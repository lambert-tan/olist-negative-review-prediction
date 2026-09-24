# Predicting Negative Customer Reviews in Brazilian E-Commerce

> **How early can an e-commerce platform identify an order that is likely to result in a negative customer review?**

This project studies negative-review risk across the Olist order lifecycle. Instead of treating prediction as a single modeling problem, I compare two decision points: **when an order is placed** and **after it is delivered**. The comparison highlights a practical trade-off between acting early and waiting for stronger information.

## Results at a glance

**95,824 delivered orders · 12.8% negative reviews (1–2 stars)**

| Decision point | Model | Precision | Recall | F1 | ROC-AUC |
|---|---|---:|---:|---:|---:|
| At placement | LightGBM | 0.231 | **0.511** | 0.318 | 0.677 |
| At delivery | CatBoost | **0.515** | 0.457 | **0.484** | **0.768** |

The placement model catches roughly half of eventual negative reviews, but with relatively low precision. Once fulfillment information becomes available, F1 rises from **0.318 to 0.484** and ROC-AUC from **0.677 to 0.768**. The later model is more selective, but it also leaves less time for preventive action.

<p align="center">
  <img src="assets/model_comparison.svg" width="820" alt="Placement versus delivery model performance">
</p>

## Why model at two points?

The useful question is not simply which algorithm scores highest. The amount of information available changes as an order moves through fulfillment.

**Order placed → early risk screening → fulfillment → delivery-stage risk update → service recovery**

At placement, the platform can still intervene early, but it has limited evidence about how the order will unfold. At delivery, actual delay and fulfillment information provide a stronger signal, making the model more suitable for targeted service recovery.

<p align="center">
  <img src="assets/business_workflow.svg" width="900" alt="Two-stage review risk workflow">
</p>

## Order-level risk patterns

K-Means was used as an exploratory segmentation of orders. Review outcome was **not** used to fit the clusters. In the team analysis, two profiles stood out:

- **Long Wait** — 28.9% negative reviews, with long delivery times and frequent lateness.
- **Multi-Item Basket** — 25.9% negative reviews despite generally arriving early.

The clustering solution should be interpreted cautiously. Its silhouette score was about **0.21**, so the segments are useful descriptive profiles rather than evidence of sharply separated natural groups.

<p align="center">
  <img src="assets/persona_risk.svg" width="820" alt="Negative review rate across order personas">
</p>

> **Reproducibility note:** the original clustering artifact was produced from a slightly different intermediate dataset version than the final 95,824-order supervised-learning cohort. I therefore do not present the cluster counts in this repository as if they reconcile exactly with the final modeling sample. A clean rebuild should rerun clustering from the frozen master dataset.

## Final delivery model

CatBoost produced the strongest delivery-stage result in the analysis. The leading predictive features were:

1. `late_days`
2. `delivery_vs_estimate_days`
3. `n_items`
4. `delivery_time_days`

These are **predictive associations, not causal effects**. In particular, feature importance does not show that changing one variable would directly change a customer's review.

<p align="center">
  <img src="assets/feature_importance.svg" width="820" alt="CatBoost feature importance">
</p>

## Modeling approach

The project combines an order-level data pipeline with unsupervised and supervised learning. One-to-many source tables are aggregated before merging so that each order contributes one observation and one target. The supervised models use a shared 80/20 stratified train/test split (`random_state=42`) to make the placement-versus-delivery comparison consistent.

The original analysis tested Logistic Regression as a baseline, LightGBM for placement-stage prediction, and CatBoost for delivery-stage prediction. Class imbalance, cross-validation, hyperparameter tuning and decision-threshold selection were considered during model development.

### Leakage control

The target is:

`review_bad = 1` for review scores 1–2, otherwise `0` for scores 3–5.

Review timestamps and review score are excluded from predictors. Delivery outcomes are also excluded from the placement model because they would not be known when the order is created. Historical reputation features require time-aware construction so that an order cannot contribute information to its own prediction.

## Error analysis

The delivery model performs much better when poor fulfillment creates an observable signal. However, some customers still leave 1–2 star reviews after fast or early delivery. The structured data does not directly observe product quality, packaging, whether the item matched expectations, or other reasons for dissatisfaction. These false negatives are an important boundary of the model rather than something that should be explained away by delivery variables.

## Business interpretation

The two models serve different purposes rather than competing for a single deployment slot. The placement model is more appropriate for low-cost monitoring or early communication, while the delivery model can prioritize higher-confidence service-recovery cases.

A production implementation would still need an intervention test. Predicting dissatisfaction is not the same as proving that contacting a flagged customer improves retention, review score, or economics.

## Repository guide

```text
olist-negative-review-prediction/
├── assets/                         # portfolio visualizations
├── notebooks/
│   └── olist_negative_review_end_to_end.ipynb
├── outputs/                        # compact model-result artifacts
├── data/
│   └── README.md                   # data lineage and cohort definition
├── requirements.txt
└── README.md
```

The notebook currently serves as a compact integrated walkthrough of the verified project outputs. It is **not presented as a raw-data-to-model reproduction** because the raw relational Olist CSV files used by the team are not committed to this repository. This distinction is intentional.

## Limitations

The analysis is restricted to delivered orders with observed reviews. Review score identifies dissatisfaction but not its cause. The clustering artifacts and supervised-learning artifacts were produced at different points in the team workflow and should not be treated as one perfectly versioned pipeline. The final CatBoost tuning search was also limited. Future work would freeze a single raw-to-processed data version, rerun all segmentation and models from it, and test whether model-driven interventions produce measurable business value.

## Tools

Python · pandas · NumPy · scikit-learn · LightGBM · CatBoost · Optuna · Matplotlib

---

**Lambert Tan**  
Master of Management in Analytics · Smith School of Business, Queen's University
