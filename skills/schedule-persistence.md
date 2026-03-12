# Schedule Persistence

 ZeroClaw's in-memory scheduler loses schedules on redeployment. Use the state_manager.py script to persist schedules to PostgreSQL.
This skill teaches you agent how to properly save and restore schedules to make them persistent across deployments.

## How Schedules Work

1. **In-Memory Scheduler**: ZeroClaw's scheduler handles cron jobs at runtime
2. **Database Persistence**: `state_manager.py` syncs schedules to PostgreSQL (NeonDB)
3. **Restore on Startup**: `docker-entrypoint.sh` calls `state_manager.py --restore` to reload schedules

## Creating a Persistent Schedule

When a user asks to create a recurring task (daily briefing, news aggregation, etc.), you MUST persist it to:

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --save-schedule \
  --schedule-type "cron" \
  --schedule-expr "0 6 * * *" \
  --task-type "morning_briefing" \
  --task-config '{"channels": ["telegram"], "include_news": true}'
```

### Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--save-schedule` | Save a new schedule | (flag) |
| `--schedule-type` | Schedule type | `cron`, `interval`, `once` |
| `--schedule-expr` | Cron expression or interval | `0 6 * * *`, `3600s` |
| `--task-type` | Type of task to run | `morning_briefing`, `rss_aggregate` |
| `--task-config` | JSON config for the task | `{"channels": ["telegram"]}` |

## Listing Saved Schedules

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --list-schedules
```

## Deleting a Schedule

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --delete-schedule --schedule-id SCHEDULE_ID
```

## Workflow Example

User: "Send me a daily news briefing at 6am"

1. Create the schedule in ZeroClaw's scheduler:
   Use the schedule tool to register the cron job in-memory

2. Persist to database:
   ```bash
   /opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --save-schedule \
     --schedule-type "cron" \
     --schedule-expr "0 6 * * *" \
     --task-type "morning_briefing" \
     --task-config '{"channels": ["telegram"]}'
   ```

3. Confirm to user:
   "Schedule created and persisted. It will survive redeployments."

## Environment Variables Required

| Variable | Description |
|----------|-------------|
| `ZEROCLAW_STATE_STORE_ENABLED` | Set to `true` |
| `ZEROCLAW_STATE_STORE_URL` | PostgreSQL connection string |
| `ZEROCLAW_SERVICE_NAME` | Unique service identifier |
| `ZEROCLAW_SERVICE_OWNER` | Owner/organization name |

## Common Task Types

| Task Type | Description | Config Example |
|-----------|-------------|----------------|
| `morning_briefing` | Daily summary with tasks, news, calendar | `{"channels": ["telegram"]}` |
| `rss_aggregate` | Fetch and summarize RSS feeds | `{"feeds": ["url1", "url2"], "format": "pdf"}` |
| `reminder` | One-time or recurring reminder | `{"message": "Take break", "channels": ["telegram"]}` |
| `news_digest` | Periodic news summary | `{"categories": ["tech", "science"]}` |

## Cron Expression Examples
| Expression | Description |
|------------|-------------|
| `0 6 * * *` | Daily at 6:00 AM |
| `0 9,17 * * *` | Twice daily at 9 AM and 5 PM |
| `*/30 * * * *` | Every 30 minutes |
| `0 21 * * 0-4` | Weekdays at 9 PM |
| `0 8 * * 1` | Every Monday at 8 AM |

## Troubleshooting
### "No schedules to restore"
This means no schedules have been saved to the database yet. Create schedules using the workflow above.
### "state_manager.py not found"
The script should be at `/usr/local/bin/zeroclaw-scripts/state_manager.py`. If missing, the Docker image needs to be rebuilt
### "Connection refused" database error
Check that `ZEROCLAW_STATE_STORE_URL` is correctly set with the full PostgreSQL connection string:
```
postgresql://user:password@host:5432/database?sslmode=require
```

### Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--type` | Schedule type | `cron`, `interval`, `once` |
| `--expression` | Cron expression or interval | `0 6 * * *`, `3600s` |
| `--task-type` | Type of task to run | `morning_briefing`, `rss_aggregate` |
| `--config` | JSON config for the task | `{"channels": ["telegram"]}` |

## Listing Saved Schedules

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --list-schedules
```

## Deleting a Schedule

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --delete-schedule --id SCHEDULE_ID
```

## Workflow Example

User: "Send me a daily news briefing at 6am"

1. Create the schedule in ZeroClaw's scheduler:
   ```
   Use the schedule tool to register the cron job
   ```

2. Persist to database:
   ```bash
   /opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --save-schedule \
     --type "cron" \
     --expression "0 6 * * *" \
     --task-type "morning_briefing" \
     --config '{"channels": ["telegram"]}'
   ```

3. Confirm to user:
   "Schedule created and persisted. It will survive redeployments."

## Environment Variables Required

| Variable | Description |
|----------|-------------|
| `ZEROCLAW_STATE_STORE_ENABLED` | Set to `true` |
| `ZEROCLAW_STATE_STORE_URL` | PostgreSQL connection string |
| `ZEROCLAW_SERVICE_NAME` | Unique service identifier |
| `ZEROCLAW_SERVICE_OWNER` | Owner/organization name |

## Common Task Types

| Task Type | Description | Config Example |
|-----------|-------------|----------------|
| `morning_briefing` | Daily summary with tasks, news, calendar | `{"channels": ["telegram"]}` |
| `rss_aggregate` | Fetch and summarize RSS feeds | `{"feeds": ["url1", "url2"], "format": "pdf"}` |
| `reminder` | One-time or recurring reminder | `{"message": "Take break", "channels": ["telegram"]}` |
| `news_digest` | Periodic news summary | `{"categories": ["tech", "science"]}` |

## Cron Expression Examples

| Expression | Description |
|------------|-------------|
| `0 6 * * *` | Daily at 6:00 AM |
| `0 9,17 * * *` | Twice daily at 9 AM and 5 PM |
| `*/30 * * * *` | Every 30 minutes |
| `0 21 * * 0-4` | Weekdays at 9 PM |
| `0 8 * * 1` | Every Monday at 8 AM |

## Troubleshooting

### "No schedules to restore"

This means no schedules have been saved to the database yet. Create schedules using the workflow above.

### "state_manager.py not found"

The script should be at `/usr/local/bin/zeroclaw-scripts/state_manager.py`. If missing, the Docker image needs to be rebuilt.

### "Connection refused" database error

Check that `ZEROCLAW_STATE_STORE_URL` is correctly set with the full PostgreSQL connection string:
```
postgresql://user:password@host:5432/database?sslmode=require
```
