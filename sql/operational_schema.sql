-- =====================================================
-- Operational Schema for Procurement Database
-- =====================================================
-- This schema supports day-to-day procurement operations
-- with normalized tables for transactional efficiency

-- =====================================================
-- MASTER DATA TABLES
-- =====================================================

-- Vendors/Suppliers Master
CREATE TABLE vendors (
    vendor_id TEXT PRIMARY KEY,
    vendor_name TEXT NOT NULL,
    vendor_tier TEXT CHECK(vendor_tier IN ('Strategic', 'Preferred', 'Approved', 'Tactical')),
    diversity_classification TEXT,
    country TEXT,
    region TEXT,
    contact_email TEXT,
    contact_phone TEXT,
    tax_id TEXT,
    registration_number TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- Commodities/Products Master
CREATE TABLE commodities (
    commodity_id TEXT PRIMARY KEY,
    commodity_description TEXT NOT NULL,
    parent_category TEXT,
    sub_category TEXT,
    unit_of_measure TEXT,
    commodity_type TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT 1
);

-- Business Units
CREATE TABLE business_units (
    business_unit_id TEXT PRIMARY KEY,
    business_unit_name TEXT NOT NULL,
    parent_unit_id TEXT,
    cost_center TEXT,
    region TEXT,
    country TEXT,
    manager_name TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_unit_id) REFERENCES business_units(business_unit_id)
);

-- =====================================================
-- TRANSACTIONAL TABLES
-- =====================================================

-- Contracts
CREATE TABLE contracts (
    contract_id TEXT PRIMARY KEY,
    vendor_id TEXT NOT NULL,
    contract_name TEXT,
    contract_type TEXT CHECK(contract_type IN ('MSA', 'SOW', 'PO', 'Framework', 'Spot')),
    contract_status TEXT CHECK(contract_status IN ('Active', 'Expired', 'Terminated', 'Draft')),
    start_date DATE,
    end_date DATE,
    contract_value REAL,
    currency_code TEXT DEFAULT 'USD',
    auto_renewal BOOLEAN DEFAULT 0,
    payment_terms INTEGER,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id)
);

-- Purchase Orders
CREATE TABLE purchase_orders (
    po_id TEXT PRIMARY KEY,
    vendor_id TEXT NOT NULL,
    contract_id TEXT,
    business_unit_id TEXT,
    po_date DATE NOT NULL,
    requested_delivery_date DATE,
    po_status TEXT CHECK(po_status IN ('Draft', 'Approved', 'Sent', 'Acknowledged', 'Delivered', 'Invoiced', 'Paid', 'Cancelled')),
    total_amount REAL NOT NULL CHECK(total_amount >= 0),
    currency_code TEXT DEFAULT 'USD',
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    approved_date TIMESTAMP,
    approved_by TEXT,
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id),
    FOREIGN KEY (contract_id) REFERENCES contracts(contract_id),
    FOREIGN KEY (business_unit_id) REFERENCES business_units(business_unit_id)
);

-- Purchase Order Line Items
CREATE TABLE po_line_items (
    po_line_id INTEGER PRIMARY KEY,
    po_id TEXT NOT NULL,
    commodity_id TEXT NOT NULL,
    line_number INTEGER NOT NULL,
    description TEXT,
    quantity REAL NOT NULL CHECK(quantity > 0),
    unit_price REAL NOT NULL CHECK(unit_price >= 0),
    line_amount REAL NOT NULL CHECK(line_amount >= 0),
    requested_delivery_date DATE,
    FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id),
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id),
    UNIQUE(po_id, line_number)
);

-- Spend Transactions (Aggregated view of actual spend)
CREATE TABLE spend_transactions (
    transaction_id INTEGER PRIMARY KEY,
    vendor_id TEXT NOT NULL,
    commodity_id TEXT NOT NULL,
    contract_id TEXT,
    business_unit_id TEXT,
    po_id TEXT,
    transaction_date DATE NOT NULL,
    award_date DATE,
    invoice_date DATE,
    payment_date DATE,
    total_amount REAL NOT NULL CHECK(total_amount >= 0),
    quantity REAL,
    unit_price REAL,
    currency_code TEXT DEFAULT 'USD',
    transaction_type TEXT CHECK(transaction_type IN ('PO', 'Invoice', 'Payment', 'Credit')),
    fiscal_year INTEGER,
    fiscal_quarter INTEGER,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id),
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id),
    FOREIGN KEY (contract_id) REFERENCES contracts(contract_id),
    FOREIGN KEY (business_unit_id) REFERENCES business_units(business_unit_id),
    FOREIGN KEY (po_id) REFERENCES purchase_orders(po_id)
);

-- =====================================================
-- SUPPORTING TABLES
-- =====================================================

