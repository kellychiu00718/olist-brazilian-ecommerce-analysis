-- 07_background.sql  (Background: what sells, and where sellers and buyers are)
-- Run with:  psql -d olist -f sql/07_background.sql   (run from the project folder; writes to data/, which stays out of git)
SET search_path TO olist, public;

-- ---------------------------------------------------------------
-- Step 1. Best-selling categories.
-- Orders that were canceled or unavailable are left out, as in file 04.
-- LEFT JOIN to the translation table keeps categories that have no English name.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_category_sales AS
SELECT COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
       COUNT(*)                          AS items,
       COUNT(DISTINCT oi.order_id)       AS orders,
       SUM(oi.price)                     AS revenue
FROM order_items oi
JOIN orders o USING (order_id)
JOIN products p USING (product_id)
LEFT JOIN product_category_translation t USING (product_category_name)
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1;

SELECT category, items, orders, ROUND(revenue::numeric, 0) AS revenue,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1) AS revenue_share_pct
FROM v_category_sales
ORDER BY revenue DESC
LIMIT 10;

-- ---------------------------------------------------------------
-- Step 2. Where are the sellers and the buyers?
-- Items sold, counted once on the seller side and once on the buyer side, by state.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_state_side AS
WITH seller_side AS (
    SELECT s.seller_state AS state, COUNT(*) AS items_sold, COUNT(DISTINCT oi.seller_id) AS sellers
    FROM order_items oi
    JOIN orders o USING (order_id)
    JOIN sellers s USING (seller_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
), buyer_side AS (
    SELECT c.customer_state AS state, COUNT(*) AS items_bought, COUNT(DISTINCT c.customer_unique_id) AS buyers
    FROM order_items oi
    JOIN orders o USING (order_id)
    JOIN customers c USING (customer_id)
    WHERE o.order_status NOT IN ('canceled', 'unavailable')
    GROUP BY 1
)
SELECT COALESCE(a.state, b.state) AS state,
       COALESCE(a.items_sold, 0)   AS items_sold,   COALESCE(a.sellers, 0) AS sellers,
       COALESCE(b.items_bought, 0) AS items_bought, COALESCE(b.buyers, 0)  AS buyers
FROM seller_side a FULL JOIN buyer_side b ON a.state = b.state;

SELECT state, sellers, items_sold,
       ROUND(100.0 * items_sold   / SUM(items_sold)   OVER (), 1) AS pct_items_sold,
       buyers, items_bought,
       ROUND(100.0 * items_bought / SUM(items_bought) OVER (), 1) AS pct_items_bought
FROM v_state_side
ORDER BY items_bought DESC
LIMIT 10;

-- ---------------------------------------------------------------
-- Step 3. Export for the Python figures.
-- ---------------------------------------------------------------
\copy (SELECT * FROM v_category_sales ORDER BY revenue DESC) TO 'data/e_categories.csv' CSV HEADER
\copy (SELECT * FROM v_state_side ORDER BY items_bought DESC) TO 'data/e_states.csv' CSV HEADER
