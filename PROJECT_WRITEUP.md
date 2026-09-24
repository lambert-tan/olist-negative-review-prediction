# Project Write-Up

## Understanding and Predicting Negative Customer Reviews in Brazilian E-Commerce

### Business problem

This project examines whether Olist can identify delivered orders that are likely to receive a 1–2 star review. I separate prediction into two points in the order lifecycle: when the order is placed and after delivery. The comparison captures a practical trade-off between acting early with limited information and acting later with stronger operational signals.

### Data

The final modeling table contains 95,824 delivered orders. Negative reviews account for 12.8% of the sample. One-to-many source tables are aggregated to the order level before modeling so that each order contributes one observation and one target.

### Unsupervised learning

K-Means is used to identify four order personas. Two groups carry especially high review risk: **Long Wait** (28.9% negative reviews) and **Multi-Item Basket** (25.9%). DBSCAN is less useful as the main segmentation method because it produces one dominant cluster, although its noise group identifies a small set of unusually risky orders.

### At-placement prediction

The final at-placement LightGBM model achieves precision of 0.231, recall of 0.511, F1 of 0.318 and ROC-AUC of 0.677. It captures roughly half of eventual negative reviews, but many flagged orders do not end in a negative review.

### At-delivery prediction

The final CatBoost model achieves precision of 0.515, recall of 0.457, F1 of 0.484 and ROC-AUC of 0.768. The strongest features are `late_days`, `delivery_vs_estimate_days`, `n_items` and `delivery_time_days`.

### Interpretation

The results consistently show that fulfillment performance is an important source of predictive information. However, some high-risk multi-item orders arrive early, and some customers leave negative reviews despite fast delivery. The model therefore captures an important part of dissatisfaction, but not all of it.

### Business implication

A two-stage workflow is more useful than treating the models as substitutes. The placement model can support low-cost early monitoring, while the delivery model can prioritize higher-confidence service recovery after stronger operational signals become available.

### Limitations

The analysis covers delivered orders only. Review scores do not identify the cause of dissatisfaction, feature importance is not causal, and the final CatBoost tuning search was limited. Future work should add time-safe seller/product history, richer product-quality signals and an intervention experiment to measure actual business impact.
