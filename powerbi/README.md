# Power BI Dashboard

This is the business-facing deployment layer of my Olist customer review risk project. I keep the Power BI report downstream of the Python workflow so the dashboard does not recreate data engineering or model logic in a second place.

## Data source

Power BI reads only:

`data/powerbi/powerbi_order_risk.csv`

I generate that file with `notebooks/06_powerbi_export.ipynb` after the canonical processed master table is available locally.

## Report design

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
- CatBoost feature importance as model context

### 3. Customer Recovery Queue
Once I persist order-level model probabilities, this page will show:
- Order ID
- Delivery risk probability
- Risk band
- Late days
- Delivery time
- Order value
- Category
- State
- Persona

The queue should be sorted by model risk descending so the report supports prioritization rather than serving as a decorative dashboard.

## Power BI skills demonstrated

- Power Query data typing and light transformation
- Explicit Date table
- Relationships / model design
- DAX measures
- Filter context and slicers
- Drill-through and tooltips
- Conditional formatting
- Business-oriented dashboard design

The final `.pbix` file and dashboard screenshot will live in this folder / `assets/` once the report is complete.