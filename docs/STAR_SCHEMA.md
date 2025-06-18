# STAR Schema Documentation

## Overview

The Procurement Analytics database implements a STAR schema design optimized for fast analytical queries and C-Suite reporting. This document details the schema structure, relationships, and design decisions.

## Schema Architecture

```
                    ┌─────────────────┐
                    │  fact_spend_    │
                    │   analytics     │◄──┐
                    │                 │   │
                    │ • spend_amount  │   │
                    │ • quantity      │   │
                    │ • unit_price    │   │
                    │ • performance   │   │
                    │ • risk_metrics  │   │
                    │ • savings       │   │
                    └─────────────────┘   │
                            │             │
                    ┌───────┼─────────┐   │
                    │       │         │   │
                    ▼       ▼         ▼   │
              ┌─────────┐ ┌─────────┐ ┌───▼─────┐
              │  dim_   │ │  dim_   │ │  dim_   │
              │vendors  │ │commoditi│ │  time   │
              │         │ │   es    │ │         │
              │• vendor │ │• categor│ │• fiscal │
              │  master │ │  hierarchy│ │  periods│
              │• risk   │ │• business│ │• calendar│
              │• ESG    │ │  critical│ │  attribs│
              │• tier   │ │• sourcing│ │         │
              └─────────┘ └─────────┘ └─────────┘
```

## Dimension Tables

### dim_vendors
**Purpose**: Master data for all suppliers with historical tracking (SCD Type 2)

| Column | Type | Description |
|--------|------|-------------|
| vendor_key | INTEGER PK | Surrogate key |
| vendor_id | TEXT | Natural business key |
| vendor_name | TEXT | Company name |
| vendor_tier | TEXT | Strategic/Preferred/Approved/Tactical |
| diversity_classification | TEXT | Minority/Women/Veteran/Small Business |
| risk_rating | TEXT | Low/Medium/High/Critical |
| esg_score | REAL | 0-100 sustainability score |
| country | TEXT | Supplier location |
| region | TEXT | Geographic region |
| effective_start_date | DATE | SCD Type 2 start date |
| effective_end_date | DATE | SCD Type 2 end date |
| is_current_record | BOOLEAN | Active record flag |

**Key Features**:
- Slowly Changing Dimension Type 2 for historical tracking
- Supports vendor tier changes over time
- ESG scoring for sustainability reporting
- Risk rating for supplier risk dashboards

### dim_commodities
**Purpose**: Product and service categorization hierarchy

| Column | Type | Description |
|--------|------|-------------|
| commodity_key | INTEGER PK | Surrogate key |
| commodity_id | TEXT | Natural business key |
| commodity_description | TEXT | Product/service description |
| parent_category | TEXT | Top-level category |
| sub_category | TEXT | Detailed subcategory |
| business_criticality | TEXT | Critical/High/Medium/Low |
| sourcing_complexity | TEXT | Simple/Moderate/Complex/Strategic |
| category_manager | TEXT | Responsible procurement manager |

**Key Features**:
- Hierarchical category structure
- Business criticality for risk assessment
- Sourcing complexity for process optimization
- Category manager assignment tracking

### dim_time
**Purpose**: Comprehensive time dimension with fiscal calendar support

| Column | Type | Description |
|--------|------|-------------|
| time_key | INTEGER PK | Date in YYYYMMDD format |
| date_actual | DATE | Actual calendar date |
| year | INTEGER | Calendar year |
| quarter | INTEGER | Calendar quarter (1-4) |
| month | INTEGER | Calendar month (1-12) |
| fiscal_year | INTEGER | Fiscal year (April-March) |
| fiscal_quarter | INTEGER | Fiscal quarter (1-4) |
| month_name | TEXT | Month name |
| quarter_name | TEXT | Quarter label (Q1, Q2, etc.) |
| day_of_week | TEXT | Day name |
| week_of_year | INTEGER | Week number (1-53) |
| is_weekend | BOOLEAN | Weekend flag |

**Key Features**:
- Fiscal year support (April-March cycle)
- Calendar and fiscal period alignment
- Weekend and holiday support
- Optimized for time-based aggregations

## Fact Tables

### fact_spend_analytics
**Purpose**: Core transactional spend data with performance metrics

| Column | Type | Description |
|--------|------|-------------|
| fact_key | INTEGER PK | Surrogate key |
| vendor_key | INTEGER FK | Link to dim_vendors |
| commodity_key | INTEGER FK | Link to dim_commodities |
| time_key | INTEGER FK | Link to dim_time |
| spend_amount | REAL | Transaction amount |
| transaction_count | INTEGER | Number of transactions |
| quantity | REAL | Quantity purchased |
| unit_price | REAL | Price per unit |
| delivery_performance_score | REAL | 0-100 OTIF score |
| quality_score | REAL | 0-100 quality rating |
| compliance_score | REAL | 0-100 compliance rating |
| risk_weighted_spend | REAL | Spend × risk factor |
| esg_weighted_spend | REAL | Spend × ESG factor |
| savings_amount | REAL | Negotiated savings |
| source_transaction_id | TEXT | Original transaction reference |

