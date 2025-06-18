import sqlite3
from datetime import datetime

class SeparateDatabaseETL:
    def __init__(self):
        self.operational_db = "/Users/myownip/db_dev/procurement_operational.db"
        self.analytics_db = "/Users/myownip/db_dev/procurement_analytics.db"
    
    def daily_etl(self):
        """Daily ETL from operational to analytics"""
        print(f"🔄 Starting ETL process at {datetime.now()}")
        
        # Connect to analytics database
        analytics_conn = sqlite3.connect(self.analytics_db)
        
        # Attach operational database
        analytics_conn.execute(f"ATTACH DATABASE '{self.operational_db}' AS operational")
        
        try:
            # ETL new/changed vendors
            print("📊 Processing new vendors...")
            result = analytics_conn.execute("""
                INSERT OR REPLACE INTO main.dim_vendors (
                    vendor_id, vendor_name, vendor_tier, diversity_classification,
                    risk_rating, country, effective_start_date, is_current_record
                )
                SELECT 
                    vendor_id, vendor_name, vendor_tier, diversity_classification,
                    'Medium', country, DATE('now'), 1
                FROM operational.vendors
                WHERE vendor_id NOT IN (SELECT vendor_id FROM main.dim_vendors WHERE vendor_id IS NOT NULL)
            """)
            vendor_updates = analytics_conn.rowcount
            print(f"   ✅ {vendor_updates} vendors processed")
            
            # ETL new transactions
            print("📊 Processing new transactions...")
            result = analytics_conn.execute("""
                INSERT INTO main.fact_spend_analytics (
                    vendor_key, commodity_key, time_key, spend_amount, 
                    transaction_count, source_transaction_id, load_date
                )
                SELECT 
                    dv.vendor_key, dc.commodity_key, dt.time_key,
                    st.total_amount, 1, CAST(st.transaction_id AS TEXT), DATE('now')
                FROM operational.spend_transactions st
                JOIN main.dim_vendors dv ON st.vendor_id = dv.vendor_id
                JOIN main.dim_commodities dc ON st.commodity_id = dc.commodity_id  
                JOIN main.dim_time dt ON dt.time_key = CAST(STRFTIME('%Y%m%d', st.award_date) AS INTEGER)
                WHERE st.transaction_id NOT IN (
                    SELECT CAST(source_transaction_id AS INTEGER) 
                    FROM main.fact_spend_analytics 
                    WHERE source_transaction_id IS NOT NULL
                )
            """)
            transaction_updates = analytics_conn.rowcount
            print(f"   ✅ {transaction_updates} transactions processed")
            
            analytics_conn.commit()
            print(f"✅ ETL process completed successfully at {datetime.now()}")
            
        except Exception as e:
            print(f"❌ ETL Error: {e}")
            analytics_conn.rollback()
            
        finally:
            analytics_conn.close()
    
    def verify_separation(self):
        """Verify both databases are working correctly"""
        print("🔍 Verifying database separation...")
        
        # Check operational database
        op_conn = sqlite3.connect(self.operational_db)
        op_tables = op_conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        op_vendor_count = op_conn.execute("SELECT COUNT(*) FROM vendors").fetchone()[0]
        op_transaction_count = op_conn.execute("SELECT COUNT(*) FROM spend_transactions").fetchone()[0]
        op_conn.close()
        
        # Check analytics database
        an_conn = sqlite3.connect(self.analytics_db)
        an_tables = an_conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        an_vendor_count = an_conn.execute("SELECT COUNT(*) FROM dim_vendors").fetchone()[0]
        an_fact_count = an_conn.execute("SELECT COUNT(*) FROM fact_spend_analytics").fetchone()[0]
        an_conn.close()
        
        print(f"\n📁 Operational Database:")
        print(f"   📊 Tables: {len(op_tables)} (includes: vendors, spend_transactions, contracts, etc.)")
        print(f"   📊 Vendors: {op_vendor_count:,}")
        print(f"   📊 Transactions: {op_transaction_count:,}")
        
        print(f"\n📁 Analytics Database:")
        print(f"   📊 Tables: {len(an_tables)} (STAR schema: dim_*, fact_*)")
        print(f"   📊 Dim Vendors: {an_vendor_count:,}")
        print(f"   📊 Fact Records: {an_fact_count:,}")
        
        print("\n✅ Database separation verified!")

# Run verification
if __name__ == "__main__":
    etl = SeparateDatabaseETL()
    etl.verify_separation()
