-- 01_delivery_timeline.sql  (Question A: where does the time go, and is lateness vs. the promise what hurts reviews?)
-- Run with:  psql -d olist -f 01_delivery_timeline.sql
SET search_path TO olist, public;

-- ---------------------------------------------------------------
-- Step 1. Data-quality check on delivered orders
-- `IS NULL` (not `= NULL`) is how SQL tests for missing values.
-- ---------------------------------------------------------------
SELECT
    COUNT(*)                                                                     AS delivered_orders,
    COUNT(*) FILTER (WHERE order_approved_at IS NULL)                            AS missing_approved,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL)                 AS missing_carrier,
    COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL)                AS missing_customer,
    COUNT(*) FILTER (WHERE order_delivered_carrier_date < order_approved_at)     AS carrier_before_approved,
    COUNT(*) FILTER (WHERE order_delivered_customer_date < order_delivered_carrier_date) AS customer_before_carrier
FROM orders
WHERE order_status = 'delivered';

-- ---------------------------------------------------------------
-- Step 2. One row per delivered order, with each stage in days.
-- extract(epoch from interval) gives seconds; / 86400 = days (keeps hours, unlike date() - date()).
-- A view is a saved query: later steps can SELECT from it like a table.
-- Rows with missing dates or a negative stage are left out (counted in Step 1 / Step 3).
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_delivery AS
SELECT
    o.order_id,
    c.customer_state,
    o.order_purchase_timestamp                                                                    AS purchased_at,
    EXTRACT(EPOCH FROM (o.order_approved_at            - o.order_purchase_timestamp))   / 86400  AS d_approval,
    EXTRACT(EPOCH FROM (o.order_delivered_carrier_date - o.order_approved_at))          / 86400  AS d_to_carrier,
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date- o.order_delivered_carrier_date))/ 86400 AS d_in_transit,
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date- o.order_purchase_timestamp))   / 86400  AS d_total,
    EXTRACT(EPOCH FROM (o.order_estimated_delivery_date- o.order_purchase_timestamp))   / 86400  AS d_promised,
    -- positive = arrived AFTER the promised date
    EXTRACT(EPOCH FROM (o.order_delivered_customer_date- o.order_estimated_delivery_date))/86400 AS d_late
FROM orders o
JOIN customers c USING (customer_id)
WHERE o.order_status = 'delivered'
  AND o.order_approved_at IS NOT NULL
  AND o.order_delivered_carrier_date IS NOT NULL
  AND o.order_delivered_customer_date IS NOT NULL
  AND o.order_approved_at            >= o.order_purchase_timestamp
  AND o.order_delivered_carrier_date >= o.order_approved_at
  AND o.order_delivered_customer_date>= o.order_delivered_carrier_date;

-- ---------------------------------------------------------------
-- Step 3. How many delivered orders did the cleaning rules drop?
-- ---------------------------------------------------------------
SELECT
    (SELECT COUNT(*) FROM orders WHERE order_status = 'delivered') AS delivered_orders,
    (SELECT COUNT(*) FROM v_delivery)                              AS kept_orders;

-- ---------------------------------------------------------------
-- Step 4. Average / median / 90th percentile of each stage (days)
-- Median and p90 matter because delivery times have a long tail.
-- ---------------------------------------------------------------
SELECT 'approval'   AS stage, ROUND(AVG(d_approval)::numeric,2)   AS mean_d,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_approval))::numeric,2)   AS median_d,
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY d_approval))::numeric,2)   AS p90_d
FROM v_delivery
UNION ALL
SELECT 'to_carrier', ROUND(AVG(d_to_carrier)::numeric,2),
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_to_carrier))::numeric,2),
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY d_to_carrier))::numeric,2) FROM v_delivery
UNION ALL
SELECT 'in_transit', ROUND(AVG(d_in_transit)::numeric,2),
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_in_transit))::numeric,2),
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY d_in_transit))::numeric,2) FROM v_delivery
UNION ALL
SELECT 'total', ROUND(AVG(d_total)::numeric,2),
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_total))::numeric,2),
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY d_total))::numeric,2) FROM v_delivery
UNION ALL
SELECT 'promised', ROUND(AVG(d_promised)::numeric,2),
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_promised))::numeric,2),
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY d_promised))::numeric,2) FROM v_delivery;

-- ---------------------------------------------------------------
-- Step 5. Promise gap: how often, and by how much, does the estimate miss?
-- ---------------------------------------------------------------
SELECT
    COUNT(*)                                           AS orders,
    ROUND(100.0 * AVG((d_late > 0)::int), 2)           AS pct_late,
    ROUND(AVG(d_late)::numeric, 2)                     AS mean_gap_days,          -- negative = early on average
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_late))::numeric, 2) AS median_gap_days,
    ROUND(AVG(d_promised - d_total)::numeric, 2)       AS mean_buffer_days        -- how much slack the promise has
FROM v_delivery;

-- ---------------------------------------------------------------
-- Step 6. By customer state (states with >= 500 orders)
-- ---------------------------------------------------------------
SELECT
    customer_state,
    COUNT(*)                                                     AS orders,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_total))::numeric,1)    AS median_total_d,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY d_promised))::numeric,1) AS median_promised_d,
    ROUND(100.0 * AVG((d_late > 0)::int), 1)                     AS pct_late,
    ROUND(AVG(d_late)::numeric, 1)                               AS mean_gap_days
FROM v_delivery
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY pct_late DESC;
