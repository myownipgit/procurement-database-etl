import sqlite3
import shutil

# Create the new analytics database at your path
analytics_db_path = "/Users/myownip/db_dev/procurement_analytics.db"
analytics_conn = sqlite3.connect(analytics_db_path)

# Create STAR schema structure in new database
analytics_conn.execute("""
CREATE TABLE dim_vendors (
    vendor_key INTEGER PRIMARY KEY,
    vendor_id TEXT,
    vendor_name TEXT,
    vendor_tier TEXT,
    diversity_classification TEXT,
    risk_rating TEXT,
    esg_score REAL,
    country TEXT,
    region TEXT,
    effective_start_date DATE,
    effective_end_date DATE,
    is_current_record BOOLEAN
);
""")

analytics_conn.execute("""
CREATE TABLE dim_commodities (
    commodity_key INTEGER PRIMARY KEY,
    commodity_id TEXT,
    commodity_description TEXT,
    parent_category TEXT,
    sub_category TEXT,
    business_criticality TEXT,
    sourcing_complexity TEXT,
    category_manager TEXT,
    effective_start_date DATE,
    is_current_record BOOLEAN
);
""")

analytics_conn.execute("""
CREATE TABLE dim_time (
    time_key INTEGER PRIMARY KEY,
    date_actual DATE,
    year INTEGER,
    quarter INTEGER,
    month INTEGER,
    fiscal_year INTEGER,
    fiscal_quarter INTEGER,
    month_name TEXT,
    quarter_name TEXT,
    day_of_week TEXT,
    week_of_year INTEGER
);
""")

analytics_conn.execute("""
CREATE TABLE fact_spend_analytics (
    fact_key INTEGER PRIMARY KEY,
    vendor_key INTEGER,
    commodity_key INTEGER,
    contract_key INTEGER,
    time_key INTEGER,
    business_unit_key INTEGER,
    spend_amount REAL,
    transaction_count INTEGER,
    quantity REAL,
    unit_price REAL,
    delivery_performance_score REAL,
    quality_score REAL,
    compliance_score REAL,
    risk_weighted_spend REAL,
    esg_weighted_spend REAL,
    savings_amount REAL,
    discount_amount REAL,
    source_transaction_id TEXT,
    load_date DATE,
    FOREIGN KEY (vendor_key) REFERENCES dim_vendors(vendor_key),
    FOREIGN KEY (commodity_key) REFERENCES dim_commodities(commodity_key),
    FOREIGN KEY (time_key) REFERENCES dim_time(time_key)
);
""")

analytics_conn.close()
print("✅ Analytics database created successfully!")
