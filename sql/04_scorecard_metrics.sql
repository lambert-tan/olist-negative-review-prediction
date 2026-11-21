-- 04_scorecard_metrics.sql
-- Scorecard-style validation in SQL: Gini, KS, lift/capture and rank ordering.
--
-- Runs on files that ARE committed to this repo, so no raw data is needed:
--   outputs/predictions/score_deciles.csv
--   outputs/model_metrics/placement_vs_delivery.csv
--
-- Cross-check: results should match outputs/model_metrics/scorecard_metrics.csv
-- (produced by scripts/validation_metrics.py).

CREATE OR REPLACE TEMP VIEW deciles AS
SELECT stage, risk_decile, orders, negative_reviews,
       orders - negative_reviews AS non_negative_reviews,
       negative_review_rate
FROM read_csv('outputs/predictions/score_deciles.csv', header = true);

CREATE OR REPLACE TEMP VIEW test_metrics AS
SELECT stage, model, roc_auc
FROM read_csv('outputs/model_metrics/placement_vs_delivery.csv', header = true);

-- Cumulative share of negatives ("bad") and non-negatives ("good"), riskiest decile first.
CREATE OR REPLACE TEMP VIEW cumulative AS
SELECT
    stage, risk_decile, orders, negative_reviews, negative_review_rate,
    SUM(negative_reviews)     OVER w / SUM(negative_reviews)     OVER (PARTITION BY stage) AS cum_bad_share,
    SUM(non_negative_reviews) OVER w / SUM(non_negative_reviews) OVER (PARTITION BY stage) AS cum_good_share,
    SUM(orders)               OVER w / SUM(orders)               OVER (PARTITION BY stage) AS cum_order_share
FROM deciles
WINDOW w AS (PARTITION BY stage ORDER BY risk_decile);

-- name: scorecard_headline
-- Headline metrics per model: Gini = 2*AUC - 1, KS = max(cum_bad - cum_good).
SELECT
    c.stage,
    t.model,
    ROUND(t.roc_auc, 4)                                    AS roc_auc,
    ROUND(2 * t.roc_auc - 1, 4)                            AS gini,
    ROUND(MAX(c.cum_bad_share - c.cum_good_share), 4)      AS ks_decile,
    ARG_MAX(c.risk_decile, c.cum_bad_share - c.cum_good_share) AS ks_peak_decile
FROM cumulative c
JOIN test_metrics t USING (stage)
GROUP BY c.stage, t.model, t.roc_auc
ORDER BY c.stage;

-- name: capture_and_lift
-- Capture and lift curve by decile: how much of the negative-review volume
-- sits in the top X% of scored orders.
SELECT
    stage,
    risk_decile,
    ROUND(cum_order_share, 2)                              AS top_share_of_orders,
    ROUND(cum_bad_share, 4)                                AS share_of_negatives_captured,
    ROUND(cum_bad_share / cum_order_share, 2)              AS cumulative_lift
FROM cumulative
ORDER BY stage, risk_decile;

-- name: rank_ordering
-- The negative-review rate should fall from decile to decile.
-- inversion = TRUE flags a decile whose rate is higher than the riskier decile before it.
SELECT
    stage,
    risk_decile,
    ROUND(negative_review_rate, 4)                         AS negative_review_rate,
    ROUND(negative_review_rate
          - LAG(negative_review_rate) OVER (PARTITION BY stage ORDER BY risk_decile), 4)
                                                           AS change_vs_prior_decile,
    COALESCE(negative_review_rate
             > LAG(negative_review_rate) OVER (PARTITION BY stage ORDER BY risk_decile), FALSE)
                                                           AS inversion
FROM deciles
ORDER BY stage, risk_decile;

-- ---------------------------------------------------------------------------
-- Optional: rebuild the deciles from order-level predictions.
-- Needs outputs/predictions/delivery_predictions.csv, which notebook 04 writes
-- locally (it is not committed). Uncomment to run.
--
-- CREATE OR REPLACE TEMP VIEW scored AS
-- SELECT order_id, actual_review_bad, delivery_probability
-- FROM read_csv('outputs/predictions/delivery_predictions.csv', header = true);
--
-- SELECT
--     decile                                      AS risk_decile,
--     COUNT(*)                                    AS orders,
--     SUM(actual_review_bad)                      AS negative_reviews,
--     AVG(actual_review_bad)                      AS negative_review_rate,
--     AVG(delivery_probability)                   AS avg_score
-- FROM (SELECT *, NTILE(10) OVER (ORDER BY delivery_probability DESC) AS decile FROM scored)
-- GROUP BY decile
-- ORDER BY decile;
