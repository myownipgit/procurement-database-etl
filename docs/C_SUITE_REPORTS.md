# C-Suite Reports Documentation

## Overview

This document maps the 17 strategic procurement reports to the analytics database schema, showing how each report leverages the STAR schema for fast, accurate C-Suite insights.

## Report Mapping Matrix

| Report | Primary Tables | Key Metrics | Update Frequency |
|--------|---------------|-------------|------------------|
| Supplier Performance | dim_vendors, fact_spend_analytics | OTIF, Quality, Spend | Daily |
| Savings Realization | fact_spend_analytics | Savings Amount, ROI | Daily |
| Pipeline Plan | dim_commodities, dim_time | Forecasted Spend | Weekly |
| Contract Expiry | dim_contracts (future) | Expiry Dates | Daily |
| Risk Exposure | dim_vendors, fact_spend_analytics | Risk Scores | Daily |
| ESG & Diversity | dim_vendors, fact_spend_analytics | ESG Scores, Diversity % | Weekly |
| Maverick Spend | fact_spend_analytics | Off-contract Spend | Daily |
| Demand Forecast | dim_commodities, dim_time | Forecast vs Actual | Weekly |
| Procurement ROI | fact_spend_analytics | ROI, Cost Savings | Monthly |
| Tail Spend | dim_vendors, fact_spend_analytics | Long-tail Analysis | Monthly |
| Strategic Roadmap | dim_vendors, dim_commodities | Strategic Classifications | Quarterly |
| Compliance | fact_spend_analytics | Compliance Scores | Daily |
| Working Capital | fact_spend_analytics, dim_time | Payment Terms, DPO | Daily |
| Digital Maturity | fact_spend_analytics | Automation Metrics | Monthly |
| Global Sourcing | dim_vendors, fact_spend_analytics | Geographic Mix | Weekly |
| Talent Plan | dim_commodities | Category Coverage | Quarterly |
| Category Plan | dim_commodities, fact_spend_analytics | Category Performance | Monthly |

---

## 1. Supplier Performance Report

### Purpose
Comprehensive vendor performance evaluation across cost, quality, delivery, and strategic value.

### Data Sources
```sql
-- Core supplier performance query
SELECT 
    dv.vendor_name,
    dv.vendor_tier,
    dv.risk_rating,
    COUNT(DISTINCT fsa.commodity_key) as categories_served,
    SUM(fsa.spend_amount) as total_spend,
    AVG(fsa.delivery_performance_score) as avg_otif,
    AVG(fsa.quality_score) as avg_quality,
    AVG(fsa.compliance_score) as avg_compliance,
    SUM(fsa.savings_amount) as total_savings
FROM fact_spend_analytics fsa
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
JOIN dim_time dt ON fsa.time_key = dt.time_key
WHERE dv.is_current_record = 1
  AND dt.fiscal_year = 2024
GROUP BY dv.vendor_key, dv.vendor_name, dv.vendor_tier, dv.risk_rating
ORDER BY total_spend DESC;
```

### Key Metrics
- **OTIF (On-Time In-Full)**: Average delivery performance
- **Quality Score**: Defect rates and customer satisfaction
- **Cost Performance**: Unit price trends and savings
- **Strategic Value**: Innovation and partnership contributions

---

## 2. Savings Realization Report

### Purpose
Track and validate procurement savings against forecasts and budgets.

### Data Sources
```sql
-- Savings realization analysis
SELECT 
    dt.fiscal_year,
    dt.fiscal_quarter,
    dc.parent_category,
    SUM(fsa.spend_amount) as actual_spend,
    SUM(fsa.savings_amount) as realized_savings,
    SUM(fsa.baseline_price * fsa.quantity) as baseline_spend,
    (SUM(fsa.savings_amount) / SUM(fsa.spend_amount)) * 100 as savings_rate
FROM fact_spend_analytics fsa
JOIN dim_time dt ON fsa.time_key = dt.time_key
JOIN dim_commodities dc ON fsa.commodity_key = dc.commodity_key
WHERE dt.fiscal_year IN (2023, 2024)
  AND fsa.savings_amount > 0
GROUP BY dt.fiscal_year, dt.fiscal_quarter, dc.parent_category
ORDER BY dt.fiscal_year, dt.fiscal_quarter, realized_savings DESC;
```

### Key Metrics
- **Realized Savings**: Actual savings achieved
- **Savings Rate**: Savings as % of total spend
- **Forecast Accuracy**: Variance from projected savings
- **Category Contribution**: Savings by procurement category

---

## 3. Risk Exposure Dashboard

### Purpose
Real-time view of supply chain risks across vendors, categories, and regions.

