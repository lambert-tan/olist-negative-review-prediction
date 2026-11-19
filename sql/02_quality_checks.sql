-- 02_quality_checks.sql
-- Data-quality and reconciliation checks on `master_orders` (built by 01).
--
-- Every check returns one row: (check_name, observed, expected, passed).
-- scripts/run_sql_pipeline.py prints the table and exits non-zero if any check fails.
--
-- The last two checks compare against the cohort sizes reported in the README
-- (95,824 delivered orders; 12,272 negative reviews). They only run when the
-- runner is started with --check-known-totals, i.e. on the real Olist data.
--
-- name: quality_checks

WITH checks AS (

    -- 1. Grain: exactly one row per order (a join fan-out would break this).
    SELECT 'one_row_per_order' AS check_name,
           COUNT(*) - COUNT(DISTINCT order_id) AS observed,
           0 AS expected
    FROM master_orders

    UNION ALL
    -- 2. Cohort filter: only delivered orders.
    SELECT 'only_delivered_orders',
           COUNT(*) FILTER (WHERE order_status <> 'delivered'), 0
    FROM master_orders

    UNION ALL
    -- 3. Target is present and binary.
    SELECT 'target_not_null_and_binary',
           COUNT(*) FILTER (WHERE review_bad IS NULL OR review_bad NOT IN (0, 1)), 0
    FROM master_orders

    UNION ALL
    -- 4. Target definition: review_bad must equal (review_score <= 2).
    SELECT 'target_matches_score_rule',
           COUNT(*) FILTER (WHERE review_bad <> CAST(review_score <= 2 AS TINYINT)), 0
    FROM master_orders

    UNION ALL
    -- 5. Reconciliation: item value in master_orders equals item value in the raw items table.
    SELECT 'item_value_reconciles',
           CAST(ROUND(ABS(
               (SELECT SUM(total_price) FROM master_orders)
             - (SELECT SUM(i.price) FROM items i
                WHERE i.order_id IN (SELECT order_id FROM master_orders))
           ), 2) AS BIGINT), 0

    UNION ALL
    -- 6. Reconciliation: payment value in master_orders equals the raw payments table.
    SELECT 'payment_value_reconciles',
           CAST(ROUND(ABS(
               (SELECT SUM(total_payment_value) FROM master_orders)
             - (SELECT SUM(p.payment_value) FROM payments p
                WHERE p.order_id IN (SELECT order_id FROM master_orders))
           ), 2) AS BIGINT), 0

    UNION ALL
    -- 7. Reconciliation: item count per order matches the raw items table.
    SELECT 'item_count_reconciles',
           (SELECT SUM(n_items) FROM master_orders)
         - (SELECT COUNT(*) FROM items i
            WHERE i.order_id IN (SELECT order_id FROM master_orders)), 0

    UNION ALL
    -- 8. Timestamps are in a plausible order: purchase before delivery.
    SELECT 'no_negative_delivery_time',
           COUNT(*) FILTER (WHERE delivery_time_days < 0), 0
    FROM master_orders

    UNION ALL
    -- 9. Negative carrier-pickup intervals are flagged and blanked, never silently kept.
    SELECT 'carrier_anomalies_are_nulled',
           COUNT(*) FILTER (WHERE carrier_timestamp_anomaly = 1
                              AND carrier_pickup_delay_days IS NOT NULL)
         + COUNT(*) FILTER (WHERE carrier_pickup_delay_days < 0), 0
    FROM master_orders

    UNION ALL
    -- 10. Categorical NULLs were replaced by 'unknown'.
    SELECT 'no_null_categoricals',
           COUNT(*) FILTER (WHERE customer_state IS NULL OR primary_seller_state IS NULL
                               OR primary_payment_type IS NULL OR primary_product_category IS NULL), 0
    FROM master_orders

    UNION ALL
    -- 11. Late flag agrees with the day difference.
    SELECT 'late_flag_consistent',
           COUNT(*) FILTER (WHERE (delivered_late = 1) <> (delivery_vs_estimate_days > 0)), 0
    FROM master_orders

    UNION ALL
    -- 12. Known cohort size (real data only).
    SELECT 'known_total_orders_95824',
           (SELECT COUNT(*) FROM master_orders),
           CASE WHEN getvariable('check_known_totals') THEN 95824
                ELSE (SELECT COUNT(*) FROM master_orders) END

    UNION ALL
    -- 13. Known negative-review count (real data only).
    SELECT 'known_negative_reviews_12272',
           (SELECT SUM(review_bad) FROM master_orders),
           CASE WHEN getvariable('check_known_totals') THEN 12272
                ELSE (SELECT SUM(review_bad) FROM master_orders) END
)
SELECT check_name, observed, expected, observed = expected AS passed
FROM checks;
