-- 03_freight_distance.sql  (Question B: which seller-state -> customer-state corridors have high freight but strong demand?)
SET search_path TO olist, public;

-- ---------------------------------------------------------------
-- Step 1. One coordinate per zip prefix.
-- geolocation has ~1,000,000 rows for ~19,000 zip prefixes (many points per prefix),
-- so average the points. A table (not a view) so the average is computed once.
-- ---------------------------------------------------------------
DROP TABLE IF EXISTS zip_centroid;
CREATE TABLE zip_centroid AS
SELECT geolocation_zip_code_prefix AS zip_prefix,
       AVG(geolocation_lat) AS lat,
       AVG(geolocation_lng) AS lng
FROM geolocation
GROUP BY geolocation_zip_code_prefix;
CREATE INDEX ON zip_centroid (zip_prefix);

-- Coverage check: how many customers and sellers have no coordinate?
SELECT
  (SELECT COUNT(*) FROM customers c LEFT JOIN zip_centroid z ON z.zip_prefix = c.customer_zip_code_prefix WHERE z.zip_prefix IS NULL) AS customers_no_coord,
  (SELECT COUNT(*) FROM sellers   s LEFT JOIN zip_centroid z ON z.zip_prefix = s.seller_zip_code_prefix   WHERE z.zip_prefix IS NULL) AS sellers_no_coord;

-- ---------------------------------------------------------------
-- Step 2. One row per order item with straight-line distance (haversine formula, km).
-- Straight-line distance is an approximation of road/shipping distance.
-- freight_ratio = freight / price: how heavy the shipping cost feels relative to the product.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_item_freight AS
SELECT
    oi.order_id, oi.order_item_id, oi.product_id,
    s.seller_state, c.customer_state,
    oi.price, oi.freight_value,
    oi.freight_value / NULLIF(oi.price, 0)                    AS freight_ratio,
    p.product_weight_g,
    (s.seller_state = c.customer_state)                       AS same_state,
    2 * 6371 * ASIN(SQRT(
        POWER(SIN(RADIANS(zc.lat - zs.lat) / 2), 2) +
        COS(RADIANS(zs.lat)) * COS(RADIANS(zc.lat)) *
        POWER(SIN(RADIANS(zc.lng - zs.lng) / 2), 2)
    ))                                                         AS distance_km
FROM order_items oi
JOIN orders    o  USING (order_id)
JOIN customers c  ON c.customer_id = o.customer_id
JOIN sellers   s  ON s.seller_id   = oi.seller_id
JOIN products  p  ON p.product_id  = oi.product_id
JOIN zip_centroid zs ON zs.zip_prefix = s.seller_zip_code_prefix
JOIN zip_centroid zc ON zc.zip_prefix = c.customer_zip_code_prefix
WHERE o.order_status NOT IN ('canceled', 'unavailable');

SELECT COUNT(*) AS items_kept, (SELECT COUNT(*) FROM order_items) AS items_total FROM v_item_freight;

-- ---------------------------------------------------------------
-- Step 3. Freight vs distance bucket
-- ---------------------------------------------------------------
SELECT
    CASE WHEN distance_km <  100 THEN '1. < 100 km'
         WHEN distance_km <  500 THEN '2. 100-500 km'
         WHEN distance_km < 1000 THEN '3. 500-1,000 km'
         WHEN distance_km < 2000 THEN '4. 1,000-2,000 km'
         ELSE                         '5. 2,000+ km' END AS distance_bucket,
    COUNT(*)                                                                    AS items,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY freight_value))::numeric,2) AS median_freight,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price))::numeric,2)         AS median_price,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY freight_ratio))::numeric,3) AS median_freight_ratio
FROM v_item_freight
GROUP BY 1 ORDER BY 1;

-- Share of items shipped within the same state
SELECT ROUND(100.0 * AVG(same_state::int), 1) AS pct_same_state FROM v_item_freight;

-- ---------------------------------------------------------------
-- Step 4. Corridors (seller state -> customer state)
-- demand = number of items; freight burden = median freight_ratio and median freight (R$)
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_corridor AS
SELECT seller_state, customer_state,
       COUNT(*)                                                                         AS items,
       ROUND(AVG(distance_km)::numeric, 0)                                              AS avg_km,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY freight_value))::numeric, 2)  AS median_freight,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY freight_ratio))::numeric, 3)  AS median_freight_ratio,
       ROUND(SUM(freight_value)::numeric, 0)                                            AS total_freight
FROM v_item_freight
GROUP BY seller_state, customer_state
HAVING COUNT(*) >= 200;

-- Top corridors by total freight paid (money at stake) -- candidates for a hub
SELECT * FROM v_corridor ORDER BY total_freight DESC LIMIT 15;

-- Where does freight burden look highest while demand is still large?
SELECT * FROM v_corridor WHERE seller_state = 'SP' ORDER BY median_freight_ratio DESC LIMIT 10;

-- ---------------------------------------------------------------
-- Step 5. Where do sellers sit, and where do customers sit? (share of the total)
-- ---------------------------------------------------------------
SELECT 'sellers'   AS who, seller_state   AS state, COUNT(*) AS n,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct FROM sellers   GROUP BY seller_state
UNION ALL
SELECT 'customers', customer_state, COUNT(*),
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) FROM customers GROUP BY customer_state
ORDER BY who, n DESC;
