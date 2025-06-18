import sqlite3

# Paths to databases
backup_db_path = "/Users/myownip/db_backups/suppliers_backup_20250509_082655.db"
analytics_db_path = "/Users/myownip/db_dev/procurement_analytics.db"

# Connect to analytics database
analytics_conn = sqlite3.connect(analytics_db_path)

# Attach backup database as source
analytics_conn.execute(f"ATTACH DATABASE '{backup_db_path}' AS source")

try:
    # Copy all STAR schema data from backup
    print("📊 Copying dim_vendors...")
    analytics_conn.execute("INSERT INTO main.dim_vendors SELECT * FROM source.dim_vendors")
    
    print("📊 Copying dim_commodities...")
    analytics_conn.execute("INSERT INTO main.dim_commodities SELECT * FROM source.dim_commodities") 
    
    print("📊 Copying dim_time...")
    analytics_conn.execute("INSERT INTO main.dim_time SELECT * FROM source.dim_time")
    
    print("📊 Copying fact_spend_analytics...")
    analytics_conn.execute("INSERT INTO main.fact_spend_analytics SELECT * FROM source.fact_spend_analytics")

    analytics_conn.commit()
    print("✅ All STAR schema data copied successfully!")
    
    # Verify data was copied
    cursor = analytics_conn.execute("SELECT name FROM sqlite_master WHERE type='table'")
    tables = cursor.fetchall()
    print(f"\n📋 Tables in analytics database: {[table[0] for table in tables]}")
    
    # Count records in each table
    for table_name in ['dim_vendors', 'dim_commodities', 'dim_time', 'fact_spend_analytics']:
        cursor = analytics_conn.execute(f"SELECT COUNT(*) FROM {table_name}")
        count = cursor.fetchone()[0]
        print(f"   📊 {table_name}: {count:,} records")

except Exception as e:
    print(f"❌ Error copying data: {e}")
    analytics_conn.rollback()

finally:
    analytics_conn.close()
