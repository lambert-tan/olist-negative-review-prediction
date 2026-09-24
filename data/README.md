# Data

This repository does not commit the full processed Olist order-level dataset.

The project uses the public **Olist Brazilian E-Commerce** data and constructs an order-level modeling table. One-to-many tables such as order items and payments are aggregated before merging so that each order contributes one observation and one target.

The final supervised-learning cohort contains **95,824 delivered orders** with an observed review and the timing information required for the placement-versus-delivery comparison.

Target definition:

- `review_bad = 1` for review scores 1–2
- `review_bad = 0` for review scores 3–5

Negative reviews account for approximately **12.8%** of the final sample.

The full processed dataset is excluded from GitHub to keep the repository lightweight and to avoid presenting a team-generated intermediate file as the sole reproducibility source.
