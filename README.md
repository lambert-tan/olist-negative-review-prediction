# Predicting Negative Customer Reviews in Brazilian E-Commerce

> **How early can an e-commerce platform identify an order that is likely to result in a negative customer review?**

**Python · LightGBM · CatBoost · Clustering · Power BI · Customer Analytics**

This project uses the public Olist Brazilian E-Commerce dataset to study when useful negative-review risk signals appear during the order lifecycle. I built the analysis from the order-level data pipeline through modeling and interpretation, then added a Power BI layer for business-facing use.

The main comparison is between an **at-placement** model, which has more time to support early action, and an **at-delivery** model, which has stronger fulfillment information.

## Results

**95,824 delivered orders · 12.8% negative reviews (1–2 stars)**

| Decision point | Model | Precision | Recall | F1 | ROC-AUC | PR-AUC |
|---|---|---:|---:|---:|---:|---:|
| At placement | LightGBM | 0.219 | **0.473** | 0.299 | 0.658 | 0.233 |
| At delivery | CatBoost | **0.565** | 0.431 | **0.489** | **0.775** | **0.496** |

The placement model works better as an early screening tool because it keeps more recall. The delivery model is much more selective and ranks negative-review cases more effectively.

<p align="center"><img src="assets/model_comparison.svg" width="900" alt="Placement versus delivery model performance"></p>

## Risk concentration

The delivery score is useful even before choosing a single operating threshold. On the held-out test set:

- the top **5%** of delivery-risk scores contain about **29.8%** of all negative reviews;
- the top **10%** contain about **43.6%**;
- the top **20%** contain about **57.9%**.

The top 10% group has a negative-review rate of about **55.9%**, compared with 12.8% overall. That is roughly **4.4× lift**.

This makes the score suitable for testing a capacity-constrained service-recovery workflow, where only a limited number of orders can be reviewed or contacted.

## Business workflow

I use the two model stages differently:

**Order placed → early risk screening → fulfillment → delivery-stage risk update → service recovery**

At placement, the score can support lower-cost monitoring or proactive communication. After delivery, the stronger CatBoost score can be used to prioritize a smaller set of higher-risk cases.

<p align="center"><img src="assets/business_workflow.svg" width="900" alt="Two-stage review risk workflow"></p>

The models estimate risk, not the causal effect of an intervention. A production test would still need to measure whether contacting flagged customers improves review outcomes, retention, or unit economics.

## Order personas

K-Means is used on the same 95,824-order cohort to provide a descriptive view of recurring order patterns.

| Persona | Orders | Share | Negative-review rate | What distinguishes it |
|---|---:|---:|---:|---|
| Long Wait | 16,705 | 17.4% | **29.1%** | ~25.3 delivery days; 39.5% delivered late |
| Multi-Item Basket | 8,306 | 8.7% | **25.9%** | ~2.5 items; high freight; generally early |
| Big-Ticket Planner | 26,692 | 27.9% | 8.2% | higher-value, heavier orders; ~4.9 installments |
| Quick Small Buy | 44,121 | 46.0% | 6.9% | low-value, light orders; ~8.3 delivery days |

Review outcome is not used to fit the clusters. The silhouette score is about **0.204**, so I use these as descriptive profiles rather than sharply separated natural groups.

<p align="center"><img src="assets/persona_risk.svg" width="820" alt="Negative review rate across order personas"></p>

## Final delivery-stage model

CatBoost gives the strongest delivery-stage result. The leading features are mostly related to fulfillment timing and order complexity.

<p align="center"><img src="assets/feature_importance.svg" width="900" alt="CatBoost feature importance"></p>

Feature importance is used as a predictive diagnostic. It does not show that changing one feature would directly change a customer's review.

## Data and leakage controls

The modeling unit is one order.

- `review_bad = 1` for review scores 1–2 and `0` for scores 3–5.
- One-to-many tables such as items and payments are aggregated before joining to the order-level target.
- Review score and review timestamps are never used as predictors.
- Delivery outcomes are excluded from the placement model.
- Numeric imputation and categorical handling are learned from training data only.
- Unseen placement-stage categories are mapped to an explicit `__OTHER__` level.
- Model settings and classification thresholds are selected on validation data.
- The frozen test set is used only for final evaluation.

Because the positive class is imbalanced, I report **PR-AUC** in addition to ROC-AUC, F1, precision and recall.

## Workflow

1. **Data join and cleaning** — combine the relational Olist tables into one row per delivered order.
2. **Feature engineering** — separate placement-stage and delivery-stage information.
3. **Clustering** — create four descriptive order personas.
4. **At-placement modeling** — run a small LightGBM validation search and save test-set scores.
5. **At-delivery modeling** — run a small CatBoost validation search, save scores and feature importance.
6. **Interpretation** — compare model stages and evaluate lift / capture rate.
7. **Power BI export** — create one curated order-level table for the final dashboard.

## Repository structure

```text
olist-negative-review-prediction/
├── assets/
├── data/
│   ├── raw/
│   ├── processed/
│   └── powerbi/
├── notebooks/
│   ├── 01_data_join_and_clean.ipynb
│   ├── 02_clustering.ipynb
│   ├── 03_at_placement_model.ipynb
│   ├── 04_at_delivery_model.ipynb
│   ├── 05_model_interpretation.ipynb
│   ├── 06_powerbi_export.ipynb
│   └── olist_negative_review_end_to_end.ipynb
├── outputs/
│   ├── model_metrics/
│   ├── interpretation/
│   └── predictions/
├── powerbi/
├── requirements.txt
└── README.md
```

The compact end-to-end notebook is saved with executed outputs so the main results can be reviewed directly on GitHub.

## Power BI

The Power BI report will use only `data/powerbi/powerbi_order_risk.csv`, which is generated by notebook 06 from the same processed data and model outputs used in Python.

The planned report has three pages:

- **Executive Risk Overview**
- **Risk Drivers**
- **Customer Recovery Queue**

I am keeping the `.pbix` and dashboard screenshot as the final project step rather than adding a placeholder report.

## Reproducibility

Raw Olist CSVs are not committed. The processed master table is also kept local because of its size. `data/README.md` lists the expected raw files and folder structure.

The repository includes compact model metrics, validation-search results, lift / capture summaries, feature importance, and small samples of the highest-risk scored orders. Running notebooks 03 and 04 recreates the full test-set prediction files locally.

## Limitations

The analysis includes only delivered orders with observed reviews. Review score identifies dissatisfaction but does not reveal its exact cause. The validation search is intentionally small, and the intervention value of the model has not been tested experimentally.

## Tools

Python · pandas · NumPy · scikit-learn · LightGBM · CatBoost · Matplotlib · Power BI · Power Query · DAX

---

**Lambert Tan**
