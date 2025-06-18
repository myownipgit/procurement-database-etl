# ETL Process Documentation

## Overview

This document describes the Extract, Transform, Load (ETL) processes that maintain data synchronization between the operational procurement database and the analytics STAR schema database.

## ETL Architecture

```
┌─────────────────┐    ETL     ┌─────────────────┐    Reports   ┌─────────────────┐
│   Operational   │   ──────►  │   Analytics     │   ────────►  │   C-Suite       │
│   Database      │            │   Database      │              │   Dashboards    │
│                 │            │                 │              │                 │
│ • vendors       │            │ • dim_vendors   │              │ • Supplier      │
│ • transactions  │            │ • dim_commoditi │              │   Performance   │
│ • contracts     │            │ • dim_time      │              │ • Spend         │
│ • commodities   │            │ • fact_spend    │              │   Analysis      │
│ • ...           │            │   _analytics    │              │ • Risk          │
└─────────────────┘            └─────────────────┘              │   Dashboard     │
                                                                 │ • ...           │
                                                                 └─────────────────┘
```

## ETL Components

### 1. Data Extraction
**Source**: Operational Database (`procurement_operational.db`)
**Target**: Analytics Database (`procurement_analytics.db`)
**Frequency**: Daily (with capability for real-time)

#### Key Tables Extracted:
- `vendors` → `dim_vendors`
- `commodities` → `dim_commodities` 
- `spend_transactions` → `fact_spend_analytics`
- `supplier_profiles` → Enhanced vendor dimensions
- `commodity_profiles` → Enhanced commodity dimensions

### 2. Data Transformation

#### Dimension Transformations

**Vendor Dimension (SCD Type 2)**
```python
# Pseudo-code for vendor transformation
for vendor in new_vendors:
    existing_vendor = get_current_vendor_record(vendor.vendor_id)
    
    if vendor_attributes_changed(vendor, existing_vendor):
        # Close current record
        close_vendor_record(existing_vendor)
        
        # Create new record with current data
        create_vendor_record(vendor, effective_date=today)
    
    elif vendor_not_exists(vendor.vendor_id):
        # New vendor - create first record
        create_vendor_record(vendor, effective_date=today)
```

**Time Dimension Population**
```sql
-- Generate time dimension for date range
WITH RECURSIVE date_series AS (
    SELECT DATE('2009-01-01') as date_actual
    UNION ALL
    SELECT DATE(date_actual, '+1 day')
    FROM date_series
    WHERE date_actual < DATE('2030-12-31')
)
INSERT INTO dim_time (
    time_key, date_actual, fiscal_year, fiscal_quarter, ...
)
SELECT 
    CAST(STRFTIME('%Y%m%d', date_actual) AS INTEGER),
    date_actual,
    CASE WHEN STRFTIME('%m', date_actual) >= '04' 
         THEN CAST(STRFTIME('%Y', date_actual) AS INTEGER) + 1
         ELSE CAST(STRFTIME('%Y', date_actual) AS INTEGER) END,
    -- Additional fiscal calendar logic...
FROM date_series;
```

#### Fact Table Transformations

**Spend Analytics Facts**
```sql
-- Transform operational transactions to analytical facts
INSERT INTO fact_spend_analytics (
    vendor_key, commodity_key, time_key, spend_amount, 
    transaction_count, source_transaction_id
)
SELECT 
    dv.vendor_key,
    dc.commodity_key,
    dt.time_key,
    st.total_amount,
    1,
    CAST(st.transaction_id AS TEXT)
FROM spend_transactions st
JOIN dim_vendors dv ON st.vendor_id = dv.vendor_id 
    AND dv.is_current_record = 1
JOIN dim_commodities dc ON st.commodity_id = dc.commodity_id 
    AND dc.is_current_record = 1
JOIN dim_time dt ON dt.time_key = 
    CAST(STRFTIME('%Y%m%d', st.transaction_date) AS INTEGER)
WHERE st.transaction_id NOT IN (
    SELECT CAST(source_transaction_id AS INTEGER)
    FROM fact_spend_analytics 
    WHERE source_transaction_id IS NOT NULL
);
```

### 3. Data Loading

#### Loading Strategy
- **Incremental Loading**: Only process new/changed records
- **Batch Processing**: Process data in configurable batch sizes
- **Transaction Management**: Ensure data consistency with commits/rollbacks
- **Error Handling**: Continue processing on non-critical errors

## ETL Execution Schedule

### Daily ETL (Primary)
**Time**: 2:00 AM daily
**Duration**: ~5-15 minutes
**Steps**:
1. Data validation and pre-checks
2. Extract new/changed operational data
3. Transform and load dimension updates
4. Transform and load new fact records
5. Data quality validation
6. Performance metrics update

### Weekly ETL (Comprehensive)
**Time**: Sunday 1:00 AM
**Duration**: ~30-60 minutes
**Steps**:
1. Full dimension refresh (SCD Type 2 cleanup)
2. Recalculate derived metrics
3. Update table statistics
4. Performance optimization
5. Data consistency validation

### Monthly ETL (Maintenance)
**Time**: First Saturday of month, 11:00 PM
**Duration**: ~1-2 hours
**Steps**:
1. Archive old data if needed
2. Reorganize and optimize indexes
3. Update dimension hierarchies
4. Performance tuning
5. Backup and recovery testing

## ETL Code Structure

### Python ETL Framework