-- Supplier Profiles (Extended vendor information)
CREATE TABLE supplier_profiles (
    vendor_id TEXT PRIMARY KEY,
    annual_revenue REAL,
    employee_count INTEGER,
    years_in_business INTEGER,
    certifications TEXT, -- JSON array of certifications
    insurance_expiry DATE,
    last_audit_date DATE,
    audit_score REAL CHECK(audit_score >= 0 AND audit_score <= 100),
    risk_rating TEXT CHECK(risk_rating IN ('Low', 'Medium', 'High', 'Critical')),
    esg_score REAL CHECK(esg_score >= 0 AND esg_score <= 100),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id)
);

-- Commodity Profiles (Extended commodity information)
CREATE TABLE commodity_profiles (
    commodity_id TEXT PRIMARY KEY,
    business_criticality TEXT CHECK(business_criticality IN ('Critical', 'High', 'Medium', 'Low')),
    sourcing_complexity TEXT CHECK(sourcing_complexity IN ('Simple', 'Moderate', 'Complex', 'Strategic')),
    category_manager TEXT,
    procurement_strategy TEXT,
    market_volatility TEXT CHECK(market_volatility IN ('Low', 'Medium', 'High')),
    supply_risk TEXT CHECK(supply_risk IN ('Low', 'Medium', 'High')),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id)
);

-- Sourcing Strategies
CREATE TABLE sourcing_strategies (
    strategy_id TEXT PRIMARY KEY,
    commodity_id TEXT NOT NULL,
    strategy_name TEXT NOT NULL,
    strategy_type TEXT CHECK(strategy_type IN ('Single Source', 'Multi Source', 'Sole Source', 'Competitive')),
    strategy_description TEXT,
    implementation_date DATE,
    review_date DATE,
    status TEXT CHECK(status IN ('Active', 'Under Review', 'Deprecated')),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id)
);

-- Time Periods (Fiscal calendar reference)
CREATE TABLE time_periods (
    period_id INTEGER PRIMARY KEY,
    period_name TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    fiscal_year INTEGER NOT NULL,
    fiscal_quarter INTEGER CHECK(fiscal_quarter >= 1 AND fiscal_quarter <= 4),
    fiscal_month INTEGER CHECK(fiscal_month >= 1 AND fiscal_month <= 12),
    is_current_period BOOLEAN DEFAULT 0
);

-- Savings Targets
CREATE TABLE savings_targets (
    target_id TEXT PRIMARY KEY,
    commodity_id TEXT,
    business_unit_id TEXT,
    fiscal_year INTEGER NOT NULL,
    target_amount REAL NOT NULL CHECK(target_amount >= 0),
    target_percentage REAL CHECK(target_percentage >= 0 AND target_percentage <= 100),
    target_type TEXT CHECK(target_type IN ('Hard Savings', 'Soft Savings', 'Cost Avoidance')),
    status TEXT CHECK(status IN ('Draft', 'Approved', 'Active', 'Achieved', 'Missed')),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id),
    FOREIGN KEY (business_unit_id) REFERENCES business_units(business_unit_id)
);

-- Demand Forecasts
CREATE TABLE demand_forecasts (
    forecast_id TEXT PRIMARY KEY,
    commodity_id TEXT NOT NULL,
    business_unit_id TEXT,
    forecast_period_start DATE NOT NULL,
    forecast_period_end DATE NOT NULL,
    forecasted_quantity REAL CHECK(forecasted_quantity >= 0),
    forecasted_value REAL CHECK(forecasted_value >= 0),
    confidence_level TEXT CHECK(confidence_level IN ('High', 'Medium', 'Low')),
    forecast_method TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id),
    FOREIGN KEY (business_unit_id) REFERENCES business_units(business_unit_id)
);

-- Risk Assessments
CREATE TABLE risk_assessments (
    assessment_id TEXT PRIMARY KEY,
    vendor_id TEXT,
    commodity_id TEXT,
    risk_type TEXT CHECK(risk_type IN ('Financial', 'Operational', 'Strategic', 'Compliance', 'ESG', 'Cyber')),
    risk_level TEXT CHECK(risk_level IN ('Low', 'Medium', 'High', 'Critical')),
    risk_description TEXT,
    mitigation_plan TEXT,
    assessment_date DATE NOT NULL,
    next_review_date DATE,
    status TEXT CHECK(status IN ('Open', 'Mitigated', 'Accepted', 'Transferred')),
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id),
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id)
);

-- Market Intelligence
CREATE TABLE market_intelligence (
    intelligence_id TEXT PRIMARY KEY,
    commodity_id TEXT NOT NULL,
    market_trend TEXT,
    price_trend TEXT CHECK(price_trend IN ('Increasing', 'Stable', 'Decreasing', 'Volatile')),
    supply_outlook TEXT CHECK(supply_outlook IN ('Abundant', 'Adequate', 'Tight', 'Shortage')),
    market_data TEXT, -- JSON for flexible market data
    data_source TEXT,
    report_date DATE NOT NULL,
    validity_period_end DATE,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by TEXT,
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id)
);

