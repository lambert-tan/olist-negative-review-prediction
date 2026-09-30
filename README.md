# Predicting Negative Customer Reviews in Brazilian E-Commerce

> **How early can an e-commerce platform identify an order that is likely to result in a negative customer review?**

**Python · LightGBM · CatBoost · Clustering · Customer Analytics**

This project estimates negative-review risk at two points in the order lifecycle: **when an order is placed** and **after it is delivered**. Comparing the two stages shows how predictive performance changes as more fulfillment information becomes available.

## Results at a glance

**95,824 delivered orders · 12.8% negative reviews (1–2 stars)**

| Decision point | Model | Precision | Recall | F1 | ROC-AUC |
|---|---|---:|---:|---:|---:|
| At placement | LightGBM | 0.231 | **0.511** | 0.318 | 0.677 |
| At delivery | CatBoost | **0.515** | 0.457 | **0.484** | **0.768** |

- The **placement model** identifies about half of eventual negative reviews, but produces more false positives.
- The **delivery model** is more selective and performs better on F1 and ROC-AUC.
- Earlier predictions give the business more time to respond; later predictions provide a stronger risk signal.

<p align="center"><img src="assets/model_comparison.svg" width="820" alt="Placement versus delivery model performance"></p>

## Business use

The placement and delivery models serve different purposes.

**At order placement:** the risk score can support lower-cost actions such as monitoring, proactive communication, or closer follow-up.

**After delivery:** the CatBoost score can be used to prioritize higher-confidence service-recovery cases.

**Order placed → early risk screening → fulfillment → delivery-stage risk update → service recovery**

<p align="center"><img src="assets/business_workflow.svg" width="900" alt="Two-stage review risk workflow"></p>

A production rollout would still require an intervention experiment. Predicting dissatisfaction does not show that contacting a flagged customer will improve retention, review score, or economics.

## Customer personas

I rebuilt K-Means on the same frozen **95,824-order cohort** used by the supervised models so the descriptive and predictive analyses use the same population.

| Persona | Orders | Share | Negative-review rate | What distinguishes it |
|---|---:|---:|---:|---|
| Long Wait | 16,705 | 17.4% | **29.1%** | ~25.3 delivery days; 39.5% delivered late |
| Multi-Item Basket | 8,306 | 8.7% | **25.9%** | ~2.5 items; high freight; generally early |
| Big-Ticket Planner | 26,692 | 27.9% | 8.2% | higher-value, heavier orders; ~4.9 installments |
| Quick Small Buy | 44,121 | 46.0% | 6.9% | low-value, light orders; ~8.3 delivery days |

Review outcome was **not** used to fit the clusters. The silhouette score is approximately **0.204**, so the personas are better treated as descriptive profiles than as sharply separated customer groups.

<p align="center"><img src="assets/persona_risk.svg" width="820" alt="Negative review rate across order personas"></p>

## Final delivery-stage model

CatBoost produced the strongest delivery-stage result. The leading predictive features were:

- `late_days`
- `delivery_vs_estimate_days`
- `n_items`
- `delivery_time_days`

<p align="center"><img src="assets/feature_importance.svg" width="820" alt="CatBoost feature importance"></p>

These are **predictive associations, not causal effects**. Feature importance does not imply that changing one variable would directly change a customer's review.

## Leakage control

Feature timing matters because the project compares models at different decision points.

- The target is `review_bad = 1` for review scores 1–2 and `0` for scores 3–5.
- Review score and review timestamps are excluded from predictors.
- Delivery outcomes are excluded from the placement model because they are not known when the order is created.
- Historical reputation features are constructed chronologically so an order does not contribute its own outcome to its history.

## Technical workflow

1. **Data preparation** — integrate order-level data, define the cohort and target, control leakage, and create a shared train/test split.
2. **Clustering** — rebuild K-Means personas on the same analytical cohort.
3. **At-placement modelling** — Logistic Regression baseline, LightGBM, feature engineering, cross-validation, and tuning.
4. **At-delivery modelling** — Logistic Regression / tree benchmarks, CatBoost, feature selection, tuning, and threshold logic.
5. **Model interpretation** — compare held-out performance, feature importance, and model errors.

The compact end-to-end notebook provides a short walkthrough, while the stage notebooks separate the main modelling steps.

## Repository guide

```text
olist-negative-review-prediction/
├── assets/
├── notebooks/
│   ├── 01_data_preparation.ipynb
│   ├── 02_clustering.ipynb
│   ├── 03_at_placement_model.ipynb
│   ├── 04_at_delivery_model.ipynb
│   ├── 05_model_interpretation.ipynb
│   └── olist_negative_review_end_to_end.ipynb
├── outputs/
├── data/
│   └── README.md
├── requirements.txt
└── README.md
```

## Reproducibility boundary

The raw Olist relational CSVs and the large team-generated processed master table are not committed here. The notebooks document the data logic and model-development workflow, but the source dataset is still required to reproduce the project end to end.

Compact verified model artifacts are included for inspection.

## Limitations

The analysis is restricted to delivered orders with observed reviews. Review score identifies dissatisfaction but not its cause. Feature importance is not causal, and the final CatBoost tuning search was limited.

Further work could package the raw-data build into reusable source modules, calibrate intervention thresholds against business cost, and test whether model-driven outreach creates measurable incremental value.

## Tools

Python · pandas · NumPy · scikit-learn · LightGBM · CatBoost · Optuna · Matplotlib

---

**Lambert Tan**  
Master of Management in Analytics · Smith School of Business, Queen's University