```python
class SeparateDatabaseETL:
    def __init__(self):
        self.operational_db = "/path/to/operational.db"
        self.analytics_db = "/path/to/analytics.db"
        self.batch_size = 1000
        self.max_retries = 3
    
    def daily_etl(self):
        """Main daily ETL process"""
        try:
            self.validate_prerequisites()
            self.extract_and_load_dimensions()
            self.extract_and_load_facts()
            self.validate_data_quality()
            self.update_etl_log()
        except Exception as e:
            self.handle_etl_error(e)
            raise
    
    def extract_and_load_dimensions(self):
        """Process dimension table updates"""
        self.process_vendor_dimension()
        self.process_commodity_dimension()
        self.process_time_dimension()
    
    def extract_and_load_facts(self):
        """Process fact table updates"""
        self.process_spend_facts()
        self.process_performance_facts()  # Future
        self.process_savings_facts()      # Future
```

### Error Handling Strategy

```python
def handle_etl_error(self, error):
    """Comprehensive error handling"""
    error_types = {
        'DatabaseConnectionError': self.retry_connection,
        'DataValidationError': self.log_and_continue,
        'TransformationError': self.rollback_and_retry,
        'CriticalSystemError': self.alert_and_stop
    }
    
    handler = error_types.get(type(error).__name__, self.default_error_handler)
    handler(error)
```

## Data Quality Validation

### Pre-ETL Checks
1. **Database Connectivity**: Verify both databases accessible
2. **Schema Validation**: Ensure table structures match expectations
3. **Data Freshness**: Check for stale operational data
4. **Disk Space**: Verify sufficient space for processing

### Post-ETL Validation
1. **Row Count Reconciliation**: Compare source vs. target counts
2. **Sum Reconciliation**: Validate total spend amounts
3. **Referential Integrity**: Check for orphaned records
4. **Business Rule Validation**: Verify data meets business constraints

### Validation Queries

```sql
-- Row count validation
SELECT 
    'Vendor Count Check' as validation,
    op.count as operational_count,
    an.count as analytics_count,
    op.count - an.count as variance
FROM (
    SELECT COUNT(*) as count FROM vendors WHERE is_active = 1
) op
CROSS JOIN (
    SELECT COUNT(*) as count FROM dim_vendors WHERE is_current_record = 1
) an;

-- Spend reconciliation
SELECT 
    'Spend Reconciliation' as validation,
    ABS(op.total_spend - an.total_spend) as variance,
    CASE WHEN ABS(op.total_spend - an.total_spend) < 1000 
         THEN 'PASS' ELSE 'FAIL' END as status
FROM (
    SELECT SUM(total_amount) as total_spend FROM spend_transactions
) op
CROSS JOIN (
    SELECT SUM(spend_amount) as total_spend FROM fact_spend_analytics
) an;
```

## Performance Monitoring

### ETL Metrics Tracked
- **Processing Time**: Total and per-stage execution time
- **Record Counts**: Records processed, inserted, updated
- **Error Rates**: Failed records and error types
- **Data Quality Scores**: Validation pass/fail rates
- **System Resource Usage**: CPU, memory, disk I/O

### Performance Optimization

#### Database Optimizations
```sql
-- Enable WAL mode for better concurrency
PRAGMA journal_mode = WAL;

-- Optimize cache size
PRAGMA cache_size = -64000;  -- 64MB cache

-- Use memory for temporary storage
PRAGMA temp_store = MEMORY;

-- Batch insertions in transactions
BEGIN TRANSACTION;
-- Multiple INSERT statements
COMMIT;
```

#### Python Optimizations
```python
# Use executemany for batch operations
cursor.executemany(
    "INSERT INTO fact_spend_analytics (vendor_key, ...) VALUES (?, ...)",
    batch_data
)

# Connection pooling for multiple operations
with sqlite3.connect(db_path) as conn:
    conn.execute("PRAGMA synchronous = NORMAL")
    # Multiple operations...
```

## Monitoring and Alerting

### ETL Dashboard Metrics
1. **Last Successful Run**: Timestamp and duration
2. **Data Freshness**: Age of latest data in analytics
3. **Processing Volume**: Records processed per run
4. **Error Rate Trend**: Historical error patterns
5. **Performance Trend**: Processing time over time

### Alert Conditions
- ETL failure or timeout
- Data quality validation failures
- Significant variance in record counts
- Processing time exceeding thresholds
- Database connectivity issues

### Notification Methods
```python
class ETLAlerting:
    def send_alert(self, level, message):
        if level == 'CRITICAL':
            self.send_email(message)
            self.send_slack(message)
        elif level == 'WARNING':
            self.send_slack(message)
        
        self.log_alert(level, message)
```

## Recovery Procedures

### ETL Failure Recovery
1. **Identify Failure Point**: Check logs and error messages
2. **Assess Data Impact**: Determine records affected
3. **Rollback if Necessary**: Restore previous consistent state
4. **Fix Root Cause**: Address underlying issue
5. **Rerun ETL**: Execute recovery ETL process
6. **Validate Results**: Ensure data consistency restored

### Backup and Restore Strategy
```bash
# Daily backup before ETL
cp analytics.db analytics_backup_$(date +%Y%m%d).db

# Restore from backup if needed
cp analytics_backup_20250618.db analytics.db

# Verify restored database
sqlite3 analytics.db "SELECT COUNT(*) FROM fact_spend_analytics;"
```

## Future Enhancements

### Phase 2: Real-time ETL
- Change Data Capture (CDC) implementation
- Event-driven processing for critical updates
- Streaming ETL for near real-time analytics

### Phase 3: Advanced Features
- Machine learning model integration
- Automated anomaly detection
- Predictive analytics pipeline
- Advanced data lineage tracking

### Phase 4: Cloud Migration
- Cloud-native ETL services (AWS Glue, Azure Data Factory)
- Serverless processing architecture
- Auto-scaling based on data volume
- Advanced monitoring and observability

---

*This ETL process ensures reliable, consistent, and performant data synchronization between operational and analytical databases, enabling accurate C-Suite reporting and strategic decision-making.*
