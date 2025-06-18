-- =====================================================
-- ETL Transformation Queries
-- =====================================================
-- These queries support the ETL process between 
-- operational and analytics databases

-- =====================================================
-- DIMENSION POPULATION QUERIES
-- =====================================================

-- Populate dim_vendors from operational vendors
INSERT INTO dim_vendors (
    vendor_id, vendor_name, vendor_tier, diversity_classification,
    risk_rating, country, region, effective_start_date, is_current_record
)
SELECT DISTINCT
    v.vendor_id,
    v.vendor_name,
    v.vendor_tier,
    v.diversity_classification,
    COALESCE(sp.risk_rating, 'Medium') as risk_rating,
    v.country,
    v.region,
    DATE('now') as effective_start_date,
    1 as is_current_record
FROM vendors v
LEFT JOIN supplier_profiles sp ON v.vendor_id = sp.vendor_id
WHERE v.is_active = 1
  AND v.vendor_id NOT IN (SELECT vendor_id FROM dim_vendors WHERE is_current_record = 1);

-- Populate dim_commodities from operational commodities
INSERT INTO dim_commodities (
    commodity_id, commodity_description, parent_category, sub_category,
    business_criticality, sourcing_complexity, category_manager,
    effective_start_date, is_current_record
)
SELECT DISTINCT
    c.commodity_id,
    c.commodity_description,
    c.parent_category,
    c.sub_category,
    COALESCE(cp.business_criticality, 'Medium') as business_criticality,
    COALESCE(cp.sourcing_complexity, 'Moderate') as sourcing_complexity,
    cp.category_manager,
    DATE('now') as effective_start_date,
    1 as is_current_record
FROM commodities c
LEFT JOIN commodity_profiles cp ON c.commodity_id = cp.commodity_id
WHERE c.is_active = 1
  AND c.commodity_id NOT IN (SELECT commodity_id FROM dim_commodities WHERE is_current_record = 1);

-- Populate dim_time for date range
INSERT INTO dim_time (
    time_key, date_actual, year, quarter, month, fiscal_year, fiscal_quarter,
    month_name, quarter_name, day_of_week, week_of_year, is_weekend
)
WITH RECURSIVE date_series AS (
    SELECT DATE('2009-01-01') as date_actual
    UNION ALL
    SELECT DATE(date_actual, '+1 day')
    FROM date_series
    WHERE date_actual < DATE('2030-12-31')
)
SELECT DISTINCT
    CAST(STRFTIME('%Y%m%d', date_actual) AS INTEGER) as time_key,
    date_actual,
    CAST(STRFTIME('%Y', date_actual) AS INTEGER) as year,
    CAST((STRFTIME('%m', date_actual) - 1) / 3 + 1 AS INTEGER) as quarter,
    CAST(STRFTIME('%m', date_actual) AS INTEGER) as month,
    CASE 
        WHEN STRFTIME('%m', date_actual) >= '04' 
        THEN CAST(STRFTIME('%Y', date_actual) AS INTEGER) + 1
        ELSE CAST(STRFTIME('%Y', date_actual) AS INTEGER)
    END as fiscal_year,
    CASE 
        WHEN STRFTIME('%m', date_actual) IN ('04', '05', '06') THEN 1
        WHEN STRFTIME('%m', date_actual) IN ('07', '08', '09') THEN 2
        WHEN STRFTIME('%m', date_actual) IN ('10', '11', '12') THEN 3
        ELSE 4
    END as fiscal_quarter,
    CASE STRFTIME('%m', date_actual)
        WHEN '01' THEN 'January' WHEN '02' THEN 'February' WHEN '03' THEN 'March'
        WHEN '04' THEN 'April' WHEN '05' THEN 'May' WHEN '06' THEN 'June'
        WHEN '07' THEN 'July' WHEN '08' THEN 'August' WHEN '09' THEN 'September'
        WHEN '10' THEN 'October' WHEN '11' THEN 'November' WHEN '12' THEN 'December'
    END as month_name,
    'Q' || CAST((STRFTIME('%m', date_actual) - 1) / 3 + 1 AS INTEGER) as quarter_name,
    CASE STRFTIME('%w', date_actual)
        WHEN '0' THEN 'Sunday' WHEN '1' THEN 'Monday' WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday' WHEN '4' THEN 'Thursday' WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END as day_of_week,
    CAST(STRFTIME('%W', date_actual) AS INTEGER) as week_of_year,
    CASE WHEN STRFTIME('%w', date_actual) IN ('0', '6') THEN 1 ELSE 0 END as is_weekend