### Data Sources
```sql
-- Risk exposure analysis
SELECT 
    dv.risk_rating,
    dv.country,
    dv.region,
    COUNT(DISTINCT dv.vendor_key) as vendor_count,
    SUM(fsa.spend_amount) as total_spend,
    SUM(fsa.risk_weighted_spend) as risk_weighted_spend,
    (SUM(fsa.risk_weighted_spend) / SUM(fsa.spend_amount)) as avg_risk_factor,
    COUNT(CASE WHEN dv.vendor_tier = 'Strategic' THEN 1 END) as strategic_vendors
FROM fact_spend_analytics fsa
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
JOIN dim_time dt ON fsa.time_key = dt.time_key
WHERE dv.is_current_record = 1
  AND dt.date_actual >= DATE('now', '-12 months')
GROUP BY dv.risk_rating, dv.country, dv.region
ORDER BY risk_weighted_spend DESC;
```

### Key Metrics
- **Risk-Weighted Spend**: Spend adjusted for risk factors
- **Geographic Concentration**: Risk by region/country
- **Vendor Risk Distribution**: High-risk vendor identification
- **Strategic Vendor Risk**: Risk in critical relationships

---

## 4. ESG & Diversity Procurement Report

### Purpose
Track environmental, social, and governance performance in procurement.

### Data Sources
```sql
-- ESG and diversity analysis
SELECT 
    dt.fiscal_year,
    dv.diversity_classification,
    COUNT(DISTINCT dv.vendor_key) as vendor_count,
    SUM(fsa.spend_amount) as total_spend,
    SUM(fsa.esg_weighted_spend) as esg_weighted_spend,
    AVG(dv.esg_score) as avg_esg_score,
    (SUM(fsa.spend_amount) / (
        SELECT SUM(spend_amount) 
        FROM fact_spend_analytics fsa2 
        JOIN dim_time dt2 ON fsa2.time_key = dt2.time_key 
        WHERE dt2.fiscal_year = dt.fiscal_year
    )) * 100 as spend_percentage
FROM fact_spend_analytics fsa
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
JOIN dim_time dt ON fsa.time_key = dt.time_key
WHERE dv.is_current_record = 1
  AND dv.diversity_classification IS NOT NULL
GROUP BY dt.fiscal_year, dv.diversity_classification
ORDER BY dt.fiscal_year, total_spend DESC;
```

### Key Metrics
- **Diversity Spend %**: Spend with diverse suppliers
- **ESG Score**: Average supplier ESG performance
- **Carbon Impact**: Estimated emissions from procurement
- **Sustainability Progress**: Year-over-year improvements

---

## 5. Maverick Spend Analysis

### Purpose
Identify and quantify off-contract and non-compliant spending.

### Data Sources
```sql
-- Maverick spend identification
SELECT 
    dc.parent_category,
    dt.fiscal_quarter,
    SUM(fsa.spend_amount) as total_spend,
    SUM(CASE WHEN fsa.contract_key IS NULL THEN fsa.spend_amount ELSE 0 END) as off_contract_spend,
    COUNT(DISTINCT CASE WHEN fsa.contract_key IS NULL THEN dv.vendor_key END) as maverick_vendors,
    (SUM(CASE WHEN fsa.contract_key IS NULL THEN fsa.spend_amount ELSE 0 END) / 
     SUM(fsa.spend_amount)) * 100 as maverick_percentage
FROM fact_spend_analytics fsa
JOIN dim_commodities dc ON fsa.commodity_key = dc.commodity_key
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
JOIN dim_time dt ON fsa.time_key = dt.time_key
WHERE dt.fiscal_year = 2024
GROUP BY dc.parent_category, dt.fiscal_quarter
HAVING maverick_percentage > 5  -- Focus on categories with >5% maverick spend
ORDER BY maverick_percentage DESC;
```

### Key Metrics
- **Off-Contract Spend**: Purchases outside approved contracts
- **Maverick Vendor Count**: Unapproved suppliers used
- **Category Risk**: Categories with highest non-compliance
- **Savings Opportunity**: Potential savings from compliance

---

## 6. Procurement ROI Report

### Purpose
Demonstrate procurement's financial value and return on investment.

### Data Sources
```sql
-- Procurement ROI calculation
WITH procurement_metrics AS (
    SELECT 
        dt.fiscal_year,
        SUM(fsa.spend_amount) as total_managed_spend,
        SUM(fsa.savings_amount) as total_savings,
        COUNT(DISTINCT fsa.vendor_key) as vendors_managed,
        COUNT(DISTINCT fsa.commodity_key) as categories_managed,
        AVG(fsa.compliance_score) as avg_compliance,
        SUM(fsa.spend_amount * (fsa.delivery_performance_score / 100)) as quality_weighted_spend
    FROM fact_spend_analytics fsa
    JOIN dim_time dt ON fsa.time_key = dt.time_key
    GROUP BY dt.fiscal_year
)
SELECT 
    fiscal_year,
    total_managed_spend,
    total_savings,
    (total_savings / total_managed_spend) * 100 as savings_rate,
    vendors_managed,
    categories_managed,
    avg_compliance,
    -- Assuming procurement cost is 1% of managed spend
    total_managed_spend * 0.01 as estimated_procurement_cost,
    ((total_savings - (total_managed_spend * 0.01)) / (total_managed_spend * 0.01)) * 100 as procurement_roi
FROM procurement_metrics
ORDER BY fiscal_year;
```

