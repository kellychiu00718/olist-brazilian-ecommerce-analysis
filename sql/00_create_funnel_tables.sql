-- Olist Marketing Funnel: create 2 empty tables (structure only, no analysis)
-- Usage: in pgAdmin, open the Query Tool on the olist database, paste this file, run it
-- Source: Kaggle olistbr/marketing-funnel-olist (CC BY-NC-SA 4.0, non-commercial use, attribution required)
-- Prerequisite: 00_create_tables.sql has been run (schema olist exists)

SET search_path TO olist;

-- Marketing qualified leads (MQL): sellers who left their details on a landing page and asked to be contacted
CREATE TABLE marketing_qualified_leads (
    mql_id             TEXT PRIMARY KEY,
    first_contact_date DATE,
    landing_page_id    TEXT,
    origin             TEXT            -- acquisition channel; 60 rows are empty
);

-- Closed deals: MQLs that signed up and became sellers
CREATE TABLE closed_deals (
    mql_id                        TEXT PRIMARY KEY,
    seller_id                     TEXT,
    sdr_id                        TEXT,
    sr_id                         TEXT,
    won_date                      TIMESTAMP,
    business_segment              TEXT,
    lead_type                     TEXT,
    lead_behaviour_profile        TEXT,
    has_company                   BOOLEAN,
    has_gtin                      BOOLEAN,
    average_stock                 TEXT,   -- the source value is a text range, not a number
    business_type                 TEXT,
    declared_product_catalog_size NUMERIC,  -- the CSV has decimals like 5.0, so not INTEGER
    declared_monthly_revenue      NUMERIC
);

-- Row-count check after import: marketing_qualified_leads should be 8,000; closed_deals should be 842
-- SELECT 'mql' AS t, COUNT(*) FROM marketing_qualified_leads UNION ALL
-- SELECT 'closed_deals', COUNT(*) FROM closed_deals;