FROM date_series
WHERE CAST(STRFTIME('%Y%m%d', date_actual) AS INTEGER) NOT IN (
    SELECT time_key FROM dim_time
);

-- =====================================================
-- FACT TABLE POPULATION QUERIES
-- =====================================================

-- Populate fact_spend_analytics from operational spend_transactions
INSERT INTO fact_spend_analytics (
    vendor_key, commodity_key, time_key, spend_amount, transaction_count,
    quantity, unit_price, source_transaction_id, load_date
)
SELECT 
    dv.vendor_key,
    dc.commodity_key,
    dt.time_key,
    st.total_amount,
    1 as transaction_count,
    st.quantity,
    st.unit_price,
    CAST(st.transaction_id AS TEXT) as source_transaction_id,
    DATE('now') as load_date
FROM spend_transactions st
JOIN dim_vendors dv ON st.vendor_id = dv.vendor_id AND dv.is_current_record = 1
JOIN dim_commodities dc ON st.commodity_id = dc.commodity_id AND dc.is_current_record = 1
JOIN dim_time dt ON dt.time_key = CAST(STRFTIME('%Y%m%d', st.transaction_date) AS INTEGER)
WHERE st.transaction_id NOT IN (
    SELECT CAST(source_transaction_id AS INTEGER)
    FROM fact_spend_analytics 
    WHERE source_transaction_id IS NOT NULL
);

-- =====================================================
-- INCREMENTAL ETL QUERIES
-- =====================================================

-- Incremental vendor updates (SCD Type 2)
INSERT INTO dim_vendors (
    vendor_id, vendor_name, vendor_tier, diversity_classification,
    risk_rating, country, region, effective_start_date, is_current_record
)
SELECT 
    v.vendor_id,
    v.vendor_name,
    v.vendor_tier,
    v.diversity_classification,
    COALESCE(sp.risk_rating, 'Medium'),
    v.country,
    v.region,
    DATE('now'),
    1
FROM vendors v
LEFT JOIN supplier_profiles sp ON v.vendor_id = sp.vendor_id
JOIN dim_vendors dv_existing ON v.vendor_id = dv_existing.vendor_id 
    AND dv_existing.is_current_record = 1
WHERE (
    v.vendor_name != dv_existing.vendor_name OR
    v.vendor_tier != dv_existing.vendor_tier OR
    v.diversity_classification != dv_existing.diversity_classification OR
    COALESCE(sp.risk_rating, 'Medium') != dv_existing.risk_rating OR
    v.country != dv_existing.country OR
    v.region != dv_existing.region
);

-- Close previous vendor records when changes detected
UPDATE dim_vendors 
SET 
    is_current_record = 0,
    effective_end_date = DATE('now', '-1 day')
WHERE vendor_id IN (
    SELECT DISTINCT dv_new.vendor_id
    FROM dim_vendors dv_new
    WHERE dv_new.effective_start_date = DATE('now')
      AND dv_new.is_current_record = 1
)
AND effective_start_date < DATE('now')
AND is_current_record = 1;

-- Incremental fact table updates (daily)
INSERT INTO fact_spend_analytics (
    vendor_key, commodity_key, time_key, spend_amount, transaction_count,
    quantity, unit_price, source_transaction_id, load_date
)
SELECT 
    dv.vendor_key,
    dc.commodity_key,
    dt.time_key,
    st.total_amount,
    1,
    st.quantity,
    st.unit_price,
    CAST(st.transaction_id AS TEXT),
    DATE('now')
FROM spend_transactions st
JOIN dim_vendors dv ON st.vendor_id = dv.vendor_id AND dv.is_current_record = 1
JOIN dim_commodities dc ON st.commodity_id = dc.commodity_id AND dc.is_current_record = 1
JOIN dim_time dt ON dt.time_key = CAST(STRFTIME('%Y%m%d', st.transaction_date) AS INTEGER)
WHERE st.transaction_date >= DATE('now', '-7 days')  -- Last week's transactions
  AND st.transaction_id NOT IN (
    SELECT CAST(source_transaction_id AS INTEGER)
    FROM fact_spend_analytics 
    WHERE source_transaction_id IS NOT NULL
  );

