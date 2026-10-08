# Order-level Prediction Artifacts

This folder is reserved for saved scoring artifacts joined by `order_id`.

Expected files:

- `placement_predictions.csv`
- `delivery_predictions.csv`

Do not reconstruct order-level probabilities from summary metrics. Notebook 06 will merge these files into the Power BI export when the original scoring artifacts are available.
