-- 01_build_master_orders.sql
-- SQL (DuckDB) version of notebooks/01_data_join_and_clean.ipynb.
--
-- Builds the one-row-per-order table `master_orders` from the raw Olist CSVs.
-- Same logic as the notebook:
--   * delivered orders only
--   * latest review per order; review_bad = 1 for scores 1-2
--   * one-to-many tables (items, payments) are aggregated BEFORE joining,
--     so the order-level target is never duplicated
--   * negative approval-to-carrier intervals are flagged and set to NULL
--
-- Not done here: the stratified train/test split. It uses scikit-learn with
-- random_state=42 and stays in the notebook so both pipelines share one split.
--
-- Usage (from repo root):   python scripts/run_sql_pipeline.py
-- Parameter: the runner sets the variable raw_dir (default data/raw).

CREATE OR REPLACE MACRO raw(name) AS getvariable('raw_dir') || '/' || name;

-- ---------------------------------------------------------------- raw tables
CREATE OR REPLACE TEMP VIEW orders AS
SELECT * FROM read_csv(raw('olist_orders_dataset.csv'), header = true, types = {
    'order_purchase_timestamp': 'TIMESTAMP',
    'order_approved_at': 'TIMESTAMP',
    'order_delivered_carrier_date': 'TIMESTAMP',
    'order_delivered_customer_date': 'TIMESTAMP',
    'order_estimated_delivery_date': 'TIMESTAMP'});

CREATE OR REPLACE TEMP VIEW items AS
SELECT * FROM read_csv(raw('olist_order_items_dataset.csv'), header = true);

CREATE OR REPLACE TEMP VIEW payments AS
SELECT * FROM read_csv(raw('olist_order_payments_dataset.csv'), header = true);

-- file_row_number lets the dedupe below reproduce pandas' "keep the last row in file order"
-- when two reviews of one order carry identical timestamps. ROW_NUMBER() OVER () follows the
-- file order because DuckDB's preserve_insertion_order setting is on by default.
-- strict_mode = false tolerates the free-text comment column (embedded quotes / line breaks).
CREATE OR REPLACE TEMP VIEW reviews AS
SELECT *, ROW_NUMBER() OVER () AS file_row_number
FROM read_csv(raw('olist_order_reviews_dataset.csv'), header = true,
    strict_mode = false, types = {
    'review_creation_date': 'TIMESTAMP',
    'review_answer_timestamp': 'TIMESTAMP'});

CREATE OR REPLACE TEMP VIEW products AS
SELECT * FROM read_csv(raw('olist_products_dataset.csv'), header = true);

CREATE OR REPLACE TEMP VIEW sellers AS
SELECT * FROM read_csv(raw('olist_sellers_dataset.csv'), header = true);

CREATE OR REPLACE TEMP VIEW customers AS
SELECT * FROM read_csv(raw('olist_customers_dataset.csv'), header = true);

CREATE OR REPLACE TEMP VIEW translation AS
SELECT * FROM read_csv(raw('product_category_name_translation.csv'), header = true);

-- ------------------------------------------------------------------- build
CREATE OR REPLACE TABLE master_orders AS
WITH
-- Some orders have several review records. Keep the most recent one
-- (missing timestamps count as oldest). Exact ties keep the later row in the file.
reviews_clean AS (
    SELECT
        order_id,
        review_score,
        review_creation_date,
        review_answer_timestamp,
        CAST(review_score <= 2 AS TINYINT) AS review_bad
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY order_id
                   ORDER BY review_creation_date DESC NULLS LAST,
                            review_answer_timestamp DESC NULLS LAST,
                            file_row_number DESC
               ) AS rn
        FROM reviews
    )
    WHERE rn = 1
),

products_clean AS (
    SELECT
        p.product_id,
        COALESCE(t.product_category_name_english, 'unknown') AS product_category_name_english,
        p.product_weight_g,
        p.product_length_cm * p.product_height_cm * p.product_width_cm AS product_volume_cm3
    FROM products p
    LEFT JOIN translation t USING (product_category_name)
),

