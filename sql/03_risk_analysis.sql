-- 03_risk_analysis.sql
-- Where do negative reviews come from? Business-facing cuts of `master_orders`.
-- Each query is tagged with "-- name:"; the runner saves it to outputs/sql_results/<name>.csv.
--
-- These are descriptive cuts (association, not causation): they show where the
-- negative-review rate is high, which is what the model's risk ranking builds on.

-- name: negative_rate_by_delivery_timing
-- Delivery vs the date promised at checkout. Late delivery is the strongest single signal.
SELECT
    CASE
        WHEN delivery_vs_estimate_days <= -7 THEN '1) 7+ days early'
        WHEN delivery_vs_estimate_days <= 0  THEN '2) on time or up to 7 days early'
        WHEN delivery_vs_estimate_days <= 3  THEN '3) 1-3 days late'
        WHEN delivery_vs_estimate_days <= 7  THEN '4) 4-7 days late'
        ELSE                                      '5) 8+ days late'
    END                                                       AS delivery_timing,
    COUNT(*)                                                  AS orders,
    SUM(review_bad)                                           AS negative_reviews,
    ROUND(AVG(review_bad), 4)                                 AS negative_review_rate,
    ROUND(AVG(review_bad) / AVG(AVG(review_bad)) OVER (), 2)  AS index_vs_overall_rate,
    ROUND(SUM(review_bad) * 1.0 / SUM(SUM(review_bad)) OVER (), 4) AS share_of_all_negatives
FROM master_orders
GROUP BY 1
ORDER BY 1;

-- name: customer_state_risk
-- States with at least 500 orders, ranked by negative-review rate.
SELECT
    m.customer_state,
    COUNT(*)                                       AS orders,
    ROUND(AVG(m.review_bad), 4)                    AS negative_review_rate,
    ROUND(AVG(m.delivered_late), 4)                AS late_delivery_rate,
    ROUND(AVG(m.delivery_time_days), 1)            AS avg_delivery_days,
    RANK() OVER (ORDER BY AVG(m.review_bad) DESC)  AS risk_rank
FROM master_orders m
GROUP BY m.customer_state
HAVING COUNT(*) >= 500
ORDER BY risk_rank;

-- name: product_category_risk
-- Categories with at least 500 orders, ranked by negative-review rate.
SELECT
    primary_product_category,
    COUNT(*)                                       AS orders,
    ROUND(AVG(review_bad), 4)                      AS negative_review_rate,
    ROUND(AVG(delivered_late), 4)                  AS late_delivery_rate,
    ROUND(AVG(total_price), 2)                     AS avg_order_value,
    RANK() OVER (ORDER BY AVG(review_bad) DESC)    AS risk_rank
FROM master_orders
GROUP BY primary_product_category
HAVING COUNT(*) >= 500
ORDER BY risk_rank
LIMIT 15;

-- name: seller_outliers
-- Sellers with at least 100 orders whose negative rate is statistically above the
-- platform average. z = (seller rate - overall rate) / sqrt(p(1-p)/n), so small
-- sellers are not flagged on noise.
WITH overall AS (SELECT AVG(review_bad) AS p FROM master_orders),
seller AS (
    SELECT
        primary_seller_id,
        ANY_VALUE(primary_seller_state)  AS seller_state,
        COUNT(*)                         AS orders,
        SUM(review_bad)                  AS negative_reviews,
        AVG(review_bad)                  AS negative_review_rate,
        AVG(delivered_late)              AS late_delivery_rate
    FROM master_orders
    GROUP BY primary_seller_id
    HAVING COUNT(*) >= 100
)
SELECT
    s.primary_seller_id,
    s.seller_state,
    s.orders,
    s.negative_reviews,
    ROUND(s.negative_review_rate, 4)     AS negative_review_rate,
    ROUND(s.late_delivery_rate, 4)       AS late_delivery_rate,
    ROUND((s.negative_review_rate - o.p) / SQRT(o.p * (1 - o.p) / s.orders), 2) AS z_score
FROM seller s CROSS JOIN overall o
WHERE (s.negative_review_rate - o.p) / SQRT(o.p * (1 - o.p) / s.orders) >= 3
ORDER BY z_score DESC;

-- name: monthly_trend
-- Monthly volume and negative rate, with change vs prior month and a 3-month moving average.
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp)::DATE AS purchase_month,
        COUNT(*)                                            AS orders,
        AVG(review_bad)                                     AS negative_review_rate,
        AVG(delivered_late)                                 AS late_delivery_rate
    FROM master_orders
    GROUP BY 1
    HAVING COUNT(*) >= 300          -- skip the thin first/last months of the dataset
)
SELECT
    purchase_month,
    orders,
    ROUND(negative_review_rate, 4)                                                  AS negative_review_rate,
    ROUND(negative_review_rate - LAG(negative_review_rate) OVER w, 4)               AS change_vs_prior_month,
    ROUND(AVG(negative_review_rate) OVER (w ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 4)
                                                                                    AS moving_avg_3m,
    ROUND(late_delivery_rate, 4)                                                    AS late_delivery_rate
FROM monthly
WINDOW w AS (ORDER BY purchase_month)
ORDER BY purchase_month;

-- name: order_complexity
-- Multi-seller orders ship in separate parcels and arrive at different times.
SELECT
    CASE WHEN n_distinct_sellers >= 2 THEN '2+ sellers' ELSE '1 seller' END AS seller_count,
    CASE WHEN n_items >= 3 THEN '3+ items' WHEN n_items = 2 THEN '2 items' ELSE '1 item' END
                                                  AS item_count,
    COUNT(*)                                      AS orders,
    ROUND(AVG(review_bad), 4)                     AS negative_review_rate,
    ROUND(AVG(delivered_late), 4)                 AS late_delivery_rate
FROM master_orders
GROUP BY 1, 2
HAVING COUNT(*) >= 100
ORDER BY 1, 2;
