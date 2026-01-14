USE retail_inventory;

-- View sample data to understand structure
SELECT *
FROM retail_store_inventory
LIMIT 10;

CREATE OR REPLACE VIEW stg_retail_inventory AS
SELECT
    -- Convert string date to DATE type
    DATE(`Date`) AS order_date,

    -- Identifiers
    `Store ID` AS store_id,
    `Product ID` AS product_id,

    -- Descriptive dimensions
    Category AS category,
    Region AS region,
    Seasonality AS season,
    `Weather Condition` AS weather,

    -- Inventory & demand metrics
    `Inventory Level` AS inventory_level,
    `Units Sold` AS units_sold,
    `Units Ordered` AS units_ordered,
    `Demand Forecast` AS demand_forecast,

    -- Pricing
    Price AS unit_price,
    Discount AS discount_percent,
    `Competitor Pricing` AS competitor_price,

    -- Promotion indicator (0 / 1)
    `Holiday/Promotion` AS is_promotion

FROM retail_store_inventory

-- Defensive filtering to remove invalid records
WHERE
    `Inventory Level` IS NOT NULL
    AND `Units Sold` IS NOT NULL
    AND Price IS NOT NULL;

CREATE OR REPLACE VIEW kpi_inventory_turnover AS
SELECT
    *,
    
    -- Inventory Turnover Ratio
    -- NULLIF prevents division by zero
    units_sold / NULLIF(inventory_level, 0) AS inventory_turnover

FROM stg_retail_inventory;

CREATE OR REPLACE VIEW kpi_demand_gap AS
SELECT
    *,
    
    -- Positive value → potential stockout risk
    -- Negative value → overstock risk
    demand_forecast - inventory_level AS demand_supply_gap

FROM kpi_inventory_turnover;

CREATE OR REPLACE VIEW kpi_revenue_margin AS
SELECT
    *,
    
    -- Net selling price after discount
    unit_price * (1 - discount_percent / 100) AS net_unit_price,

    -- Revenue estimation
    units_sold * unit_price * (1 - discount_percent / 100) AS estimated_revenue,

    -- Cost estimation using competitor pricing
    units_sold * competitor_price AS estimated_cost,

    -- Estimated margin
    (units_sold * unit_price * (1 - discount_percent / 100))
    - (units_sold * competitor_price) AS estimated_margin

FROM kpi_demand_gap;

CREATE OR REPLACE VIEW bi_inventory_risk AS
SELECT
    *,
    
    CASE
        WHEN inventory_level < 30 THEN 'Low Stock'
        WHEN inventory_level BETWEEN 30 AND 200 THEN 'Healthy Stock'
        ELSE 'Overstock'
    END AS inventory_status

FROM kpi_revenue_margin;

CREATE OR REPLACE VIEW bi_promotion_efficiency AS
SELECT
    *,
    
    CASE
        WHEN is_promotion = 1 AND units_sold > demand_forecast THEN 'High Promotion Impact'
        WHEN is_promotion = 1 AND units_sold <= demand_forecast THEN 'Low Promotion Impact'
        ELSE 'No Promotion'
    END AS promotion_effectiveness

FROM bi_inventory_risk;

CREATE OR REPLACE VIEW bi_retail_operations_final AS
SELECT
    order_date,
    store_id,
    product_id,
    category,
    region,
    season,

    inventory_level,
    units_sold,
    units_ordered,
    demand_forecast,
    inventory_turnover,
    demand_supply_gap,

    estimated_revenue,
    estimated_margin,

    inventory_status,
    promotion_effectiveness

FROM bi_promotion_efficiency;

SELECT * FROM bi_retail_operations_final;