# Power BI Dashboard

Power BI is the deployment layer of this project. It does not connect to raw Olist tables and does not recreate the machine-learning pipeline.

## Data source

Use only:

`data/powerbi/powerbi_order_risk.csv`

Generate it by running `notebooks/06_powerbi_export.ipynb` after the processed master table is available locally.

## Recommended pages

### 1. Executive Risk Overview
- Total Orders
- Negative Review Rate
- Late Delivery Rate
- Average Delivery Time
- Negative Review Rate by month, state, category and persona

### 2. Risk Drivers
- Negative Review Rate by late-days band
- Delivery delay versus negative-review rate
- Product-category comparison
- State comparison
- Persona comparison
- Reference the CatBoost feature-importance artifact for model interpretation

### 3. Customer Recovery Queue
Once order-level prediction probabilities are available, show:
- Order ID
- Delivery risk probability
- Risk band
- Late days
- Delivery time
- Order value
- Category
- State
- Persona

Sort by model risk descending so the page functions as an operational prioritization view rather than a decorative report.

## Power BI skills demonstrated

- Power Query data typing and light transformation
- Explicit Date table
- Relationships / model design
- DAX measures
- Filter context and slicers
- Drill-through and tooltips
- Conditional formatting
- Business-oriented dashboard design

The final `.pbix` file and a dashboard screenshot can be added to this folder / `assets/` after the report is built.
