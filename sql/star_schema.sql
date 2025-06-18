-- =====================================================
-- STAR Schema for Procurement Analytics Database
-- =====================================================

-- Drop tables if they exist (for clean recreation)
DROP TABLE IF EXISTS fact_spend_analytics;
DROP TABLE IF EXISTS dim_vendors;
DROP TABLE IF EXISTS dim_commodities;
DROP TABLE IF EXISTS dim_time;
DROP TABLE IF EXISTS dim_contracts;
DROP TABLE IF EXISTS dim_business_units;

-- =====================================================
-- DIMENSION TABLES
-- =====================================================

-- Vendor Dimension (SCD Type 2)
CREATE TABLE dim_vendors (
    vendor_key INTEGER PRIMARY KEY,
    vendor_id TEXT NOT NULL,
    vendor_name TEXT NOT NULL,
    vendor_tier TEXT CHECK(vendor_tier IN ('Strategic', 'Preferred', 'Approved', 'Tactical')),
    diversity_classification TEXT,
    risk_rating TEXT CHECK(risk_rating IN ('Low', 'Medium', 'High', 'Critical')),
    esg_score REAL CHECK(esg_score >= 0 AND esg_score <= 100),
    country TEXT,
    region TEXT,
    supplier_size TEXT CHECK(supplier_size IN ('SME', 'Large', 'Enterprise')),
    certification_status TEXT,
    effective_start_date DATE NOT NULL,
    effective_end_date DATE,
    is_current_record BOOLEAN NOT NULL DEFAULT 1,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Commodity Dimension
CREATE TABLE dim_commodities (
    commodity_key INTEGER PRIMARY KEY,
    commodity_id TEXT NOT NULL,
    commodity_description TEXT NOT NULL,
    parent_category TEXT,
    sub_category TEXT,
    commodity_level INTEGER,
    business_criticality TEXT CHECK(business_criticality IN ('Critical', 'High', 'Medium', 'Low')),
    sourcing_complexity TEXT CHECK(sourcing_complexity IN ('Simple', 'Moderate', 'Complex', 'Strategic')),
    category_manager TEXT,
    spend_category TEXT,
    unit_of_measure TEXT,
    effective_start_date DATE NOT NULL,
    is_current_record BOOLEAN NOT NULL DEFAULT 1,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Time Dimension
CREATE TABLE dim_time (
    time_key INTEGER PRIMARY KEY,
    date_actual DATE NOT NULL UNIQUE,
    year INTEGER NOT NULL,
    quarter INTEGER NOT NULL CHECK(quarter >= 1 AND quarter <= 4),
    month INTEGER NOT NULL CHECK(month >= 1 AND month <= 12),
    fiscal_year INTEGER NOT NULL,
    fiscal_quarter INTEGER NOT NULL CHECK(fiscal_quarter >= 1 AND fiscal_quarter <= 4),
    fiscal_month INTEGER NOT NULL,
    month_name TEXT NOT NULL,
    quarter_name TEXT NOT NULL,
    day_of_week TEXT NOT NULL,
    day_of_week_num INTEGER NOT NULL CHECK(day_of_week_num >= 1 AND day_of_week_num <= 7),
    week_of_year INTEGER NOT NULL CHECK(week_of_year >= 1 AND week_of_year <= 53),
    is_weekend BOOLEAN NOT NULL,
    is_holiday BOOLEAN DEFAULT 0,
    holiday_name TEXT
);

-- Contract Dimension (Future Enhancement)
CREATE TABLE dim_contracts (
    contract_key INTEGER PRIMARY KEY,
    contract_id TEXT NOT NULL,
    contract_name TEXT,
    contract_type TEXT CHECK(contract_type IN ('MSA', 'SOW', 'PO', 'Framework', 'Spot')),
    contract_status TEXT CHECK(contract_status IN ('Active', 'Expired', 'Terminated', 'Draft')),
    start_date DATE,
    end_date DATE,
    auto_renewal BOOLEAN DEFAULT 0,
    payment_terms INTEGER,
    currency_code TEXT,
    risk_level TEXT CHECK(risk_level IN ('Low', 'Medium', 'High')),
    effective_start_date DATE NOT NULL,
    is_current_record BOOLEAN NOT NULL DEFAULT 1
);

-- Business Unit Dimension (Future Enhancement)
CREATE TABLE dim_business_units (
    business_unit_key INTEGER PRIMARY KEY,
    business_unit_id TEXT NOT NULL,
    business_unit_name TEXT NOT NULL,
    parent_unit_id TEXT,
    level_in_hierarchy INTEGER,
    cost_center TEXT,
    region TEXT,
    country TEXT,
    manager_name TEXT,
    budget_amount REAL,
    effective_start_date DATE NOT NULL,
    is_current_record BOOLEAN NOT NULL DEFAULT 1
);

-- =====================================================
-- FACT TABLES
-- =====================================================

-- Main Spend Analytics Fact Table
CREATE TABLE fact_spend_analytics (
    fact_key INTEGER PRIMARY KEY,
    
    -- Foreign Keys to Dimensions
    vendor_key INTEGER NOT NULL,
    commodity_key INTEGER NOT NULL,
    contract_key INTEGER,
    time_key INTEGER NOT NULL,
    business_unit_key INTEGER,
    
    -- Spend Metrics
    spend_amount REAL NOT NULL CHECK(spend_amount >= 0),
    transaction_count INTEGER DEFAULT 1 CHECK(transaction_count > 0),
    quantity REAL CHECK(quantity >= 0),
    unit_price REAL CHECK(unit_price >= 0),
    
    -- Performance Metrics
    delivery_performance_score REAL CHECK(delivery_performance_score >= 0 AND delivery_performance_score <= 100),
    quality_score REAL CHECK(quality_score >= 0 AND quality_score <= 100),
    compliance_score REAL CHECK(compliance_score >= 0 AND compliance_score <= 100),
    
    -- Risk and ESG Metrics
    risk_weighted_spend REAL CHECK(risk_weighted_spend >= 0),
    esg_weighted_spend REAL CHECK(esg_weighted_spend >= 0),
    carbon_footprint_kg REAL CHECK(carbon_footprint_kg >= 0),
    
    -- Savings Metrics
    savings_amount REAL DEFAULT 0,
    discount_amount REAL DEFAULT 0,
    baseline_price REAL CHECK(baseline_price >= 0),
    
    -- Processing Metrics
    po_cycle_time_days INTEGER CHECK(po_cycle_time_days >= 0),
    invoice_processing_time_days INTEGER CHECK(invoice_processing_time_days >= 0),
    payment_delay_days INTEGER,
    
    -- Audit Trail
    source_transaction_id TEXT,
    source_system TEXT,
    load_date DATE NOT NULL,
    load_timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Foreign Key Constraints
    FOREIGN KEY (vendor_key) REFERENCES dim_vendors(vendor_key),
    FOREIGN KEY (commodity_key) REFERENCES dim_commodities(commodity_key),
    FOREIGN KEY (contract_key) REFERENCES dim_contracts(contract_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key),
    FOREIGN KEY (business_unit_key) REFERENCES dim_business_units(business_unit_key)
);

-- Supplier Performance Fact Table (Future Enhancement)
CREATE TABLE fact_supplier_performance (
    performance_key INTEGER PRIMARY KEY,
    vendor_key INTEGER NOT NULL,
    time_key INTEGER NOT NULL,
    
    -- Delivery Metrics
    on_time_delivery_rate REAL CHECK(on_time_delivery_rate >= 0 AND on_time_delivery_rate <= 100),
    in_full_delivery_rate REAL CHECK(in_full_delivery_rate >= 0 AND in_full_delivery_rate <= 100),
    otif_rate REAL CHECK(otif_rate >= 0 AND otif_rate <= 100),
    
    -- Quality Metrics
    defect_rate REAL CHECK(defect_rate >= 0 AND defect_rate <= 100),
    return_rate REAL CHECK(return_rate >= 0 AND return_rate <= 100),
    warranty_claims_count INTEGER DEFAULT 0,
    
    -- Service Metrics
    response_time_hours REAL CHECK(response_time_hours >= 0),
    resolution_time_hours REAL CHECK(resolution_time_hours >= 0),
    customer_satisfaction_score REAL CHECK(customer_satisfaction_score >= 0 AND customer_satisfaction_score <= 10),
    
    -- ESG Metrics
    sustainability_score REAL CHECK(sustainability_score >= 0 AND sustainability_score <= 100),
    diversity_spend_percentage REAL CHECK(diversity_spend_percentage >= 0 AND diversity_spend_percentage <= 100),
    
    load_date DATE NOT NULL,
    
    FOREIGN KEY (vendor_key) REFERENCES dim_vendors(vendor_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key)
);

-- Savings Realization Fact Table (Future Enhancement)
CREATE TABLE fact_savings_realization (
    savings_key INTEGER PRIMARY KEY,
    vendor_key INTEGER NOT NULL,
    commodity_key INTEGER NOT NULL,
    time_key INTEGER NOT NULL,
    
    -- Savings Types
    hard_savings_amount REAL DEFAULT 0,
    soft_savings_amount REAL DEFAULT 0,
    cost_avoidance_amount REAL DEFAULT 0,
    working_capital_improvement REAL DEFAULT 0,
    
    -- Realization Status
    forecasted_savings REAL NOT NULL,
    realized_savings REAL NOT NULL,
    realization_rate REAL GENERATED ALWAYS AS (
        CASE WHEN forecasted_savings > 0 
             THEN (realized_savings / forecasted_savings) * 100 
             ELSE 0 END
    ) STORED,
    
    -- Initiative Details
    initiative_id TEXT,
    initiative_type TEXT,
    business_case_reference TEXT,
    
    load_date DATE NOT NULL,
    
    FOREIGN KEY (vendor_key) REFERENCES dim_vendors(vendor_key),
    FOREIGN KEY (commodity_key) REFERENCES dim_commodities(commodity_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Dimension Table Indexes
CREATE INDEX idx_dim_vendors_id ON dim_vendors(vendor_id);
CREATE INDEX idx_dim_vendors_current ON dim_vendors(is_current_record, effective_start_date);
CREATE INDEX idx_dim_commodities_id ON dim_commodities(commodity_id);
CREATE INDEX idx_dim_time_date ON dim_time(date_actual);
CREATE INDEX idx_dim_time_fiscal ON dim_time(fiscal_year, fiscal_quarter);

-- Fact Table Indexes
CREATE INDEX idx_fact_spend_vendor ON fact_spend_analytics(vendor_key);
CREATE INDEX idx_fact_spend_commodity ON fact_spend_analytics(commodity_key);
CREATE INDEX idx_fact_spend_time ON fact_spend_analytics(time_key);
CREATE INDEX idx_fact_spend_date ON fact_spend_analytics(load_date);
CREATE INDEX idx_fact_spend_amount ON fact_spend_analytics(spend_amount);

-- Composite Indexes for Common Queries
CREATE INDEX idx_fact_spend_vendor_time ON fact_spend_analytics(vendor_key, time_key);
CREATE INDEX idx_fact_spend_commodity_time ON fact_spend_analytics(commodity_key, time_key);

-- =====================================================
-- VIEWS FOR COMMON REPORTING
-- =====================================================

-- Current Vendor View (Active Records Only)
CREATE VIEW vw_current_vendors AS
SELECT *
FROM dim_vendors
WHERE is_current_record = 1;

-- Monthly Spend Summary View
CREATE VIEW vw_monthly_spend_summary AS
SELECT 
    dt.fiscal_year,
    dt.fiscal_month,
    dt.month_name,
    dv.vendor_tier,
    dc.parent_category,
    SUM(fsa.spend_amount) as total_spend,
    COUNT(fsa.fact_key) as transaction_count,
    AVG(fsa.delivery_performance_score) as avg_delivery_score
FROM fact_spend_analytics fsa
JOIN dim_time dt ON fsa.time_key = dt.time_key
JOIN vw_current_vendors dv ON fsa.vendor_key = dv.vendor_key
JOIN dim_commodities dc ON fsa.commodity_key = dc.commodity_key
GROUP BY dt.fiscal_year, dt.fiscal_month, dt.month_name, dv.vendor_tier, dc.parent_category;

-- Top Vendor Spend View
CREATE VIEW vw_top_vendor_spend AS
SELECT 
    dv.vendor_name,
    dv.vendor_tier,
    dv.risk_rating,
    SUM(fsa.spend_amount) as total_spend,
    COUNT(DISTINCT fsa.commodity_key) as commodity_count,
    AVG(fsa.compliance_score) as avg_compliance_score
FROM fact_spend_analytics fsa
JOIN vw_current_vendors dv ON fsa.vendor_key = dv.vendor_key
GROUP BY dv.vendor_key, dv.vendor_name, dv.vendor_tier, dv.risk_rating
ORDER BY total_spend DESC;

-- =====================================================
-- DATA QUALITY CONSTRAINTS
-- =====================================================

-- Ensure time keys are properly formatted (YYYYMMDD)
CREATE TRIGGER trg_validate_time_key
BEFORE INSERT ON fact_spend_analytics
FOR EACH ROW
WHEN NEW.time_key < 20090101 OR NEW.time_key > 99991231
BEGIN
    SELECT RAISE(ABORT, 'Invalid time_key format. Must be YYYYMMDD.');
END;

-- Ensure no negative spend amounts
CREATE TRIGGER trg_validate_spend_amount
BEFORE INSERT ON fact_spend_analytics
FOR EACH ROW
WHEN NEW.spend_amount < 0
BEGIN
    SELECT RAISE(ABORT, 'Spend amount cannot be negative.');
END;

-- Auto-update timestamps
CREATE TRIGGER trg_update_vendor_timestamp
AFTER UPDATE ON dim_vendors
FOR EACH ROW
BEGIN
    UPDATE dim_vendors 
    SET updated_date = CURRENT_TIMESTAMP 
    WHERE vendor_key = NEW.vendor_key;
END;