item_detail AS (
    SELECT i.*, pc.product_category_name_english, pc.product_weight_g, pc.product_volume_cm3
    FROM items i
    LEFT JOIN products_clean pc USING (product_id)
),

-- Highest-priced item = "primary" item (ties: lowest order_item_id).
primary_item AS (
    SELECT order_id,
           product_id AS primary_product_id,
           seller_id  AS primary_seller_id,
           product_category_name_english AS primary_product_category
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY price DESC, order_item_id ASC) AS rn
        FROM item_detail
    )
    WHERE rn = 1
),

items_agg AS (
    SELECT
        d.order_id,
        COUNT(d.order_item_id)                       AS n_items,
        COUNT(DISTINCT d.seller_id)                  AS n_distinct_sellers,
        COUNT(DISTINCT d.product_id)                 AS n_distinct_products,
        COUNT(DISTINCT d.product_category_name_english) AS n_product_categories,
        SUM(d.price)                                 AS total_price,
        SUM(d.freight_value)                         AS total_freight,
        AVG(d.price)                                 AS avg_item_price,
        AVG(d.product_weight_g)                      AS avg_product_weight_g,
        MAX(d.product_weight_g)                      AS max_product_weight_g,
        AVG(d.product_volume_cm3)                    AS avg_product_volume_cm3,
        MAX(d.product_volume_cm3)                    AS max_product_volume_cm3,
        ANY_VALUE(pi.primary_product_id)             AS primary_product_id,
        ANY_VALUE(pi.primary_seller_id)              AS primary_seller_id,
        ANY_VALUE(pi.primary_product_category)       AS primary_product_category
    FROM item_detail d
    JOIN primary_item pi USING (order_id)
    GROUP BY d.order_id
),

-- Payment type that carried the largest share of the order (ties: alphabetical).
primary_payment AS (
    SELECT order_id, payment_type AS primary_payment_type
    FROM (
        SELECT order_id, payment_type,
               ROW_NUMBER() OVER (PARTITION BY order_id
                                  ORDER BY SUM(payment_value) DESC, payment_type ASC) AS rn
        FROM payments
        GROUP BY order_id, payment_type
    )
    WHERE rn = 1
),

payments_agg AS (
    SELECT
        p.order_id,
        SUM(p.payment_value)             AS total_payment_value,
        MAX(p.payment_installments)      AS n_payment_installments,
        COUNT(DISTINCT p.payment_type)   AS n_payment_methods,
        ANY_VALUE(pp.primary_payment_type) AS primary_payment_type
    FROM payments p
    JOIN primary_payment pp USING (order_id)
    GROUP BY p.order_id
),

joined AS (
    SELECT
        o.*,
        c.customer_unique_id,
        c.customer_zip_code_prefix,
        c.customer_city,
        c.customer_state,
        ia.n_items, ia.n_distinct_sellers, ia.n_distinct_products, ia.n_product_categories,
        ia.total_price, ia.total_freight, ia.avg_item_price,
        ia.avg_product_weight_g, ia.max_product_weight_g,
        ia.avg_product_volume_cm3, ia.max_product_volume_cm3,
        ia.primary_product_id, ia.primary_seller_id, ia.primary_product_category,
        pa.total_payment_value, pa.n_payment_installments, pa.n_payment_methods,
        pa.primary_payment_type,
        s.seller_zip_code_prefix AS primary_seller_zip_code_prefix,
        s.seller_city            AS primary_seller_city,
        s.seller_state           AS primary_seller_state,
        r.review_score, r.review_creation_date, r.review_answer_timestamp, r.review_bad
    FROM orders o
    LEFT JOIN customers c        ON c.customer_id = o.customer_id
    JOIN      items_agg ia       ON ia.order_id   = o.order_id      -- inner: need >= 1 item
    LEFT JOIN payments_agg pa    ON pa.order_id   = o.order_id
    LEFT JOIN sellers s          ON s.seller_id   = ia.primary_seller_id
    LEFT JOIN reviews_clean r    ON r.order_id    = o.order_id
    WHERE o.order_status = 'delivered'
),

