# Data

This project uses the public Olist Brazilian E-Commerce dataset.

## Folder structure

```text
data/
├── raw/        # original relational source files
├── processed/  # one-row-per-order analytical data
└── powerbi/    # curated table used by Power BI
```

## Raw files

Place the following source files under `data/raw/` before running notebook 01:

- `olist_orders_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_order_payments_dataset.csv`
- `olist_order_reviews_dataset.csv`
- `olist_products_dataset.csv`
- `olist_sellers_dataset.csv`
- `olist_customers_dataset.csv`
- `product_category_name_translation.csv`

The raw files are not committed to this repository.

## Processed data

Notebook `01_data_join_and_clean.ipynb` creates the main analytical files under `data/processed/`.

`master_orders_clean_v2.csv` is the single source used by clustering, both prediction models, interpretation and the Power BI export.

The final modeling cohort contains:

- 95,824 delivered orders
- 12,272 negative reviews (12.8%)
- 76,659 training orders
- 19,165 test orders

The train/test split is stratified with `random_state=42`.

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
    personas       risk scores          risk scores
        └──────────────┬────────────────────┘
                       ↓
              05 interpretation
                       ↓
              06_powerbi_export.ipynb
                       ↓
          data/powerbi/powerbi_order_risk.csv
```

Large processed files are kept local to avoid duplicating bulky intermediate data in GitHub.
