#!/usr/bin/env python3
"""
Database Configuration Module for Procurement ETL Pipeline

This module provides centralized configuration management for database
connections, ETL settings, and system parameters.
"""

import os
import sqlite3
from pathlib import Path
from typing import Dict, Optional
from dataclasses import dataclass
from datetime import datetime

@dataclass
class DatabaseConfig:
    """Configuration class for database connections"""
    operational_db_path: str
    analytics_db_path: str
    backup_db_path: Optional[str] = None
    connection_timeout: int = 30
    enable_foreign_keys: bool = True
    enable_wal_mode: bool = True
    max_retries: int = 3

@dataclass
class ETLConfig:
    """Configuration class for ETL processes"""
    batch_size: int = 1000
    max_parallel_jobs: int = 4
    enable_data_validation: bool = True
    auto_create_indexes: bool = True
    log_level: str = "INFO"
    backup_before_etl: bool = True
    
class ProcurementETLConfig:
    """Main configuration manager for the Procurement ETL system"""
    
    def __init__(self, config_file: Optional[str] = None):
        self.config_file = config_file
        self._load_configuration()
    
    def _load_configuration(self):
        """Load configuration from environment variables or config file"""
        
        # Database paths - default to development environment
        db_base_path = os.getenv('PROCUREMENT_DB_PATH', '/Users/myownip/db_dev')
        
        self.database = DatabaseConfig(
            operational_db_path=os.getenv(
                'OPERATIONAL_DB_PATH', 
                f'{db_base_path}/procurement_operational.db'
            ),
            analytics_db_path=os.getenv(
                'ANALYTICS_DB_PATH', 
                f'{db_base_path}/procurement_analytics.db'
            ),
            backup_db_path=os.getenv(
                'BACKUP_DB_PATH', 
                '/Users/myownip/db_backups/suppliers_backup_20250509_082655.db'
            ),
            connection_timeout=int(os.getenv('DB_CONNECTION_TIMEOUT', '30')),
            enable_foreign_keys=os.getenv('DB_ENABLE_FK', 'true').lower() == 'true',
            enable_wal_mode=os.getenv('DB_ENABLE_WAL', 'true').lower() == 'true'
        )
        
        self.etl = ETLConfig(
            batch_size=int(os.getenv('ETL_BATCH_SIZE', '1000')),
            max_parallel_jobs=int(os.getenv('ETL_MAX_JOBS', '4')),
            enable_data_validation=os.getenv('ETL_VALIDATE_DATA', 'true').lower() == 'true',
            auto_create_indexes=os.getenv('ETL_AUTO_INDEX', 'true').lower() == 'true',
            log_level=os.getenv('ETL_LOG_LEVEL', 'INFO'),
            backup_before_etl=os.getenv('ETL_BACKUP_FIRST', 'true').lower() == 'true'
        )
        
        # System settings
        self.system = {
            'temp_dir': os.getenv('TEMP_DIR', '/tmp/procurement_etl'),
            'log_dir': os.getenv('LOG_DIR', './logs'),
            'max_log_files': int(os.getenv('MAX_LOG_FILES', '10')),
            'environment': os.getenv('ENVIRONMENT', 'development'),
            'debug_mode': os.getenv('DEBUG_MODE', 'false').lower() == 'true'
        }
        
        # MCP Server settings
        self.mcp = {
            'operational_server_name': 'sqlite-operational',
            'analytics_server_name': 'sqlite-analytics',
            'claude_config_path': os.path.expanduser(
                '~/Library/Application Support/Claude/claude_desktop_config.json'
            )
        }
        
        # Ensure directories exist
        self._ensure_directories()
    
    def _ensure_directories(self):
        """Create necessary directories if they don't exist"""
        directories = [
            os.path.dirname(self.database.operational_db_path),
            os.path.dirname(self.database.analytics_db_path),
            self.system['temp_dir'],
            self.system['log_dir']
        ]
        
        for directory in directories:
            Path(directory).mkdir(parents=True, exist_ok=True)
    
    def get_operational_connection(self) -> sqlite3.Connection:
        """Get connection to operational database"""
        return self._get_connection(self.database.operational_db_path)
    
    def get_analytics_connection(self) -> sqlite3.Connection:
        """Get connection to analytics database"""
        return self._get_connection(self.database.analytics_db_path)
    
    def get_backup_connection(self) -> Optional[sqlite3.Connection]:
        """Get connection to backup database if available"""
        if self.database.backup_db_path and os.path.exists(self.database.backup_db_path):
            return self._get_connection(self.database.backup_db_path)
        return None
    
    def _get_connection(self, db_path: str) -> sqlite3.Connection:
        """Create optimized SQLite connection"""
        conn = sqlite3.connect(
            db_path, 
            timeout=self.database.connection_timeout
        )
        
        # Enable foreign keys if configured
        if self.database.enable_foreign_keys:
            conn.execute('PRAGMA foreign_keys = ON')
        
        # Enable WAL mode for better concurrency
        if self.database.enable_wal_mode:
            conn.execute('PRAGMA journal_mode = WAL')
        
        # Performance optimizations
        conn.execute('PRAGMA synchronous = NORMAL')
        conn.execute('PRAGMA cache_size = -64000')  # 64MB cache
        conn.execute('PRAGMA temp_store = MEMORY')
        
        return conn
    
    def validate_configuration(self) -> Dict[str, bool]:
        """Validate configuration and database accessibility"""
        results = {
            'operational_db_exists': os.path.exists(self.database.operational_db_path),
            'analytics_db_exists': os.path.exists(self.database.analytics_db_path),
            'backup_db_exists': (
                self.database.backup_db_path is not None and 
                os.path.exists(self.database.backup_db_path)
            ),
            'temp_dir_writable': os.access(self.system['temp_dir'], os.W_OK),
            'log_dir_writable': os.access(self.system['log_dir'], os.W_OK)
        }
        
        # Test database connections
        try:
            conn = self.get_operational_connection()
            conn.execute('SELECT 1')
            conn.close()
            results['operational_db_accessible'] = True
        except Exception:
            results['operational_db_accessible'] = False
        
        try:
            conn = self.get_analytics_connection()
            conn.execute('SELECT 1')
            conn.close()
            results['analytics_db_accessible'] = True
        except Exception:
            results['analytics_db_accessible'] = False
            
        return results
    
    def get_claude_mcp_config(self) -> Dict:
        """Generate MCP server configuration for Claude Desktop"""
        return {
            "mcpServers": {
                self.mcp['operational_server_name']: {
                    "command": "uvx",
                    "args": [
                        "mcp-server-sqlite",
                        "--db-path",
                        self.database.operational_db_path
                    ]
                },
                self.mcp['analytics_server_name']: {
                    "command": "uvx",
                    "args": [
                        "mcp-server-sqlite",
                        "--db-path",
                        self.database.analytics_db_path
                    ]
                }
            }
        }
    
    def print_summary(self):
        """Print configuration summary"""
        print("\n" + "=" * 60)
        print("📋 PROCUREMENT ETL CONFIGURATION SUMMARY")
        print("=" * 60)
        
        print(f"\n🗃️  Database Configuration:")
        print(f"   Operational: {self.database.operational_db_path}")
        print(f"   Analytics:   {self.database.analytics_db_path}")
        print(f"   Backup:      {self.database.backup_db_path or 'None'}")
        
        print(f"\n⚙️  ETL Configuration:")
        print(f"   Batch Size:      {self.etl.batch_size:,}")
        print(f"   Max Jobs:        {self.etl.max_parallel_jobs}")
        print(f"   Validation:      {self.etl.enable_data_validation}")
        print(f"   Auto Indexes:    {self.etl.auto_create_indexes}")
        print(f"   Log Level:       {self.etl.log_level}")
        
        print(f"\n🔧 System Configuration:")
        print(f"   Environment:     {self.system['environment']}")
        print(f"   Debug Mode:      {self.system['debug_mode']}")
        print(f"   Temp Directory:  {self.system['temp_dir']}")
        print(f"   Log Directory:   {self.system['log_dir']}")
        
        # Validation results
        validation = self.validate_configuration()
        print(f"\n✅ Validation Results:")
        for check, result in validation.items():
            status = "✅ PASS" if result else "❌ FAIL"
            print(f"   {check.replace('_', ' ').title()}: {status}")
        
        print("\n" + "=" * 60)

