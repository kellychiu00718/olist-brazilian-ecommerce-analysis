-- 05_listing_content.sql  (Question D, optional: does listing text length relate to sales within a category?)
-- Column names are misspelled in the source data: product_name_lenght, product_description_lenght.
SET search_path TO olist, public;

-- ---------------------------------------------------------------
-- Step 1. Product-level table: sales = how many times the product was sold (order items)
-- Price is averaged per product; categories translated to English.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_product_sales AS
SELECT p.product_id,
       COALESCE(t.product_category_name_english, p.product_category_name) AS category,
       p.product_name_lenght        AS name_len,
       p.product_description_lenght AS desc_len,
       p.product_photos_qty         AS photos,
       COUNT(oi.order_id)           AS units_sold,
       AVG(oi.price)                AS avg_price
FROM products p
JOIN order_items oi USING (product_id)
JOIN orders o USING (order_id)
LEFT JOIN product_category_translation t USING (product_category_name)
WHERE o.order_status NOT IN ('canceled','unavailable')
  AND p.product_name_lenght IS NOT NULL
  AND p.product_category_name IS NOT NULL
GROUP BY 1,2,3,4,5;

SELECT COUNT(*) AS products_sold, ROUND(AVG(units_sold),2) AS mean_units,
       (PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY units_sold)) AS median_units FROM v_product_sales;

-- ---------------------------------------------------------------
-- Step 2. Naive view: across ALL products (this mixes categories, so it can mislead)
-- ---------------------------------------------------------------
SELECT ROUND(CORR(name_len,  units_sold)::numeric,3) AS corr_name_len,
       ROUND(CORR(desc_len,  units_sold)::numeric,3) AS corr_desc_len,
       ROUND(CORR(photos,    units_sold)::numeric,3) AS corr_photos
FROM v_product_sales;

-- ---------------------------------------------------------------
-- Step 3. Bucketed (description length) -- again before controlling for category
-- ---------------------------------------------------------------
SELECT CASE WHEN desc_len <  250 THEN '1. < 250'
            WHEN desc_len <  500 THEN '2. 250-500'
            WHEN desc_len < 1000 THEN '3. 500-1,000'
            ELSE                      '4. 1,000+' END AS desc_bucket,
       COUNT(*) AS products,
       ROUND(AVG(units_sold),2) AS mean_units,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY units_sold))::numeric,1) AS median_units
FROM v_product_sales GROUP BY 1 ORDER BY 1;
-- Within-category tests (Spearman per category) are in ../python/analysis_d.py