-- Performance Metrics
CREATE TABLE performance_metrics (
    metric_id TEXT PRIMARY KEY,
    vendor_id TEXT,
    commodity_id TEXT,
    metric_type TEXT CHECK(metric_type IN ('Delivery', 'Quality', 'Service', 'Cost', 'Innovation')),
    metric_name TEXT NOT NULL,
    metric_value REAL,
    target_value REAL,
    measurement_period_start DATE,
    measurement_period_end DATE,
    measurement_unit TEXT,
    created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (vendor_id) REFERENCES vendors(vendor_id),
    FOREIGN KEY (commodity_id) REFERENCES commodities(commodity_id)
);

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Master Data Indexes
CREATE INDEX idx_vendors_name ON vendors(vendor_name);
CREATE INDEX idx_vendors_tier ON vendors(vendor_tier);
CREATE INDEX idx_commodities_category ON commodities(parent_category, sub_category);

-- Transaction Indexes
CREATE INDEX idx_spend_vendor ON spend_transactions(vendor_id);
CREATE INDEX idx_spend_commodity ON spend_transactions(commodity_id);
CREATE INDEX idx_spend_date ON spend_transactions(transaction_date);
CREATE INDEX idx_spend_fiscal ON spend_transactions(fiscal_year, fiscal_quarter);
CREATE INDEX idx_spend_amount ON spend_transactions(total_amount);

-- Contract Indexes
CREATE INDEX idx_contracts_vendor ON contracts(vendor_id);
CREATE INDEX idx_contracts_status ON contracts(contract_status);
CREATE INDEX idx_contracts_dates ON contracts(start_date, end_date);

-- PO Indexes
CREATE INDEX idx_po_vendor ON purchase_orders(vendor_id);
CREATE INDEX idx_po_status ON purchase_orders(po_status);
CREATE INDEX idx_po_date ON purchase_orders(po_date);

-- =====================================================
-- OPERATIONAL VIEWS
-- =====================================================

-- Active Contracts View
CREATE VIEW vw_active_contracts AS
SELECT 
    c.*,
    v.vendor_name,
    v.vendor_tier
FROM contracts c
JOIN vendors v ON c.vendor_id = v.vendor_id
WHERE c.contract_status = 'Active'
  AND (c.end_date IS NULL OR c.end_date >= DATE('now'));

-- Current Fiscal Year Spend View
CREATE VIEW vw_current_fy_spend AS
SELECT 
    st.*,
    v.vendor_name,
    v.vendor_tier,
    c.commodity_description,
    c.parent_category
FROM spend_transactions st
JOIN vendors v ON st.vendor_id = v.vendor_id
JOIN commodities c ON st.commodity_id = c.commodity_id
WHERE st.fiscal_year = (
    SELECT MAX(fiscal_year) FROM spend_transactions
);

-- Contract Expiry Alert View
CREATE VIEW vw_contract_expiry_alerts AS
SELECT 
    c.contract_id,
    c.contract_name,
    c.vendor_id,
    v.vendor_name,
    c.end_date,
    julianday(c.end_date) - julianday('now') as days_to_expiry,
    CASE 
        WHEN julianday(c.end_date) - julianday('now') <= 30 THEN 'Critical'
        WHEN julianday(c.end_date) - julianday('now') <= 90 THEN 'Warning'
        ELSE 'Monitor'
    END as alert_level
FROM contracts c
JOIN vendors v ON c.vendor_id = v.vendor_id
WHERE c.contract_status = 'Active'
  AND c.end_date IS NOT NULL
  AND c.end_date >= DATE('now')
ORDER BY c.end_date;

-- =====================================================
-- DATA QUALITY TRIGGERS
-- =====================================================

-- Auto-update fiscal periods
CREATE TRIGGER trg_auto_fiscal_year
BEFORE INSERT ON spend_transactions
FOR EACH ROW
WHEN NEW.fiscal_year IS NULL
BEGIN
    UPDATE spend_transactions SET
        fiscal_year = CASE 
            WHEN strftime('%m', NEW.transaction_date) >= '04' 
            THEN CAST(strftime('%Y', NEW.transaction_date) AS INTEGER) + 1
            ELSE CAST(strftime('%Y', NEW.transaction_date) AS INTEGER)
        END,
        fiscal_quarter = CASE 
            WHEN strftime('%m', NEW.transaction_date) IN ('04', '05', '06') THEN 1
            WHEN strftime('%m', NEW.transaction_date) IN ('07', '08', '09') THEN 2
            WHEN strftime('%m', NEW.transaction_date) IN ('10', '11', '12') THEN 3
            ELSE 4
        END
    WHERE transaction_id = NEW.transaction_id;
END;

-- Validate PO line amounts
CREATE TRIGGER trg_validate_po_line_amount
BEFORE INSERT ON po_line_items
FOR EACH ROW
WHEN ABS(NEW.line_amount - (NEW.quantity * NEW.unit_price)) > 0.01
BEGIN
    SELECT RAISE(ABORT, 'Line amount must equal quantity * unit_price');
END;
