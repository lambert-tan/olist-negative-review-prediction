# Negative-review score validation

The holdout contains 19,165 delivered orders, including 2,454 with a one- or two-star review. The operational question is whether the scores concentrate those reviews in a queue small enough for a service team to handle.

| Measure | Placement (LightGBM) | Delivery (CatBoost) |
|---|---:|---:|
| Validation ROC-AUC | 0.654 | 0.755 |
| Test ROC-AUC | 0.658 | 0.775 |
| Test PR-AUC (average precision) | 0.233 | 0.496 |
| Gini | 0.316 | 0.550 |
| KS at decile boundaries | 0.233 | 0.435 |
| Negative-review rate in highest-risk decile | 29.6% | 55.9% |
| Negative-review rate in lowest-risk decile | 5.0% | 3.8% |

The overall negative-review rate was 12.8%. In the highest-risk delivery decile, it reached 55.9%, about 4.4 times the overall rate. That decile captured 43.6% of the negative reviews. Separation is weaker near the bottom of the ranking. For example, the rate in delivery decile eight was 0.5 percentage points higher than in decile seven. [Rank ordering](../outputs/model_metrics/rank_ordering.csv) · [Capacity curve](../outputs/model_metrics/capacity_curve.csv)

## Limits of the evidence

Validation and test ROC-AUC were similar on this random split. Orders from later months would provide a stronger test of stability over time. KS is evaluated at decile boundaries, so a gap between those boundaries can be missed. Calibration also remains untested. A service team can evaluate the ranking at its actual review capacity before using score values as probabilities.

A controlled trial of customer contact would answer a separate question: whether following up with flagged customers improves their experience.

## Reproduction

Run `python scripts/validation_metrics.py` from the repository root. The script uses committed model summaries and decile counts. [Scorecard metrics](../outputs/model_metrics/scorecard_metrics.csv)
