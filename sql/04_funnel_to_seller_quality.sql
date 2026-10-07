-- 04_funnel_to_seller_quality.sql  (Question C: which acquisition channels bring sellers that actually sell well?)
-- Two datasets are linked through seller_id:
--   marketing_qualified_leads (8,000 leads) -> closed_deals (842 won) -> order_items / reviews (marketplace results)
-- The funnel data covers the SELLER side only (no shopper visits).
SET search_path TO olist, public;

-- ---------------------------------------------------------------
-- Step 1. Funnel: leads -> closed deals, by acquisition channel (origin)
-- LEFT JOIN keeps leads that never closed; closed_deals columns are NULL for them.
-- ---------------------------------------------------------------
SELECT COALESCE(m.origin, 'unknown')                        AS origin,
       COUNT(*)                                             AS leads,
       COUNT(d.mql_id)                                      AS closed,
       ROUND(100.0 * COUNT(d.mql_id) / COUNT(*), 1)         AS conversion_pct
FROM marketing_qualified_leads m
LEFT JOIN closed_deals d USING (mql_id)
GROUP BY 1
ORDER BY leads DESC;

SELECT COUNT(*) AS leads, COUNT(d.mql_id) AS closed,
       ROUND(100.0 * COUNT(d.mql_id) / COUNT(*), 1) AS conversion_pct
FROM marketing_qualified_leads m LEFT JOIN closed_deals d USING (mql_id);

-- ---------------------------------------------------------------
-- Step 2. Seller performance after closing the deal.
-- Reviews first reduced to one per order (v_order_review from file 02), then to a score per seller.
-- A seller "activated" if they appear in order_items at least once.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_seller_perf AS
SELECT oi.seller_id,
       COUNT(DISTINCT oi.order_id)                AS orders,
       SUM(oi.price)                              AS revenue,
       AVG(r.review_score)                        AS avg_score
FROM order_items oi
JOIN orders o USING (order_id)
LEFT JOIN v_order_review r USING (order_id)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY oi.seller_id;

CREATE OR REPLACE VIEW v_closed_seller AS
SELECT d.mql_id, d.seller_id, d.won_date, d.business_segment, d.lead_type, d.business_type,
       m.origin, m.landing_page_id,
       p.orders, p.revenue, p.avg_score,
       (p.seller_id IS NOT NULL) AS activated
FROM closed_deals d
JOIN marketing_qualified_leads m USING (mql_id)
LEFT JOIN v_seller_perf p USING (seller_id);

-- ---------------------------------------------------------------
-- Step 3. By acquisition channel: activation, orders, revenue, score of the sellers it brought in
-- ---------------------------------------------------------------
SELECT COALESCE(origin,'unknown')                                          AS origin,
       COUNT(*)                                                            AS closed_sellers,
       ROUND(100.0 * AVG(activated::int), 1)                               AS activation_pct,
       ROUND(AVG(COALESCE(orders,0))::numeric, 1)                          AS avg_orders_per_closed_seller,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY COALESCE(orders,0)))::numeric, 1) AS median_orders,
       ROUND(AVG(COALESCE(revenue,0))::numeric, 0)                         AS avg_revenue,
       ROUND(AVG(avg_score)::numeric, 2)                                   AS avg_review_score
FROM v_closed_seller
GROUP BY 1
HAVING COUNT(*) >= 15
ORDER BY closed_sellers DESC;

-- ---------------------------------------------------------------
-- Step 4. Channel funnel and quality side by side: conversion% vs. average orders per lead closed
-- (a channel can convert well but bring inactive sellers)
-- ---------------------------------------------------------------
WITH funnel AS (
    SELECT COALESCE(m.origin,'unknown') AS origin, COUNT(*) AS leads, COUNT(d.mql_id) AS closed
    FROM marketing_qualified_leads m LEFT JOIN closed_deals d USING (mql_id) GROUP BY 1
), quality AS (
    SELECT COALESCE(origin,'unknown') AS origin,
           AVG(COALESCE(orders,0)) AS avg_orders, AVG(activated::int) AS activation
    FROM v_closed_seller GROUP BY 1
)
SELECT f.origin, f.leads, f.closed,
       ROUND(100.0 * f.closed / f.leads, 1)         AS conversion_pct,
       ROUND(100 * q.activation, 1)                 AS activation_pct,
       ROUND(q.avg_orders::numeric, 1)              AS avg_orders_per_closed_seller,
       ROUND((f.closed * q.avg_orders)::numeric / f.leads, 2) AS orders_per_lead   -- value of one lead
FROM funnel f JOIN quality q USING (origin)
WHERE f.closed >= 15
ORDER BY orders_per_lead DESC;

-- ---------------------------------------------------------------
-- Step 5. By business segment (what kind of seller sells)
-- ---------------------------------------------------------------
SELECT COALESCE(business_segment,'unknown') AS segment,
       COUNT(*) AS closed_sellers,
       ROUND(100.0 * AVG(activated::int),1) AS activation_pct,
       ROUND(AVG(COALESCE(orders,0))::numeric,1) AS avg_orders,
       ROUND(AVG(avg_score)::numeric,2) AS avg_score
FROM v_closed_seller GROUP BY 1 HAVING COUNT(*) >= 15 ORDER BY closed_sellers DESC;

-- Sanity: do some sellers have orders BEFORE the won_date? (timing check)
SELECT COUNT(*) AS sellers_with_orders_before_won
FROM v_closed_seller v
WHERE activated AND EXISTS (
   SELECT 1 FROM order_items oi JOIN orders o USING (order_id)
   WHERE oi.seller_id = v.seller_id AND o.order_purchase_timestamp < v.won_date);