# Global configuration instance
config = ProcurementETLConfig()

# Convenience functions for common operations
def get_operational_db() -> str:
    """Get path to operational database"""
    return config.database.operational_db_path

def get_analytics_db() -> str:
    """Get path to analytics database"""
    return config.database.analytics_db_path

def get_operational_connection() -> sqlite3.Connection:
    """Get connection to operational database"""
    return config.get_operational_connection()

def get_analytics_connection() -> sqlite3.Connection:
    """Get connection to analytics database"""
    return config.get_analytics_connection()

# Example usage and testing
if __name__ == "__main__":
    print("🔧 Testing Procurement ETL Configuration...")
    
    # Print configuration summary
    config.print_summary()
    
    # Test database connections
    print("\n🔍 Testing Database Connections...")
    
    try:
        op_conn = get_operational_connection()
        result = op_conn.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'").fetchone()
        print(f"   Operational DB: ✅ {result[0]} tables found")
        op_conn.close()
    except Exception as e:
        print(f"   Operational DB: ❌ Error - {e}")
    
    try:
        an_conn = get_analytics_connection()
        result = an_conn.execute("SELECT COUNT(*) FROM sqlite_master WHERE type='table'").fetchone()
        print(f"   Analytics DB:   ✅ {result[0]} tables found")
        an_conn.close()
    except Exception as e:
        print(f"   Analytics DB:   ❌ Error - {e}")
    
    print("\n🎯 Configuration test complete!")
