# Prediction outputs

Notebooks 03 and 04 generate full order-level test-set prediction files locally:

- `placement_predictions.csv`
- `delivery_predictions.csv`

The full files contain 19,165 rows each and are intentionally not committed to keep the repository compact.

For inspection on GitHub, this folder includes:

- `placement_top_risk_sample.csv`
- `delivery_top_risk_sample.csv`
- `score_deciles.csv`

The model-level metrics, validation-search results, and lift / capture summaries are stored under `outputs/model_metrics/`.

Notebook 06 reads the full local prediction files when building the Power BI export.
