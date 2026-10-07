-- Olist Brazilian E-Commerce: create the schema and empty tables (structure only, no analysis)
-- Usage: in pgAdmin, open Tools -> Query Tool on the olist database, paste this file, run it
-- Source: Kaggle olistbr/brazilian-ecommerce (CC BY-NC-SA 4.0, non-commercial use, attribution required)

CREATE SCHEMA IF NOT EXISTS olist;
SET search_path TO olist;

CREATE TABLE customers (
    customer_id              TEXT PRIMARY KEY,
    customer_unique_id       TEXT NOT NULL,
    customer_zip_code_prefix TEXT,          -- TEXT, not a number: values like 01037 have a leading zero
    customer_city            TEXT,
    customer_state           TEXT
);

CREATE TABLE sellers (
    seller_id              TEXT PRIMARY KEY,
    seller_zip_code_prefix TEXT,
    seller_city            TEXT,
    seller_state           TEXT
);

CREATE TABLE products (
    product_id                 TEXT PRIMARY KEY,
    product_category_name      TEXT,
    product_name_lenght        INTEGER,     -- the source column name is misspelled (lenght); kept as is
    product_description_lenght INTEGER,
    product_photos_qty         INTEGER,
    product_weight_g           INTEGER,
    product_length_cm          INTEGER,
    product_height_cm          INTEGER,
    product_width_cm           INTEGER
);

CREATE TABLE product_category_translation (
    product_category_name         TEXT PRIMARY KEY,
    product_category_name_english TEXT
);

CREATE TABLE orders (
    order_id                      TEXT PRIMARY KEY,
    customer_id                   TEXT NOT NULL,
    order_status                  TEXT,
    order_purchase_timestamp      TIMESTAMP,
    order_approved_at             TIMESTAMP,
    order_delivered_carrier_date  TIMESTAMP,
    order_delivered_customer_date TIMESTAMP,
    order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE order_items (
    order_id            TEXT NOT NULL,
    order_item_id       INTEGER NOT NULL,
    product_id          TEXT,
    seller_id           TEXT,
    shipping_limit_date TIMESTAMP,
    price               NUMERIC(10,2),
    freight_value       NUMERIC(10,2),
    PRIMARY KEY (order_id, order_item_id)
);

CREATE TABLE order_payments (
    order_id             TEXT NOT NULL,
    payment_sequential   INTEGER NOT NULL,
    payment_type         TEXT,
    payment_installments INTEGER,
    payment_value        NUMERIC(10,2),
    PRIMARY KEY (order_id, payment_sequential)
);

-- No primary key on reviews on purpose: review_id repeats (about 814 rows) and one order can have several reviews.
-- De-duplication is an analysis step (see 02_reviews_vs_promise.sql), not done at import.
CREATE TABLE order_reviews (
    review_id               TEXT,
    order_id                TEXT,
    review_score            INTEGER,
    review_comment_title    TEXT,
    review_comment_message  TEXT,
    review_creation_date    TIMESTAMP,
    review_answer_timestamp TIMESTAMP
);

-- Several rows per zip prefix and no primary key (about 1 million rows)
CREATE TABLE geolocation (
    geolocation_zip_code_prefix TEXT,
    geolocation_lat             DOUBLE PRECISION,
    geolocation_lng             DOUBLE PRECISION,
    geolocation_city            TEXT,
    geolocation_state           TEXT
);

-- After the import, check the row counts with these lines. Expected: orders 99,441; order_items 112,650; order_reviews 99,224;
-- customers 99,441; sellers 3,095; products 32,951; order_payments 103,886; geolocation 1,000,163; translation 71.
-- SELECT 'orders' AS t, COUNT(*) FROM orders UNION ALL
-- SELECT 'order_items', COUNT(*) FROM order_items UNION ALL
-- SELECT 'order_reviews', COUNT(*) FROM order_reviews UNION ALL
-- SELECT 'customers', COUNT(*) FROM customers UNION ALL
-- SELECT 'sellers', COUNT(*) FROM sellers UNION ALL
-- SELECT 'products', COUNT(*) FROM products UNION ALL
-- SELECT 'order_payments', COUNT(*) FROM order_payments UNION ALL
-- SELECT 'geolocation', COUNT(*) FROM geolocation UNION ALL
-- SELECT 'product_category_translation', COUNT(*) FROM product_category_translation;
