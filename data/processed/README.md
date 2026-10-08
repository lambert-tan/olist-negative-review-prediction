# Processed Data

Notebook `01_data_join_and_clean.ipynb` creates the main processed files used by the project:

- `master_orders_clean_v2.csv`
- `shared_train_test_split.csv`
- `data_quality_audit_v2.csv`

`master_orders_clean_v2.csv` is the canonical downstream input for clustering, modeling, interpretation and the Power BI export.

Optional documentation files can also be stored here, but the downstream notebooks do not depend on them.

Do not keep duplicate working copies of the processed data in `outputs/`, the repository root or the Power BI folder.
