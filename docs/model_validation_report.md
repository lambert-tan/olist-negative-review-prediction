# Model Validation Report

This report reviews the two negative-review risk scores the way a credit or fraud scorecard would be reviewed: discrimination, rank ordering, out-of-sample stability, and known limitations.

All figures come from the frozen test set (19,165 orders, 2,454 negative reviews) and can be reproduced from committed outputs with:

```bash
python scripts/validation_metrics.py
```

## 1. Discrimination

| Metric | At placement (LightGBM) | At delivery (CatBoost) |
|---|---:|---:|
| ROC-AUC | 0.658 | **0.775** |
| Gini (2·AUC − 1) | 0.316 | **0.550** |
| KS (decile) | 0.233 | **0.435** |
| KS peak | decile 4 | decile 2 |
| PR-AUC | 0.233 | **0.496** |

KS is measured at decile cut points, which slightly understates the order-level KS. A delivery-stage Gini of 0.55 and KS of 0.44 sit in the range usually treated as a usable ranking score in retail credit and fraud work. The placement score is weaker but still separates risk.

## 2. Rank ordering

A usable score should show the bad rate falling steadily from the riskiest decile to the safest.

- **Delivery:** negative-review rate falls from **55.9%** in decile 1 to **3.8%** in decile 10. There is one small inversion (decile 8 is 0.5 points above decile 7). Beyond decile 5 the rates are close together, so the score separates risk mainly at the top.
- **Placement:** the rate falls from **29.6%** to **5.0%**, with two small inversions (deciles 6 and 9, each under 1 point).

Full table: `outputs/model_metrics/rank_ordering.csv`.

**Implication:** both scores are suited to a capacity-limited queue that works the top deciles. They are less reliable for fine distinctions among low-risk orders.

## 3. Out-of-sample stability

| | Best validation ROC-AUC | Test ROC-AUC | Gap |
|---|---:|---:|---:|
| Placement | 0.654 | 0.658 | +0.004 |
| Delivery | 0.755 | 0.775 | +0.020 |

Test performance is at or slightly above validation, so the hyperparameter search did not overfit. The validation candidates are also tightly grouped (delivery AUC 0.752–0.755), so the result does not depend on one lucky configuration.

**Population stability (PSI)** compares the score distribution in training and test. It needs training-set scores, which are not committed because the processed data is kept local. `scripts/validation_metrics.py` includes a `psi()` function for this. Because the split is random and stratified, PSI should be near zero here. The more meaningful test would be a time-based split, described below.

## 4. Limitations and recommended next checks

1. **Random rather than time-based split.** A production score would be validated on later months than it was trained on. Next step: train on orders before a cutoff date, test on orders after it, and report PSI and Gini drift.
2. **Decile-level KS.** Order-level KS needs the full test predictions; it will be equal to or slightly above the figure shown.
3. **No calibration check.** The scores rank well, but predicted probabilities have not been checked against observed rates (for example with a calibration plot or Brier score).
4. **Risk, not causal effect.** A high score means an order is likely to get a bad review, not that contacting the customer will change the outcome. An A/B test of the recovery action is needed before measuring business impact.

## 5. Conclusion

The delivery-stage CatBoost score (Gini 0.55, KS 0.44) ranks risk reliably at the top of the distribution and generalizes from validation to test without overfitting. It is fit for a capacity-limited review queue. Before production use, it would need a time-based validation and a calibration check.
