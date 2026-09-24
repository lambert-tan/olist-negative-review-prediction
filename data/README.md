# Data and Reproducibility

This project is based on the public **Olist Brazilian E-Commerce** data. The raw relational CSV files are not committed to this portfolio repository, but the project keeps the data lineage and feature timing explicit.

## Unit of analysis

The supervised-learning unit is **one order**. One-to-many source tables such as order items and payments are aggregated before merging so that each order contributes one observation and one target.

## Target and cohort

- `review_bad = 1` for review scores 1–2
- `review_bad = 0` for review scores 3–5
- Final cohort: **95,824 delivered orders**
- Negative reviews: **12,272 (12.8%)**

## Shared split

Both supervised models use the same frozen split:

- Train: **76,659 orders**
- Test: **19,165 orders**
- 80/20 stratified split
- `random_state=42`

## Data flow

```text
Olist relational tables
        ↓
aggregate one-to-many tables
        ↓
merge to one row per order
        ↓
feature engineering + leakage checks
        ↓
95,824-order master table
        ↓
shared stratified train/test split
        ↓
placement model      delivery model
```

## Feature timing

Placement-stage features are restricted to information available when an order is created. Delivery-stage modeling adds observed fulfillment information such as delivery duration and performance relative to the estimated date.

Review score and review timestamps are never predictors. Historical reputation variables must be constructed chronologically so that an order cannot contribute information to its own features.

## Clustering rebuild

The portfolio clustering profile has been rebuilt on the same **95,824-order frozen master table** used by the supervised models. The original seven clustering variables are retained:

- log order value
- log freight
- log product weight
- log delivery days
- delivery versus estimate
- payment installments
- number of items

Seventeen rows had at least one missing clustering input. Rather than dropping them and creating a different cohort, the portfolio rebuild uses median imputation before standardization. K-Means uses `k=4`, `n_init=10`, and `random_state=42`. The resulting cluster counts sum to **95,824**. A 20,000-row silhouette sample gives approximately **0.204**, reinforcing that the personas are descriptive profiles rather than sharply separated natural groups.

## Reproduction

The complete processed master table is intentionally excluded from GitHub because it is a large team-generated intermediate artifact. The notebooks therefore document the transformations and modeling logic without claiming that a fresh clone can reproduce the project from raw data alone.
