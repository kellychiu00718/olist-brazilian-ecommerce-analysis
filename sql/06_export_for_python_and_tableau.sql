-- 06_export_for_python_and_tableau.sql
-- Exports derived tables to ./data (kept out of git; Olist data is CC BY-NC-SA, so raw/row-level data is never published).
-- Run from the project folder:  psql -d olist -f sql/06_export_for_python_and_tableau.sql
SET search_path TO olist, public;
\copy (SELECT customer_state, d_approval, d_to_carrier, d_in_transit, d_total, d_promised, d_late, review_score FROM v_delivery_review) TO 'data/a_delivery_review.csv' CSV HEADER
\copy (SELECT * FROM v_corridor) TO 'data/b_corridors.csv' CSV HEADER
\copy (SELECT seller_state, customer_state, price, freight_value, freight_ratio, product_weight_g, distance_km, same_state FROM v_item_freight WHERE price > 0 AND distance_km IS NOT NULL) TO 'data/b_items.csv' CSV HEADER
\copy (SELECT COALESCE(origin,'unknown') AS origin, business_segment, lead_type, orders, revenue, avg_score, activated FROM v_closed_seller) TO 'data/c_closed_sellers.csv' CSV HEADER
\copy (SELECT COALESCE(m.origin,'unknown') AS origin, (d.mql_id IS NOT NULL) AS closed FROM marketing_qualified_leads m LEFT JOIN closed_deals d USING (mql_id)) TO 'data/c_leads.csv' CSV HEADER
\copy (SELECT category, name_len, desc_len, photos, units_sold, avg_price FROM v_product_sales) TO 'data/d_products.csv' CSV HEADER
