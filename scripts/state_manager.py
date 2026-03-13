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
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger("state_manager")


class StateManager:
    """Manages persistent state for ZeroClaw agents."""

    def __init__(self):
        self.service_name = os.environ.get("ZEROCLAW_SERVICE_NAME", "default-service")
        self.owner = os.environ.get("ZEROCLAW_SERVICE_OWNER", "default-owner")
        self.platform = os.environ.get("ZEROCLAW_PLATFORM", "railway")
        self.state_key = f"{self.platform}:{self.owner}:{self.service_name}"

        self.db_url = os.environ.get("ZEROCLAW_STATE_STORE_URL")
        self.conn = None

        if not self.db_url:
            logger.warning(
                "ZEROCLAW_STATE_STORE_URL not set - state persistence disabled"
            )

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
                cur.execute(
                    """
                    INSERT INTO services (state_key, service_name, owner, platform, last_deployment)
                    VALUES (%s, %s, %s, %s, NOW())
                    ON CONFLICT (state_key) 
                    DO UPDATE SET last_deployment = NOW()
                """,
                    (self.state_key, self.service_name, self.owner, self.platform),
                )
                conn.commit()
                logger.info(f"Service registered: {self.state_key}")
                return True
        except Exception as e:
            logger.error(f"Failed to register service: {e}")
            return False

    def save_schedule(
        self,
        schedule_type: str,
        schedule_expr: str,
        task_type: str,
        task_config: Dict[str, Any],
    ) -> Optional[str]:
        """Save a schedule to the database."""
        conn = self._get_connection()
        if not conn:
            return None

        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    INSERT INTO schedules (state_key, schedule_type, schedule_expr, task_type, task_config)
                    VALUES (%s, %s, %s, %s, %s)
                    RETURNING id
                """,
                    (
                        self.state_key,
                        schedule_type,
                        schedule_expr,
                        task_type,
                        json.dumps(task_config),
                    ),
                )
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
                cur.execute(
                    """
                    SELECT id, schedule_type, schedule_expr, task_type, task_config, 
                           enabled, last_run, next_run, run_count
                    FROM schedules
                    WHERE state_key = %s AND enabled = true
                    ORDER BY created_at
                """,
                    (self.state_key,),
                )
                schedules = [dict(row) for row in cur.fetchall()]
                logger.info(f"Retrieved {len(schedules)} schedules from database")
                return schedules
        except Exception as e:
            logger.error(f"Failed to get schedules: {e}")
            return []

    def update_schedule(
        self,
        schedule_id: str,
        schedule_type: str = None,
        schedule_expr: str = None,
        task_type: str = None,
        task_config: Dict[str, Any] = None,
        enabled: bool = None,
    ) -> bool:
        """Update an existing schedule."""
        conn = self._get_connection()
        if not conn:
            return False

        updates = []
        params = []
        if schedule_type is not None:
            updates.append("schedule_type = %s")
            params.append(schedule_type)
        if schedule_expr is not None:
            updates.append("schedule_expr = %s")
            params.append(schedule_expr)
        if task_type is not None:
            updates.append("task_type = %s")
            params.append(task_type)
        if task_config is not None:
            updates.append("task_config = %s")
            params.append(json.dumps(task_config))
        if enabled is not None:
            updates.append("enabled = %s")
            params.append(enabled)

        if not updates:
            logger.warning("No updates specified")
            return False

        params.extend([schedule_id, self.state_key])

        try:
            with conn.cursor() as cur:
                cur.execute(
                    f"""
                    UPDATE schedules 
                    SET {", ".join(updates)}
                    WHERE id = %s AND state_key = %s
                """,
                    params,
                )
                conn.commit()
                logger.info(f"Updated schedule: {schedule_id}")
                return cur.rowcount > 0
        except Exception as e:
            logger.error(f"Failed to update schedule: {e}")
            return False

    def delete_schedule(self, schedule_id: str) -> bool:
        """Delete a schedule from the database."""
        conn = self._get_connection()
        if not conn:
            return False

        try:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    DELETE FROM schedules 
                    WHERE id = %s AND state_key = %s
                """,
                    (schedule_id, self.state_key),
                )
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
                cur.execute(
                    """
                    INSERT INTO preferences (state_key, key, value, updated_at)
                    VALUES (%s, %s, %s, NOW())
                    ON CONFLICT (state_key, key)
                    DO UPDATE SET value = EXCLUDED.value, updated_at = NOW()
                """,
                    (self.state_key, key, json.dumps(value)),
                )
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
                cur.execute(
                    """
                    SELECT value FROM preferences
                    WHERE state_key = %s AND key = %s
                """,
                    (self.state_key, key),
                )
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
    import argparse

    parser = argparse.ArgumentParser(
        description="ZeroClaw State Manager - Persist schedules and preferences",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  List schedules:
    state_manager.py --list-schedules

  Save new schedule:
    state_manager.py --save-schedule --schedule-type cron --schedule-expr "0 6 * * *" --task-type morning_briefing --task-config '{"channels": ["telegram"]}'

  Update schedule:
    state_manager.py --update-schedule --schedule-id UUID --schedule-expr "0 7 * * *"

  Delete schedule:
    state_manager.py --delete-schedule --schedule-id UUID

  Restore schedules (for startup):
    state_manager.py --restore
""",
    )

    # Context options
    parser.add_argument(
        "--service-name",
        default=os.environ.get("ZEROCLAW_SERVICE_NAME"),
        help="Service name (default: ZEROCLAW_SERVICE_NAME env)",
    )
    parser.add_argument(
        "--owner",
        default=os.environ.get("ZEROCLAW_SERVICE_OWNER"),
        help="Owner name (default: ZEROCLAW_SERVICE_OWNER env)",
    )

    # Action options (mutually exclusive operations)
    action_group = parser.add_mutually_exclusive_group()
    action_group.add_argument(
        "--restore",
        action="store_true",
        help="Restore schedules from database (outputs JSON)",
    )
    action_group.add_argument(
        "--list-schedules",
        action="store_true",
        help="List all schedules for this service",
    )
    action_group.add_argument(
        "--save-schedule", action="store_true", help="Save a new schedule"
    )
    action_group.add_argument(
        "--update-schedule", action="store_true", help="Update an existing schedule"
    )
    action_group.add_argument(
        "--delete-schedule", action="store_true", help="Delete a schedule"
    )

    # Schedule definition options
    parser.add_argument("--schedule-id", help="Schedule UUID (for update/delete)")
    parser.add_argument(
        "--schedule-type", choices=["cron", "interval", "once"], help="Schedule type"
    )
    parser.add_argument(
        "--schedule-expr",
        help='Cron expression or interval (e.g., "0 6 * * *" or "3600s")',
    )
    parser.add_argument(
        "--task-type", help="Task type (e.g., morning_briefing, rss_aggregate)"
    )
    parser.add_argument("--task-config", help="JSON config for the task")
    parser.add_argument(
        "--enabled",
        type=lambda x: x.lower() == "true",
        help="Enable/disable schedule (true/false)",
    )

    args = parser.parse_args()

    if args.service_name:
        os.environ["ZEROCLAW_SERVICE_NAME"] = args.service_name
    if args.owner:
        os.environ["ZEROCLAW_SERVICE_OWNER"] = args.owner

    manager = StateManager()

    try:
        if args.restore:
            manager._ensure_tables()
            manager.register_service()
            schedules = manager.get_schedules()
            print(json.dumps(schedules, indent=2, default=str))

        elif args.list_schedules:
            manager._ensure_tables()
            schedules = manager.get_schedules()
            if schedules:
                print(json.dumps(schedules, indent=2, default=str))
            else:
                print("[]")

        elif args.save_schedule:
            if not all(
                [
                    args.schedule_type,
                    args.schedule_expr,
                    args.task_type,
                    args.task_config,
                ]
            ):
                print(
                    "Error: --save-schedule requires --schedule-type, --schedule-expr, --task-type, --task-config"
                )
                sys.exit(1)
            try:
                task_config = json.loads(args.task_config)
            except json.JSONDecodeError as e:
                print(f"Error: Invalid JSON in --task-config: {e}")
                sys.exit(1)

            manager._ensure_tables()
            manager.register_service()
            schedule_id = manager.save_schedule(
                args.schedule_type, args.schedule_expr, args.task_type, task_config
            )
            if schedule_id:
                print(json.dumps({"success": True, "schedule_id": schedule_id}))
            else:
                print(
                    json.dumps({"success": False, "error": "Failed to save schedule"})
                )
                sys.exit(1)

        elif args.update_schedule:
            if not args.schedule_id:
                print("Error: --update-schedule requires --schedule-id")
                sys.exit(1)

            task_config = None
            if args.task_config:
                try:
                    task_config = json.loads(args.task_config)
                except json.JSONDecodeError as e:
                    print(f"Error: Invalid JSON in --task-config: {e}")
                    sys.exit(1)

            success = manager.update_schedule(
                args.schedule_id,
                schedule_type=args.schedule_type,
                schedule_expr=args.schedule_expr,
                task_type=args.task_type,
                task_config=task_config,
                enabled=args.enabled,
            )
            if success:
                print(json.dumps({"success": True, "schedule_id": args.schedule_id}))
            else:
                print(
                    json.dumps(
                        {
                            "success": False,
                            "error": "Failed to update schedule or no changes made",
                        }
                    )
                )
                sys.exit(1)

        elif args.delete_schedule:
            if not args.schedule_id:
                print("Error: --delete-schedule requires --schedule-id")
                sys.exit(1)

            success = manager.delete_schedule(args.schedule_id)
            if success:
                print(json.dumps({"success": True, "schedule_id": args.schedule_id}))
            else:
                print(
                    json.dumps({"success": False, "error": "Failed to delete schedule"})
                )
                sys.exit(1)

        else:
            parser.print_help()

    finally:
        manager.close()


if __name__ == "__main__":
    main()
