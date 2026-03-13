# Schedule Persistence

ZeroClaw's in-memory scheduler loses schedules on redeployment. Use `state_manager.py` to persist schedules to PostgreSQL (NeonDB).

## How Schedules Work

1. **In-Memory Scheduler**: ZeroClaw's scheduler handles cron jobs at runtime
2. **Database Persistence**: `state_manager.py` syncs schedules to NeonDB
3. **Restore on Startup**: `docker-entrypoint.sh` calls `state_manager.py --restore`

## CLI Reference

### List Schedules

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --list-schedules
```

### Save New Schedule

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --save-schedule \
  --schedule-type "cron" \
  --schedule-expr "0 6 * * *" \
  --task-type "morning_briefing" \
  --task-config '{"channels": ["telegram"], "include_news": true}'
```

### Update Schedule

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --update-schedule \
  --schedule-id SCHEDULE_ID \
  --schedule-expr "0 7 * * *" \
  --task-config '{"channels": ["telegram"], "include_news": false}'
```

Only provide fields you want to change. Omitted fields keep current values.

### Delete Schedule

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --delete-schedule --schedule-id SCHEDULE_ID
```

### Restore Schedules (Startup)

```bash
/opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --restore
```

## Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--save-schedule` | Create new schedule | (flag) |
| `--update-schedule` | Update existing schedule | (flag) |
| `--delete-schedule` | Delete schedule | (flag) |
| `--list-schedules` | List all schedules | (flag) |
| `--restore` | Restore from database | (flag) |
| `--schedule-id` | Schedule UUID | `000e13a7-8d7e-...` |
| `--schedule-type` | Schedule type | `cron`, `interval`, `once` |
| `--schedule-expr` | Cron or interval | `0 6 * * *`, `3600s` |
| `--task-type` | Task to run | `morning_briefing` |
| `--task-config` | JSON config | `{"channels": ["telegram"]}` |
| `--enabled` | Enable/disable | `true`, `false` |

## Environment Variables Required

| Variable | Description |
|----------|-------------|
| `ZEROCLAW_STATE_STORE_ENABLED` | Set to `true` |
| `ZEROCLAW_STATE_STORE_URL` | PostgreSQL connection string |
| `ZEROCLAW_SERVICE_NAME` | Service identifier |
| `ZEROCLAW_SERVICE_OWNER` | Owner name |

## Common Task Types

| Task Type | Description | Config Example |
|-----------|-------------|----------------|
| `morning_briefing` | Daily summary | `{"channels": ["telegram"], "include_news": true, "include_audio": true}` |
| `rss_aggregate` | RSS feed summary | `{"feeds": ["url1"], "format": "pdf"}` |
| `reminder` | Recurring reminder | `{"message": "Take break", "channels": ["telegram"]}` |
| `news_digest` | News summary | `{"categories": ["tech", "science"]}` |

## Cron Expression Examples

| Expression | Description |
|------------|-------------|
| `0 6 * * *` | Daily at 6:00 AM |
| `0 9,17 * * *` | 9 AM and 5 PM |
| `*/30 * * * *` | Every 30 minutes |
| `0 21 * * 0-4` | Weekdays at 9 PM |
| `0 8 * * 1` | Mondays at 8 AM |

## Workflow: Modify Existing Schedule

User: "Change my morning briefing to 7am instead of 6am"

1. List schedules to get the ID:
   ```bash
   /opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --list-schedules
   ```

2. Update the schedule:
   ```bash
   /opt/venv/bin/python3 /usr/local/bin/zeroclaw-scripts/state_manager.py --update-schedule \
     --schedule-id SCHEDULE_ID \
     --schedule-expr "0 7 * * *"
   ```

3. Confirm: "Schedule updated to 7:00 AM. Changes persist across redeployments."

## Troubleshooting

### "No schedules to restore"
No schedules saved to database yet. Create one with `--save-schedule`.

### "state_manager.py not found"
Script should be at `/usr/local/bin/zeroclaw-scripts/state_manager.py`. Rebuild Docker image.

### "Connection refused"
Check `ZEROCLAW_STATE_STORE_URL` is set correctly:
```
postgresql://user:password@host:5432/database?sslmode=require
```
