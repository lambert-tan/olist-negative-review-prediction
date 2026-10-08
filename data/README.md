# Data and Reproducibility

This personal portfolio project uses the public **Olist Brazilian E-Commerce** dataset and keeps one explicit data lineage from raw relational tables through modeling and Power BI.

## Folder contract

```text
data/
├── raw/        # original Olist relational CSVs (not committed)
├── processed/  # canonical order-level analytical datasets
└── powerbi/    # one curated table consumed by Power BI
```

## Canonical processed dataset

`data/processed/master_orders_clean_v2.csv` is the single source of truth for clustering, placement-stage modeling, delivery-stage modeling, interpretation, and the Power BI export.

I rebuild the analytical table at **one row per order**. One-to-many source tables such as items and payments are aggregated before merging so each order contributes one observation and one target.

- `review_bad = 1` for review scores 1–2
- `review_bad = 0` for review scores 3–5
- Final cohort: **95,824 delivered orders**
- Negative reviews: **12,272 (12.8%)**
- Train: **76,659 orders**
- Test: **19,165 orders**
- 80/20 stratified split, `random_state=42`

## Data flow

```text
Olist raw relational tables
        ↓
01_data_join_and_clean.ipynb
        ↓
data/processed/master_orders_clean_v2.csv
        ↓
02 clustering   03 placement model   04 delivery model
        ↓              ↓                    ↓
   persona map      model results        model results
        └──────────────┬────────────────────┘
                       ↓
              05 interpretation
                       ↓
              06_powerbi_export.ipynb
                       ↓
          data/powerbi/powerbi_order_risk.csv
                       ↓
                    Power BI
```

## Local files

The processed master table is kept local because of its size. To run the notebooks, place these files under `data/processed/`:

- `master_orders_clean_v2.csv`
- `shared_train_test_split.csv`
- `data_quality_audit_v2.csv`
- `feature_availability_matrix_v2.csv`

If rebuilding from source, place the original Olist CSVs under `data/raw/` and run `notebooks/01_data_join_and_clean.ipynb`.

The important design rule is that downstream notebooks do not read separate ad hoc copies of the data. They all reference the same canonical processed table.