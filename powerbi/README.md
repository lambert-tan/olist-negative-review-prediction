# Power BI Dashboard

The Power BI report is the final project step. It uses one curated export from the Python workflow and does not repeat the raw-data joins or model training.

## Data source

Use:

`data/powerbi/powerbi_order_risk.csv`

Generate the file by running notebooks 02–04 first, then notebook 06.

The export includes:

- order and purchase fields
- geography and product category
- order value and delivery performance
- persona
- actual review outcome
- placement-model score
- delivery-model score
- model-based risk band
- delivery-risk rank and percentile
- top 5%, top 10% and top 20% risk flags
- service-priority label for the recovery queue

## Planned pages

### 1. Executive Risk Overview

- Total Orders
- Negative Review Rate
- Late Delivery Rate
- Average Delivery Time
- monthly trend
- state, category and persona breakdowns

### 2. Risk Drivers

- negative-review rate by delivery delay
- order-value and order-complexity views
- state and category comparisons
- persona comparison
- CatBoost feature-importance reference

### 3. Customer Recovery Queue

- Order ID
- Delivery Risk Probability
- Delivery Risk Rank
- Service Priority
- Risk Band
- Late Days
- Delivery Time
- Order Value
- Category
- State
- Persona

The queue should be sorted by delivery-model probability so it functions as a prioritization tool.

A capacity view can use the top-risk flags or a What-if parameter to show how review capacity changes the share of negative reviews captured. The Python analysis already provides benchmark points at 5%, 10% and 20% capacity.

## Power BI skills shown

- Power Query for data typing and light transformation
- explicit Date table
- relationships and model design
- DAX measures
- slicers and filter context
- What-if parameter for service capacity
- drill-through / tooltips
- conditional formatting
- operational dashboard design

The `.pbix` file and dashboard screenshot will be added after the report is complete.
