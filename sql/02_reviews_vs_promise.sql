-- 02_reviews_vs_promise.sql  (Question A, part 2: slow vs. late: which one hurts the review score?)
-- Needs the view v_delivery from 01_delivery_timeline.sql.
-- NOTE: the dataset has NO seller-reply time. order_reviews.review_answer_timestamp is when the CUSTOMER
-- answered the survey, so we do not use it as "seller response".
SET search_path TO olist, public;

-- ---------------------------------------------------------------
-- Step 1. order_reviews has more than one row for some orders. Joining it directly would
-- duplicate orders and distort every average. Check how many orders are affected.
-- ---------------------------------------------------------------
SELECT COUNT(*) AS orders_with_multiple_reviews
FROM (SELECT order_id FROM order_reviews GROUP BY order_id HAVING COUNT(*) > 1) t;

-- ---------------------------------------------------------------
-- Step 2. One review per order: keep the most recent one.
-- DISTINCT ON (order_id) keeps the first row per order after the ORDER BY.
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_order_review AS
SELECT DISTINCT ON (order_id) order_id, review_score
FROM order_reviews
ORDER BY order_id, review_creation_date DESC, review_answer_timestamp DESC;

-- ---------------------------------------------------------------
-- Step 3. Orders + delivery stages + review score, with two ways of bucketing time
-- ---------------------------------------------------------------
CREATE OR REPLACE VIEW v_delivery_review AS
SELECT
    d.*,
    r.review_score,
    CASE WHEN d.d_total <  7  THEN '1. < 7 days'
         WHEN d.d_total < 14  THEN '2. 7-14 days'
         WHEN d.d_total < 21  THEN '3. 14-21 days'
         ELSE                      '4. 21+ days' END AS speed_bucket,
    CASE WHEN d.d_late <= -7 THEN '1. 7+ days early'
         WHEN d.d_late <= 0  THEN '2. 0-7 days early'
         WHEN d.d_late <= 3  THEN '3. 1-3 days late'
         WHEN d.d_late <= 7  THEN '4. 4-7 days late'
         ELSE                     '5. 7+ days late' END AS promise_bucket
FROM v_delivery d
JOIN v_order_review r USING (order_id);

-- ---------------------------------------------------------------
-- Step 4. Average score by speed, and by promise gap
-- ---------------------------------------------------------------
SELECT speed_bucket, COUNT(*) AS orders,
       ROUND(AVG(review_score),2) AS avg_score,
       ROUND(100.0*AVG((review_score<=2)::int),1) AS pct_1_2_star
FROM v_delivery_review GROUP BY speed_bucket ORDER BY speed_bucket;

SELECT promise_bucket, COUNT(*) AS orders,
       ROUND(AVG(review_score),2) AS avg_score,
       ROUND(100.0*AVG((review_score<=2)::int),1) AS pct_1_2_star
FROM v_delivery_review GROUP BY promise_bucket ORDER BY promise_bucket;

-- ---------------------------------------------------------------
-- Step 5. The key test: slow-but-on-time vs. fast-but-late (cross-tab)
-- If customers punish SLOW delivery, the 21+ days / on-time cell should look bad.
-- If they punish BROKEN PROMISES, the late cells should look bad regardless of speed.
-- ---------------------------------------------------------------
SELECT speed_bucket,
       (d_late > 0) AS arrived_late,
       COUNT(*) AS orders,
       ROUND(AVG(review_score),2) AS avg_score,
       ROUND(100.0*AVG((review_score<=2)::int),1) AS pct_1_2_star
FROM v_delivery_review
GROUP BY speed_bucket, (d_late > 0)
ORDER BY speed_bucket, arrived_late;

-- ---------------------------------------------------------------
-- Step 6. Correlations (Pearson; Python adds Spearman and a regression)
-- ---------------------------------------------------------------
SELECT ROUND(CORR(d_total, review_score)::numeric,3) AS corr_total_days_score,
       ROUND(CORR(d_late,  review_score)::numeric,3) AS corr_days_late_score
FROM v_delivery_review;

-- ---------------------------------------------------------------
-- Step 7. What-if: a tighter promise by state (assumption: future delivery times look like the past)
-- For each state, find the number of days that would have been met by ~92% / 95% of orders
-- (92% ~ today's on-time rate), and compare to the promise customers see today.
-- ---------------------------------------------------------------
SELECT customer_state,
       COUNT(*) AS orders,
       ROUND((PERCENTILE_CONT(0.5)   WITHIN GROUP (ORDER BY d_promised))::numeric,1) AS promise_today_d,
       ROUND((PERCENTILE_CONT(0.918) WITHIN GROUP (ORDER BY d_total))::numeric,1)    AS promise_same_late_rate_d,
       ROUND((PERCENTILE_CONT(0.95)  WITHIN GROUP (ORDER BY d_total))::numeric,1)    AS promise_95pct_d
FROM v_delivery
GROUP BY customer_state
HAVING COUNT(*) >= 500
ORDER BY orders DESC;