features AS (
    SELECT
        *,
        -- calendar / placement-stage features
        hour(order_purchase_timestamp)                       AS purchase_hour,
        dayofweek(order_purchase_timestamp)                  AS purchase_dow_sun0,
        month(order_purchase_timestamp)                      AS purchase_month,
        epoch(order_estimated_delivery_date - order_purchase_timestamp) / 86400.0
                                                             AS promised_delivery_days,
        CASE WHEN total_price > 0 THEN total_freight / total_price END
                                                             AS freight_to_price_ratio,
        CASE WHEN n_items > 0 THEN total_freight / n_items END
                                                             AS avg_freight_per_item,
        CAST(customer_state IS NOT NULL AND primary_seller_state IS NOT NULL
             AND customer_state = primary_seller_state AS TINYINT)
                                                             AS same_customer_seller_state,
        -- delivery-stage features
        epoch(order_delivered_customer_date - order_purchase_timestamp) / 86400.0
                                                             AS delivery_time_days,
        epoch(order_delivered_customer_date - order_estimated_delivery_date) / 86400.0
                                                             AS delivery_vs_estimate_days,
        epoch(order_approved_at - order_purchase_timestamp) / 86400.0
                                                             AS approval_delay_days,
        epoch(order_delivered_carrier_date - order_approved_at) / 86400.0
                                                             AS carrier_pickup_delay_days_raw,
        epoch(order_delivered_customer_date - order_delivered_carrier_date) / 86400.0
                                                             AS shipping_transit_days
    FROM joined
)

SELECT
    f.* EXCLUDE (purchase_dow_sun0),
    -- Python's dayofweek is Monday=0; DuckDB's dayofweek is Sunday=0.
    CAST((purchase_dow_sun0 + 6) % 7 AS INTEGER)                          AS purchase_day_of_week,
    CAST((purchase_dow_sun0 + 6) % 7 IN (5, 6) AS TINYINT)                AS is_weekend,
    -- COALESCE: a missing carrier date is not an anomaly (pandas: NaN < 0 is False; SQL: NULL < 0 is NULL)
    CAST(COALESCE(carrier_pickup_delay_days_raw < 0, FALSE) AS TINYINT)   AS carrier_timestamp_anomaly,
    CASE WHEN carrier_pickup_delay_days_raw >= 0 THEN carrier_pickup_delay_days_raw END
                                                                           AS carrier_pickup_delay_days,
    CAST(delivery_vs_estimate_days > 0 AS TINYINT)                        AS delivered_late,
    GREATEST(delivery_vs_estimate_days, 0)                                AS late_days,
    GREATEST(-delivery_vs_estimate_days, 0)                               AS early_days
FROM features f
-- Final cohort: observed review + complete delivery timestamps.
WHERE review_bad IS NOT NULL
  AND order_delivered_customer_date IS NOT NULL
  AND order_estimated_delivery_date IS NOT NULL
  AND delivery_time_days IS NOT NULL
  AND delivery_vs_estimate_days IS NOT NULL;

-- Categorical NULLs are grouped as 'unknown', as in the notebook.
UPDATE master_orders SET customer_state          = COALESCE(customer_state, 'unknown'),
                         customer_city           = COALESCE(customer_city, 'unknown'),
                         primary_seller_state    = COALESCE(primary_seller_state, 'unknown'),
                         primary_seller_city     = COALESCE(primary_seller_city, 'unknown'),
                         primary_payment_type    = COALESCE(primary_payment_type, 'unknown'),
                         primary_product_category = COALESCE(primary_product_category, 'unknown');