-- =====================================================
-- DATA QUALITY AND RECONCILIATION QUERIES
-- =====================================================

-- Vendor count reconciliation
SELECT 
    'Vendor Count Check' as check_name,
    op.operational_count,
    an.analytics_count,
    op.operational_count - an.analytics_count as variance
FROM (
    SELECT COUNT(*) as operational_count FROM vendors WHERE is_active = 1
) op
CROSS JOIN (
    SELECT COUNT(*) as analytics_count FROM dim_vendors WHERE is_current_record = 1
) an;

-- Spend amount reconciliation
SELECT 
    'Spend Amount Check' as check_name,
    op.operational_spend,
    an.analytics_spend,
    op.operational_spend - an.analytics_spend as variance,
    ROUND((an.analytics_spend / op.operational_spend) * 100, 2) as coverage_percentage
FROM (
    SELECT SUM(total_amount) as operational_spend 
    FROM spend_transactions 
    WHERE transaction_date >= '2009-01-01'
) op
CROSS JOIN (
    SELECT SUM(spend_amount) as analytics_spend 
    FROM fact_spend_analytics
) an;

-- Transaction count by fiscal year
SELECT 
    'Transaction Count by FY' as check_name,
    op.fiscal_year,
    op.operational_count,
    an.analytics_count,
    op.operational_count - an.analytics_count as variance
FROM (
    SELECT 
        fiscal_year,
        COUNT(*) as operational_count
    FROM spend_transactions 
    GROUP BY fiscal_year
) op
FULL OUTER JOIN (
    SELECT 
        dt.fiscal_year,
        COUNT(*) as analytics_count
    FROM fact_spend_analytics fsa
    JOIN dim_time dt ON fsa.time_key = dt.time_key
    GROUP BY dt.fiscal_year
) an ON op.fiscal_year = an.fiscal_year
ORDER BY op.fiscal_year;

-- Orphaned records check
SELECT 
    'Orphaned Fact Records' as check_name,
    COUNT(*) as orphaned_count
FROM fact_spend_analytics fsa
LEFT JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
LEFT JOIN dim_commodities dc ON fsa.commodity_key = dc.commodity_key
LEFT JOIN dim_time dt ON fsa.time_key = dt.time_key
WHERE dv.vendor_key IS NULL 
   OR dc.commodity_key IS NULL 
   OR dt.time_key IS NULL;

-- =====================================================
-- PERFORMANCE OPTIMIZATION QUERIES
-- =====================================================

-- Update table statistics
ANALYZE dim_vendors;
ANALYZE dim_commodities;
ANALYZE dim_time;
ANALYZE fact_spend_analytics;

-- Vacuum to reclaim space
-- Note: Run these during maintenance windows
-- VACUUM;

-- =====================================================
-- ETL MONITORING QUERIES
-- =====================================================

-- ETL run summary
SELECT 
    'ETL Summary' as report_type,
    MAX(load_date) as last_etl_date,
    COUNT(DISTINCT load_date) as total_etl_runs,
    COUNT(*) as total_records_loaded,
    MIN(load_date) as first_etl_date
FROM fact_spend_analytics;

-- Daily ETL volume
SELECT 
    load_date,
    COUNT(*) as records_loaded,
    SUM(spend_amount) as total_spend_loaded,
    COUNT(DISTINCT vendor_key) as vendors_affected,
    COUNT(DISTINCT commodity_key) as commodities_affected
FROM fact_spend_analytics
WHERE load_date >= DATE('now', '-30 days')
GROUP BY load_date
ORDER BY load_date DESC;

-- Data freshness check
SELECT 
    'Data Freshness' as check_type,
    MAX(dt.date_actual) as latest_transaction_date,
    DATE('now') as current_date,
    julianday('now') - julianday(MAX(dt.date_actual)) as days_behind
FROM fact_spend_analytics fsa
JOIN dim_time dt ON fsa.time_key = dt.time_key;
