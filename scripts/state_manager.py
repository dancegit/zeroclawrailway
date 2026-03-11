#!/usr/bin/env python3
"""
State Manager for ZeroClaw - Persist schedules and preferences across deployments.

This module syncs ZeroClaw's in-memory scheduler to PostgreSQL (NeonDB) for
persistence across Railway deployments.

Usage in docker-entrypoint.sh:
    # On startup - restore schedules
    python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --restore
    
    # Then start ZeroClaw daemon
    zeroclaw daemon
"""

import os
import sys
import json
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
from typing import Optional, List, Dict, Any

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger('state_manager')


class StateManager:
    """Manages persistent state for ZeroClaw agents."""
    
    def __init__(self):
        self.service_name = os.environ.get('ZEROCLAW_SERVICE_NAME', 'default-service')
        self.owner = os.environ.get('ZEROCLAW_SERVICE_OWNER', 'default-owner')
        self.platform = os.environ.get('ZEROCLAW_PLATFORM', 'railway')
        self.state_key = f"{self.platform}:{self.owner}:{self.service_name}"
        
        self.db_url = os.environ.get('ZEROCLAW_STATE_STORE_URL')
        self.conn = None
        
        if not self.db_url:
            logger.warning("ZEROCLAW_STATE_STORE_URL not set - state persistence disabled")
    
    def _get_connection(self):
        """Get or create database connection."""
        if not self.db_url:
            return None
        
        if self.conn is None or self.conn.closed:
            try:
                self.conn = psycopg2.connect(self.db_url)
                logger.info(f"Connected to state database")
            except Exception as e:
                logger.error(f"Failed to connect to state database: {e}")
                return None
        
        return self.conn
    
    def _ensure_tables(self):
        """Create tables if they don't exist."""
        conn = self._get_connection()
        if not conn:
            return False
        
        try:
            with conn.cursor() as cur:
                # Services table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS services (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        state_key VARCHAR(255) UNIQUE NOT NULL,
                        service_name VARCHAR(255) NOT NULL,
                        owner VARCHAR(255) NOT NULL,
                        platform VARCHAR(50) NOT NULL,
                        created_at TIMESTAMP DEFAULT NOW(),
                        last_deployment TIMESTAMP DEFAULT NOW(),
                        metadata JSONB DEFAULT '{}'
                    )
                """)
                
                # Schedules table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS schedules (
                        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                        state_key VARCHAR(255) REFERENCES services(state_key) ON DELETE CASCADE,
                        schedule_type VARCHAR(50) NOT NULL,
                        schedule_expr VARCHAR(100) NOT NULL,
                        task_type VARCHAR(100) NOT NULL,
                        task_config JSONB NOT NULL,
                        enabled BOOLEAN DEFAULT true,
                        created_at TIMESTAMP DEFAULT NOW(),
                        last_run TIMESTAMP,
                        next_run TIMESTAMP,
                        run_count INTEGER DEFAULT 0
                    )
                """)
                
                # Preferences table
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS preferences (
                        state_key VARCHAR(255) REFERENCES services(state_key) ON DELETE CASCADE,
                        key VARCHAR(255) NOT NULL,
                        value JSONB NOT NULL,
                        updated_at TIMESTAMP DEFAULT NOW(),
                        PRIMARY KEY (state_key, key)
                    )
                """)
                
                conn.commit()
                logger.info("Database tables verified")
                return True
        except Exception as e:
            logger.error(f"Failed to create tables: {e}")
            return False
    
    def register_service(self):
        """Register or update this service in the database."""
        conn = self._get_connection()
        if not conn:
            return False
        
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO services (state_key, service_name, owner, platform, last_deployment)
                    VALUES (%s, %s, %s, %s, NOW())
                    ON CONFLICT (state_key) 
                    DO UPDATE SET last_deployment = NOW()
                """, (self.state_key, self.service_name, self.owner, self.platform))
                conn.commit()
                logger.info(f"Service registered: {self.state_key}")
                return True
        except Exception as e:
            logger.error(f"Failed to register service: {e}")
            return False
    
    def save_schedule(self, schedule_type: str, schedule_expr: str, 
                      task_type: str, task_config: Dict[str, Any]) -> Optional[str]:
        """Save a schedule to the database."""
        conn = self._get_connection()
        if not conn:
            return None
        
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO schedules (state_key, schedule_type, schedule_expr, task_type, task_config)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id
                """, (self.state_key, schedule_type, schedule_expr, task_type, json.dumps(task_config)))
                schedule_id = cur.fetchone()[0]
                conn.commit()
                logger.info(f"Saved schedule: {task_type} ({schedule_expr})")
                return str(schedule_id)
        except Exception as e:
            logger.error(f"Failed to save schedule: {e}")
            return None
    
    def get_schedules(self) -> List[Dict[str, Any]]:
        """Get all schedules for this service."""
        conn = self._get_connection()
        if not conn:
            return []
        
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT id, schedule_type, schedule_expr, task_type, task_config, 
                           enabled, last_run, next_run, run_count
                    FROM schedules
                    WHERE state_key = %s AND enabled = true
                    ORDER BY created_at
                """, (self.state_key,))
                schedules = [dict(row) for row in cur.fetchall()]
                logger.info(f"Retrieved {len(schedules)} schedules from database")
                return schedules
        except Exception as e:
            logger.error(f"Failed to get schedules: {e}")
            return []
    
    def delete_schedule(self, schedule_id: str) -> bool:
        """Delete a schedule from the database."""
        conn = self._get_connection()
        if not conn:
            return False
        
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    DELETE FROM schedules 
                    WHERE id = %s AND state_key = %s
                """, (schedule_id, self.state_key))
                conn.commit()
                logger.info(f"Deleted schedule: {schedule_id}")
                return True
        except Exception as e:
            logger.error(f"Failed to delete schedule: {e}")
            return False
    
    def set_preference(self, key: str, value: Any) -> bool:
        """Set a preference value."""
        conn = self._get_connection()
        if not conn:
            return False
        
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    INSERT INTO preferences (state_key, key, value, updated_at)
                    VALUES (%s, %s, %s, NOW())
                    ON CONFLICT (state_key, key)
                    DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
                """, (self.state_key, key, json.dumps(value)))
                conn.commit()
                logger.info(f"Set preference: {key}")
                return True
        except Exception as e:
            logger.error(f"Failed to set preference: {e}")
            return False
    
    def get_preference(self, key: str, default: Any = None) -> Any:
        """Get a preference value."""
        conn = self._get_connection()
        if not conn:
            return default
        
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    SELECT value FROM preferences
                    WHERE state_key = %s AND key = %s
                """, (self.state_key, key))
                result = cur.fetchone()
                if result:
                    return json.loads(result[0])
                return default
        except Exception as e:
            logger.error(f"Failed to get preference: {e}")
            return default
    
    def close(self):
        """Close database connection."""
        if self.conn and not self.conn.closed:
            self.conn.close()
            logger.info("Database connection closed")


def restore_schedules():
    """
    Restore schedules from database and output them for ZeroClaw to consume.
    
    This outputs a JSON array of schedules that can be used by the entrypoint
    to re-register them with ZeroClaw's scheduler.
    """
    manager = StateManager()
    
    # Ensure tables exist
    manager._ensure_tables()
    
    # Register this service
    manager.register_service()
    
    # Get schedules
    schedules = manager.get_schedules()
    
    # Output as JSON for consumption by entrypoint
    print(json.dumps(schedules, indent=2, default=str))
    
    manager.close()
    return schedules


def main():
    """CLI entry point."""
    import argparse
    
    parser = argparse.ArgumentParser(description='ZeroClaw State Manager')
    parser.add_argument('--restore', action='store_true', 
                       help='Restore schedules from database')
    parser.add_argument('--service-name', default=os.environ.get('ZEROCLAW_SERVICE_NAME'),
                       help='Service name')
    parser.add_argument('--owner', default=os.environ.get('ZEROCLAW_SERVICE_OWNER'),
                       help='Owner name')
    
    args = parser.parse_args()
    
    if args.service_name:
        os.environ['ZEROCLAW_SERVICE_NAME'] = args.service_name
    if args.owner:
        os.environ['ZEROCLAW_SERVICE_OWNER'] = args.owner
    
    if args.restore:
        restore_schedules()
    else:
        parser.print_help()


if __name__ == '__main__':
    main()
