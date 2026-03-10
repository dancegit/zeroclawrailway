# Todoist CLI Skill

Task management via Todoist API integration.

## Prerequisites

- `TODOIST_API_TOKEN` must be set in environment
- Get token from: [Todoist Settings → Integrations → API Token](https://todoist.com/app/settings/integrations)

## Basic Commands

### List Tasks

```bash
# All tasks
todoist-cli list

# JSON output for parsing
todoist-cli list --json

# Filter by project
todoist-cli list --project "Work"

# Filter by label
todoist-cli list --label urgent

# Only overdue tasks
todoist-cli list --overdue

# Tasks due today
todoist-cli today

# Today's tasks as JSON
todoist-cli today --json
```

### Add Tasks

```bash
# Simple task
todoist-cli add "Buy groceries"

# With due date
todoist-cli add "Meeting with John" --due "tomorrow"
todoist-cli add "Call mom" --due "2024-12-25"
todoist-cli add "Weekly review" --due "every monday"

# With project
todoist-cli add "Review PR" --project "Work"

# With priority (1-4, 4=highest)
todoist-cli add "Urgent fix" --priority 4

# With labels
todoist-cli add "Task" --labels "urgent,work"

# Full example
todoist-cli add "Quarterly review" --project "Work" --due "next monday" --priority 3 --labels "review,quarterly"
```

### Complete Tasks

```bash
# By task ID
todoist-cli complete 123456789

# Complete multiple
todoist-cli complete 123456789 987654321
```

### Projects

```bash
# List all projects
todoist-cli projects

# List as JSON
todoist-cli projects --json
```

### Labels

```bash
# List all labels
todoist-cli labels
```

### Daily Briefing

```bash
# Generate a daily briefing
todoist-cli briefing

# Briefing as JSON
todoist-cli briefing --json
```

### Archive Tasks

```bash
# Archive a completed task
todoist-cli archive <task_id>

# Archive all completed tasks
todoist-cli archive --all
```

## Common Workflows

### Morning Routine

```bash
# Check today's tasks
todoist-cli today

# Check for overdue items
todoist-cli list --overdue

# Generate briefing
todoist-cli briefing
```

### Quick Capture

```bash
# Capture thought quickly
todoist-cli add "Remember to call dentist" --due "no date"

# Capture and categorize
todoist-cli add "Review proposal" --project "Work" --priority 3
```

### End of Day Review

```bash
# See what's left
todoist-cli list --overdue

# Complete done items
todoist-cli complete <id1> <id2>

# Archive completed
todoist-cli archive --all
```

## Task ID Format

Task IDs are long numeric strings like `1234567890123456789`

When using `--json` output, extract IDs programmatically:
```bash
todoist-cli list --json | jq '.[] | select(.content | contains("keyword")) | .id'
```

## JSON Output Examples

### List tasks with jq

```bash
# Get all task IDs
todoist-cli list --json | jq '.[].id'

# Get tasks by project
todoist-cli list --json | jq '.[] | select(.project_name == "Work")'

# Get high priority tasks
todoist-cli list --json | jq '.[] | select(.priority == 4)'

# Count tasks by project
todoist-cli list --json | jq 'group_by(.project_name) | map({project: .[0].project_name, count: length})'
```

## Troubleshooting

### "Invalid API token"
- Verify `TODOIST_API_TOKEN` is set correctly
- Check token at Todoist Settings → Integrations

### "Project not found"
- Use exact project name (case-sensitive)
- List projects first: `todoist-cli projects`

### "Task not found"
- Task IDs are long numbers
- Use `--json` to get exact IDs

### Rate limiting
- Todoist has API rate limits
- If getting errors, wait a moment and retry

## Integration with Other Tools

### With Obsidian
```bash
# Create note from tasks
todoist-cli today --json | jq '.[] | .content' > /zeroclaw-data/.zeroclaw/workspace/vault/Daily/$(date +%Y-%m-%d).md
```

### With TTS
```bash
# Read tasks aloud
todoist-cli today | kokoro-tts --voice af_sarah - /zeroclaw-data/.zeroclaw/workspace/tts-output/tasks.wav
```

## Quick Reference

| Command | Description |
|---------|-------------|
| `todoist-cli list` | All tasks |
| `todoist-cli list --json` | All tasks as JSON |
| `todoist-cli today` | Today's tasks |
| `todoist-cli add "Task"` | Quick add |
| `todoist-cli add "Task" --due "tomorrow"` | Add with due date |
| `todoist-cli add "Task" --project "Work"` | Add to project |
| `todoist-cli complete ID` | Complete task |
| `todoist-cli projects` | List projects |
| `todoist-cli briefing` | Daily briefing |
| `todoist-cli archive ID` | Archive task |
