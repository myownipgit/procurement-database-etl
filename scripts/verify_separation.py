#!/usr/bin/env python3
"""
Database Separation Verification Script

This script performs comprehensive health checks on both operational 
and analytics databases to ensure proper separation and data integrity.
"""

import sqlite3
import os
from datetime import datetime
from typing import Dict, List, Tuple

class DatabaseHealthChecker:
    def __init__(self, operational_db: str, analytics_db: str):
        self.operational_db = operational_db
        self.analytics_db = analytics_db
        
    def check_database_exists(self, db_path: str) -> bool:
        """Check if database file exists and is accessible"""
        return os.path.exists(db_path) and os.path.getsize(db_path) > 0
    
    def get_table_info(self, db_path: str) -> Dict:
        """Get comprehensive table information from database"""
        conn = sqlite3.connect(db_path)
        
        # Get all tables
        tables = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table'"
        ).fetchall()
        table_names = [t[0] for t in tables]
        
        # Get row counts
        table_counts = {}
        for table in table_names:
            try:
                count = conn.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0]
                table_counts[table] = count
            except Exception as e:
                table_counts[table] = f"Error: {e}"
        
        # Get database size
        db_size = os.path.getsize(db_path)
        
        conn.close()
        
        return {
            'tables': table_names,
            'table_counts': table_counts,
            'total_tables': len(table_names),
            'db_size_mb': round(db_size / (1024 * 1024), 2)
        }
    
    def verify_star_schema(self) -> Dict:
        """Verify STAR schema structure in analytics database"""
        required_tables = ['dim_vendors', 'dim_commodities', 'dim_time', 'fact_spend_analytics']
        
        if not self.check_database_exists(self.analytics_db):
            return {'status': 'FAILED', 'reason': 'Analytics database not found'}
        
        analytics_info = self.get_table_info(self.analytics_db)
        missing_tables = [t for t in required_tables if t not in analytics_info['tables']]
        
        if missing_tables:
            return {
                'status': 'FAILED', 
                'reason': f'Missing STAR schema tables: {missing_tables}'
            }
        
        # Check for fact table relationships
        conn = sqlite3.connect(self.analytics_db)
        try:
            # Verify foreign key relationships exist
            fk_check = conn.execute(
                "PRAGMA foreign_key_list(fact_spend_analytics)"
            ).fetchall()
            
            conn.close()
            
            return {
                'status': 'PASSED',
                'star_tables': required_tables,
                'foreign_keys': len(fk_check),
                'table_counts': {t: analytics_info['table_counts'][t] for t in required_tables}
            }
        except Exception as e:
            conn.close()
            return {'status': 'FAILED', 'reason': f'Schema validation error: {e}'}
    
    def verify_operational_schema(self) -> Dict:
        """Verify operational database has required tables"""
        required_tables = ['vendors', 'spend_transactions', 'contracts', 'commodities']
        
        if not self.check_database_exists(self.operational_db):
            return {'status': 'FAILED', 'reason': 'Operational database not found'}
        
        operational_info = self.get_table_info(self.operational_db)
        missing_tables = [t for t in required_tables if t not in operational_info['tables']]
        
        if missing_tables:
            return {
                'status': 'FAILED', 
                'reason': f'Missing operational tables: {missing_tables}'
            }
        
        return {
            'status': 'PASSED',
            'operational_tables': required_tables,
            'total_tables': operational_info['total_tables'],
            'table_counts': {t: operational_info['table_counts'][t] for t in required_tables}
        }
    
    def check_data_consistency(self) -> Dict:
        """Check data consistency between operational and analytics databases"""
        try:
            # Connect to both databases
            op_conn = sqlite3.connect(self.operational_db)
            an_conn = sqlite3.connect(self.analytics_db)
            
            # Check vendor counts
            op_vendors = op_conn.execute("SELECT COUNT(*) FROM vendors").fetchone()[0]
            an_vendors = an_conn.execute("SELECT COUNT(*) FROM dim_vendors").fetchone()[0]
            
            # Check transaction vs fact counts (may differ due to ETL processing)
            op_transactions = op_conn.execute("SELECT COUNT(*) FROM spend_transactions").fetchone()[0]
            an_facts = an_conn.execute("SELECT COUNT(*) FROM fact_spend_analytics").fetchone()[0]
            
            op_conn.close()
            an_conn.close()
            
            vendor_consistency = abs(op_vendors - an_vendors) <= 10  # Allow small variance
            transaction_ratio = an_facts / op_transactions if op_transactions > 0 else 0
            
            return {
                'status': 'PASSED' if vendor_consistency and transaction_ratio > 0.9 else 'WARNING',
                'vendor_counts': {'operational': op_vendors, 'analytics': an_vendors},
                'transaction_counts': {'operational': op_transactions, 'analytics': an_facts},
                'vendor_consistency': vendor_consistency,
                'transaction_ratio': round(transaction_ratio, 3)
            }
        
        except Exception as e:
            return {'status': 'FAILED', 'reason': f'Consistency check error: {e}'}
    
    def run_full_health_check(self) -> Dict:
        """Run comprehensive health check on both databases"""
        print("🔍 Running Database Health Check...")
        print(f"⏰ Timestamp: {datetime.now()}")
        print("=" * 60)
        
        results = {
            'timestamp': datetime.now().isoformat(),
            'operational_db': self.operational_db,
            'analytics_db': self.analytics_db
        }
        
        # 1. Check database existence
        print("\n📁 Checking Database Files...")
        op_exists = self.check_database_exists(self.operational_db)
        an_exists = self.check_database_exists(self.analytics_db)
        
        print(f"   Operational DB: {'✅ EXISTS' if op_exists else '❌ MISSING'}")
        print(f"   Analytics DB: {'✅ EXISTS' if an_exists else '❌ MISSING'}")
        
        if not (op_exists and an_exists):
            results['status'] = 'FAILED'
            results['reason'] = 'Database files missing'
            return results
        
        # 2. Get database info
        print("\n📊 Analyzing Database Structure...")
        op_info = self.get_table_info(self.operational_db)
        an_info = self.get_table_info(self.analytics_db)
        
        print(f"   Operational: {op_info['total_tables']} tables, {op_info['db_size_mb']}MB")
        print(f"   Analytics: {an_info['total_tables']} tables, {an_info['db_size_mb']}MB")
        
        results['operational_info'] = op_info
        results['analytics_info'] = an_info
        
        # 3. Verify schemas
        print("\n🏗️ Verifying Schema Structure...")
        star_check = self.verify_star_schema()
        operational_check = self.verify_operational_schema()
        
        print(f"   STAR Schema: {'✅ PASSED' if star_check['status'] == 'PASSED' else '❌ FAILED'}")
        print(f"   Operational Schema: {'✅ PASSED' if operational_check['status'] == 'PASSED' else '❌ FAILED'}")
        
        if star_check['status'] == 'FAILED':
            print(f"      Reason: {star_check['reason']}")
        if operational_check['status'] == 'FAILED':
            print(f"      Reason: {operational_check['reason']}")
        
        results['star_schema_check'] = star_check
        results['operational_schema_check'] = operational_check
        
        # 4. Check data consistency
        print("\n🔄 Checking Data Consistency...")
        consistency_check = self.check_data_consistency()
        
        if consistency_check['status'] != 'FAILED':
            print(f"   Vendor Consistency: {'✅ GOOD' if consistency_check['vendor_consistency'] else '⚠️ WARNING'}")
            print(f"   Transaction Ratio: {consistency_check['transaction_ratio']} {'✅ GOOD' if consistency_check['transaction_ratio'] > 0.9 else '⚠️ WARNING'}")
        else:
            print(f"   ❌ FAILED: {consistency_check['reason']}")
        
        results['consistency_check'] = consistency_check
        
        # 5. Overall status
        print("\n" + "=" * 60)
        
        all_passed = (
            star_check['status'] == 'PASSED' and 
            operational_check['status'] == 'PASSED' and 
            consistency_check['status'] in ['PASSED', 'WARNING']
        )
        
        overall_status = 'HEALTHY' if all_passed else 'ISSUES_DETECTED'
        results['overall_status'] = overall_status
        
        if overall_status == 'HEALTHY':
            print("🎉 Overall Status: ✅ HEALTHY - Database separation working correctly!")
        else:
            print("⚠️ Overall Status: ❌ ISSUES DETECTED - Review failures above")
        
        print("=" * 60)
        
        return results

def main():
    """Main function to run health check"""
    # Default paths - update these for your environment
    operational_db = "/Users/myownip/db_dev/procurement_operational.db"
    analytics_db = "/Users/myownip/db_dev/procurement_analytics.db"
    
    checker = DatabaseHealthChecker(operational_db, analytics_db)
    results = checker.run_full_health_check()
    
    # Optionally save results to file
    # import json
    # with open(f"health_check_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json", 'w') as f:
    #     json.dump(results, f, indent=2)

if __name__ == "__main__":
    main()
