# Data and Reproducibility

The project is based on the public **Olist Brazilian E-Commerce** data. The full raw relational dataset and the team-generated processed master table are not committed to this portfolio repository.

## Unit of analysis

The supervised-learning unit is **one order**. One-to-many source tables such as order items and payments are aggregated before merging so that an order contributes one observation and one target.

## Target

- `review_bad = 1` for review scores 1–2
- `review_bad = 0` for review scores 3–5

The frozen supervised-learning cohort contains **95,824 delivered orders**, including **12,272 negative reviews (12.8%)**.

## Shared split

The placement and delivery models use the same split:

- Train: **76,659 orders**
- Test: **19,165 orders**
- Split: 80/20, stratified by `review_bad`
- `random_state=42`

Keeping the cohort and held-out sample fixed makes the two prediction stages directly comparable.

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
95,824-order supervised master table
        ↓
shared stratified train/test split
        ↓
placement model      delivery model
```

## Feature timing

Placement-stage features are restricted to information available when an order is created. Delivery-stage modeling adds observed fulfillment information such as delivery duration and performance relative to the estimated date.

Review score and review timestamps are never predictors. Historical reputation variables should be constructed chronologically so that an order does not contribute information to its own features.

## Version note

The clustering work in the original team workflow used a slightly different intermediate dataset version. For that reason, the saved clustering profile in this repository should be treated as an exploratory artifact and its cluster counts should **not** be expected to sum to the final 95,824-order supervised cohort. A fully reproducible rebuild would rerun clustering from the frozen master table.