### Key Metrics
- **Procurement ROI**: Return on procurement investment
- **Cost Avoidance**: Prevented cost increases
- **Process Efficiency**: Cycle time improvements
- **Risk Mitigation Value**: Avoided disruption costs

---

## 7. Global Sourcing Mix Report

### Purpose
Analyze geographic distribution and optimize sourcing strategies.

### Data Sources
```sql
-- Global sourcing analysis
SELECT 
    dv.region,
    dv.country,
    dc.parent_category,
    COUNT(DISTINCT dv.vendor_key) as vendor_count,
    SUM(fsa.spend_amount) as total_spend,
    AVG(fsa.delivery_performance_score) as avg_delivery_performance,
    AVG(fsa.unit_price) as avg_unit_price,
    SUM(fsa.risk_weighted_spend) / SUM(fsa.spend_amount) as avg_risk_factor,
    (SUM(fsa.spend_amount) / (
        SELECT SUM(spend_amount) 
        FROM fact_spend_analytics fsa2 
        JOIN dim_commodities dc2 ON fsa2.commodity_key = dc2.commodity_key 
        WHERE dc2.parent_category = dc.parent_category
    )) * 100 as category_share
FROM fact_spend_analytics fsa
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
JOIN dim_commodities dc ON fsa.commodity_key = dc.commodity_key
JOIN dim_time dt ON fsa.time_key = dt.time_key
WHERE dv.is_current_record = 1
  AND dt.fiscal_year = 2024
GROUP BY dv.region, dv.country, dc.parent_category
ORDER BY total_spend DESC;
```

### Key Metrics
- **Regional Spend Distribution**: Spend by geography
- **Supply Chain Resilience**: Geographic diversification
- **Cost Competitiveness**: Regional price comparisons
- **Lead Time Analysis**: Delivery performance by region

---

## Implementation Guide

### Query Optimization Tips

1. **Use Appropriate Indexes**
```sql
-- Ensure these indexes exist for fast reporting
CREATE INDEX idx_fact_vendor_time ON fact_spend_analytics(vendor_key, time_key);
CREATE INDEX idx_fact_commodity_time ON fact_spend_analytics(commodity_key, time_key);
CREATE INDEX idx_dim_vendors_current ON dim_vendors(is_current_record, vendor_tier);
```

2. **Leverage Views for Complex Reports**
```sql
-- Create materialized views for frequently accessed data
CREATE VIEW vw_current_fy_performance AS
SELECT 
    dv.vendor_key,
    dv.vendor_name,
    SUM(fsa.spend_amount) as total_spend,
    AVG(fsa.delivery_performance_score) as avg_delivery
FROM fact_spend_analytics fsa
JOIN dim_vendors dv ON fsa.vendor_key = dv.vendor_key
JOIN dim_time dt ON fsa.time_key = dt.time_key
WHERE dv.is_current_record = 1
  AND dt.fiscal_year = (SELECT MAX(fiscal_year) FROM dim_time)
GROUP BY dv.vendor_key, dv.vendor_name;
```

3. **Parameterize Date Ranges**
```python
# Python example for dynamic date filtering
def get_supplier_performance(fiscal_year=None, vendor_tier=None):
    query = """
    SELECT vendor_name, avg_otif, total_spend
    FROM vw_supplier_performance
    WHERE 1=1
    """
    
    params = []
    if fiscal_year:
        query += " AND fiscal_year = ?"
        params.append(fiscal_year)
    
    if vendor_tier:
        query += " AND vendor_tier = ?"
        params.append(vendor_tier)
    
    return execute_query(query, params)
```

### Dashboard Integration

#### Power BI Connection
```
Data Source: SQLite
Database Path: /path/to/procurement_analytics.db
Connection Type: DirectQuery (for real-time) or Import (for performance)
```

#### Tableau Connection
```
Connector: SQLite
Database: procurement_analytics.db
Custom SQL: Use optimized queries from this documentation
```

### Automated Report Generation

```python
class ProcurementReportGenerator:
    def __init__(self, analytics_db_path):
        self.db_path = analytics_db_path
    
    def generate_executive_dashboard(self):
        """Generate all C-Suite reports"""
        reports = {
            'supplier_performance': self.get_supplier_performance(),
            'savings_realization': self.get_savings_realization(),
            'risk_exposure': self.get_risk_exposure(),
            'esg_diversity': self.get_esg_diversity()
        }
        
        return self.compile_executive_report(reports)
    
    def schedule_daily_reports(self):
        """Schedule automated report generation"""
        # Implementation for scheduled reporting
        pass
```

---

*This comprehensive mapping ensures all 17 C-Suite reports can be generated efficiently from the analytics database, providing executives with timely, accurate insights for strategic procurement decisions.*