**Key Features**:
- Grain: One record per transaction
- Performance metrics for supplier scorecards
- Risk and ESG weighting for advanced analytics
- Savings tracking for ROI reporting
- Audit trail to operational data

## Future Enhancement Tables

### dim_contracts (Future)
- Contract master data with lifecycle tracking
- Contract types, terms, and renewal dates
- Integration with contract management systems

### dim_business_units (Future)
- Organizational hierarchy
- Cost center and budget tracking
- Regional and divisional reporting

### fact_supplier_performance (Future)
- Dedicated performance metrics fact table
- OTIF, quality, and service KPIs
- Monthly/quarterly aggregations

### fact_savings_realization (Future)
- Savings tracking and validation
- Hard vs. soft savings classification
- Initiative-level attribution

## Performance Optimizations

### Indexing Strategy
```sql
-- Primary fact table indexes
CREATE INDEX idx_fact_spend_vendor ON fact_spend_analytics(vendor_key);
CREATE INDEX idx_fact_spend_commodity ON fact_spend_analytics(commodity_key);
CREATE INDEX idx_fact_spend_time ON fact_spend_analytics(time_key);

-- Composite indexes for common queries
CREATE INDEX idx_fact_spend_vendor_time ON fact_spend_analytics(vendor_key, time_key);
CREATE INDEX idx_fact_spend_commodity_time ON fact_spend_analytics(commodity_key, time_key);
```

### Query Optimization
- Foreign key constraints ensure referential integrity
- Proper data types for efficient storage
- Calculated columns for common aggregations
- Views for frequently accessed data combinations

## Data Quality Constraints

### Business Rules
- Spend amounts cannot be negative
- Performance scores range from 0-100
- Time keys must be valid YYYYMMDD format
- All fact records must have valid dimension keys

### Triggers
```sql
-- Prevent negative spend
CREATE TRIGGER trg_validate_spend_amount
BEFORE INSERT ON fact_spend_analytics
FOR EACH ROW
WHEN NEW.spend_amount < 0
BEGIN
    SELECT RAISE(ABORT, 'Spend amount cannot be negative.');
END;
```

## Common Query Patterns

### Monthly Spend by Category
```sql
SELECT 
    dt.fiscal_year,
    dt.month_name,
    dc.parent_category,
    SUM(fsa.spend_amount) as total_spend
FROM fact_spend_analytics fsa
JOIN dim_time dt ON fsa.time_key = dt.time_key
JOIN dim_commodities dc ON fsa.commodity_key = dc.commodity_key
GROUP BY dt.fiscal_year, dt.month_name, dc.parent_category;
```

### Top Vendor Performance
```sql
SELECT 
    dv.vendor_name,
    SUM(fsa.spend_amount) as total_spend,
    AVG(fsa.delivery_performance_score) as avg_delivery,
    AVG(fsa.quality_score) as avg_quality
FROM fact_spend_analytics fsa
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
WHERE dv.is_current_record = 1
GROUP BY dv.vendor_name
ORDER BY total_spend DESC;
```

### Risk-Weighted Spend Analysis
```sql
SELECT 
    dv.risk_rating,
    COUNT(DISTINCT dv.vendor_key) as vendor_count,
    SUM(fsa.spend_amount) as total_spend,
    SUM(fsa.risk_weighted_spend) as risk_weighted_spend
FROM fact_spend_analytics fsa
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
WHERE dv.is_current_record = 1
GROUP BY dv.risk_rating;
```

## Maintenance Procedures

### Daily Tasks
- ETL new transactions from operational database
- Update dimension records for changed data
- Validate data quality and consistency

### Weekly Tasks
- Update table statistics for query optimization
- Review performance metrics and slow queries
- Backup analytics database

### Monthly Tasks
- Archive old transactions if needed
- Update dimension hierarchies
- Performance tuning and index optimization

## Integration Points

### Operational Database
- Source of all transactional data
- Master data for vendors and commodities
- Real-time operational queries

### Reporting Tools
- Power BI/Tableau dashboard connections
- C-Suite executive reporting
- Ad-hoc analytical queries

### External Systems
- ERP system integration for real-time data
- Risk management platform data feeds
- ESG scoring service integration

---

*This schema supports all 17 C-Suite procurement reports and provides the foundation for advanced procurement analytics and insights.*
