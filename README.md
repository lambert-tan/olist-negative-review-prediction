# Predicting Negative Customer Reviews in Brazilian E-Commerce

An end-to-end machine learning project using the Olist Brazilian e-commerce dataset to study **when negative-review risk becomes predictable during the order lifecycle**.

## Project overview

A poor review is not equally predictable at every stage of an order. This project compares two decision points:

- **At placement** — using only information available when the order is created.
- **At delivery** — adding observed fulfillment and delivery performance.

The analysis also uses unsupervised learning to identify order personas with different review-risk profiles.

## Key results

| Model | Precision | Recall | F1 | ROC-AUC |
|---|---:|---:|---:|---:|
| At placement — LightGBM | 0.231 | 0.511 | 0.318 | 0.677 |
| At delivery — CatBoost | **0.515** | 0.457 | **0.484** | **0.768** |

The final modeling sample contains **95,824 delivered orders**, with a **12.8% negative-review rate**.

Moving from placement to delivery increased F1 from **0.318 to 0.484** and ROC-AUC from **0.677 to 0.768**. The strongest delivery-stage signals were lateness relative to the promised date, total delivery time, and order size.

## What I found

### 1. Delivery performance matters, but it is not the whole story

K-Means identified four order personas. Two groups had particularly high negative-review rates:

- **Long Wait** — 28.9% negative reviews; strongly associated with late delivery.
- **Multi-Item Basket** — 25.9% negative reviews despite generally arriving early.

This suggests that dissatisfaction is not explained by a single mechanism.

### 2. Earlier prediction trades accuracy for actionability

The placement model captures about half of eventual negative reviews, but precision is relatively low. It can support low-cost monitoring or proactive communication while there is still time to intervene.

The delivery model has substantially stronger discrimination and precision, making it more useful for targeted service recovery.

### 3. Error cases reveal missing information

Some 1–2 star reviews occur even when delivery is early and fast. The available structured data cannot directly observe product quality, packaging, item accuracy, or customer expectations. These cases define an important limit of the model.

## Methods

**Data preparation**
- Order-level modeling table
- One-to-many tables aggregated before merging
- Delivered-order cohort
- Leakage controls based on feature availability
- Shared stratified train/test split for fair model comparison

**Unsupervised learning**
- K-Means clustering
- DBSCAN comparison
- Silhouette analysis
- Adjusted Rand Index
- Post-hoc cluster risk profiling

**Supervised learning**
- Logistic Regression baseline
- LightGBM at placement
- CatBoost at delivery
- Class-imbalance handling
- Cross-validation
- Hyperparameter tuning
- Out-of-fold threshold selection

**Interpretation**
- Feature importance
- Confusion matrix
- Held-out error analysis
- Placement-versus-delivery comparison

## Repository structure

```text
olist-negative-review-prediction/
├── notebooks/
│   └── olist_negative_review_end_to_end.ipynb
├── outputs/
│   ├── cluster_profile.csv
│   ├── placement_vs_delivery.csv
│   ├── catboost_feature_importance.csv
│   ├── catboost_cv_folds.csv
│   └── ...
├── data/
│   └── README.md
├── PROJECT_WRITEUP.md
├── requirements.txt
└── README.md
```

## Business use

A practical implementation would use a two-stage workflow:

**Order placed → early risk screening → fulfillment monitoring → delivery-stage risk update → targeted service recovery**

The placement model is suited to inexpensive preventive actions. The delivery model can prioritize higher-confidence cases once stronger operational evidence becomes available.

## Limitations

The analysis covers delivered orders only. Review scores identify dissatisfaction but do not explain its cause. Feature importance is predictive rather than causal, and the final CatBoost tuning search was deliberately limited. Historical seller/product reputation features also require strict time-aware construction before they should be used in production.

## Data

The analysis is based on the public Olist Brazilian E-Commerce dataset. The full processed order-level dataset is intentionally not committed to this repository; the notebook documents the modeling design and the repository includes compact reproducibility outputs.

## Tools

Python · pandas · NumPy · scikit-learn · LightGBM · CatBoost · Optuna · Matplotlib

---

**Author:** Lambert Tan  
Master of Management in Analytics, Smith School of Business, Queen's University
