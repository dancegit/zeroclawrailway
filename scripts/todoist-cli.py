#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
from functools import wraps
from datetime import datetime
from typing import Optional, Callable

try:
    from todoist_api_python.api import TodoistAPI
except ImportError:
    print("Error: todoist-api-python not installed")
    print("Run: pip install todoist-api-python")
    sys.exit(1)


# Rate limiter configuration
MAX_REQUESTS_PER_MINUTE = 450
MAX_RETRIES = 3
MIN_RETRY_DELAY = 5

_request_timestamps: list[float] = []


class RateLimitError(Exception):
    """Raised when rate limit is exceeded"""

    pass


def rate_limit(
    max_requests: int = MAX_REQUESTS_PER_MINUTE,
    max_retries: int = MAX_RETRIES,
    retry_delay: float = MIN_RETRY_DELAY,
):
    """
    Decorator to rate limit API requests with exponential backoff retry.
    """

    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            global _request_timestamps

            # Clean old timestamps (older than 1 minute)
            current_time = time.time()
            _request_timestamps = [
                ts for ts in _request_timestamps if current_time - ts < 60
            ]

            # Check rate limit
            if len(_request_timestamps) >= max_requests:
                wait_time = 60 - (current_time - _request_timestamps[0])
                if wait_time > 0:
                    print(f"Rate limit reached. Waiting {wait_time:.1f} seconds...")
                    time.sleep(wait_time + 1)
                    _request_timestamps = []

            # Retry logic
            for attempt in range(max_retries):
                try:
                    _request_timestamps.append(time.time())
                    return func(*args, **kwargs)
                except Exception as e:
                    error_msg = str(e).lower()
                    if (
                        "rate" in error_msg
                        or "limit" in error_msg
                        or "429" in error_msg
                    ):
                        if attempt < max_retries - 1:
                            wait = retry_delay * (2**attempt)
                            print(
                                f"Rate limited. Retrying in {wait} seconds... (attempt {attempt + 1}/{max_retries})"
                            )
                            time.sleep(wait)
                            continue
                    raise

            return None

        return wrapper

    return decorator


def get_api() -> TodoistAPI:
    """Get Todoist API instance with token from environment"""
    token = os.environ.get("TODOIST_API_TOKEN")
    if not token:
        print("Error: TODOIST_API_TOKEN not set")
        print("Get your token from: https://todoist.com/app/settings/integrations")
        sys.exit(1)
    return TodoistAPI(token)


@rate_limit()
def get_all_tasks(api: TodoistAPI) -> list:
    """Fetch all tasks handling pagination"""
    all_tasks = []
    try:
        tasks_iter = api.get_tasks()
        for task_list in tasks_iter:
            all_tasks.extend(task_list)
        return all_tasks
    except Exception as e:
        print(f"Error fetching tasks: {e}")
        return []


@rate_limit()
def get_all_completed_tasks(api: TodoistAPI, limit: int = 100) -> list:
    """Fetch completed tasks"""
    try:
        result = api.get_completed_items()
        return result if result else []
    except AttributeError:
        print("Note: Completed tasks retrieval not available in this API version")
        return []
    except Exception as e:
        print(f"Error fetching completed tasks: {e}")
        return []


def cmd_list(args):
    """List tasks with optional filters"""
    api = get_api()
    try:
        tasks = get_all_tasks(api)

        if args.project:
            projects = api.get_projects()
            project_map = {p.name.lower(): p.id for p in projects}
            project_id = project_map.get(args.project.lower())
            if not project_id:
                print(f"Project '{args.project}' not found")
                return
            tasks = [t for t in tasks if t.project_id == project_id]

        if args.overdue:
            today = datetime.now().strftime("%Y-%m-%d")
            tasks = [t for t in tasks if t.due and t.due.date < today]

        if args.today:
            today = datetime.now().strftime("%Y-%m-%d")
            tasks = [t for t in tasks if t.due and t.due.date == today]

        if args.completed:
            tasks = [t for t in tasks if getattr(t, "is_completed", False)]

        if args.json:
            print(
                json.dumps(
                    [
                        {
                            "id": t.id,
                            "content": t.content,
                            "due": t.due.date if t.due else None,
                            "priority": t.priority,
                            "project_id": t.project_id,
                        }
                        for t in tasks
                    ],
                    indent=2,
                )
            )
            return

        if not tasks:
            print("No tasks found")
            return

        for task in tasks:
            due = f" [due: {task.due.date}]" if task.due else ""
            priority = "!" * task.priority if task.priority > 1 else ""
            completed = "[x] " if getattr(task, "is_completed", False) else "[ ] "
            print(f"{completed}[{task.id}] {task.content}{due} {priority}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_add(args):
    """Add a new task"""
    api = get_api()
    try:
        task_data = {"content": args.content}

        if args.due:
            task_data["due_string"] = args.due

        if args.project:
            projects = api.get_projects()
            project_map = {p.name.lower(): p.id for p in projects}
            project_id = project_map.get(args.project.lower())
            if not project_id:
                print(f"Project '{args.project}' not found")
                return
            task_data["project_id"] = project_id

        if args.priority:
            task_data["priority"] = args.priority

        if args.labels:
            task_data["labels"] = [l.strip() for l in args.labels.split(",")]

        task = api.add_task(**task_data)
        print(f"Created task [{task.id}]: {task.content}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_complete(args):
    """Complete a task"""
    api = get_api()
    try:
        success = api.complete_task(args.task_id)
        if success:
            print(f"Completed task {args.task_id}")
        else:
            print(f"Failed to complete task {args.task_id}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_archive(args):
    """Archive a completed task or all completed tasks"""
    api = get_api()
    try:
        if args.all:
            # Archive all completed tasks
            completed = get_all_completed_tasks(api)
            if not completed:
                print("No completed tasks to archive")
                return

            archived_count = 0
            for task in completed:
                try:
                    api.archive_task(task.id)
                    archived_count += 1
                except Exception as e:
                    print(f"Failed to archive task {task.id}: {e}")

            print(f"Archived {archived_count} completed tasks")
        else:
            # Archive specific task
            task_id = args.task_id
            success = api.archive_task(task_id)
            if success:
                print(f"Archived task {task_id}")
            else:
                print(f"Failed to archive task {task_id}")
    except AttributeError:
        print("Note: Archive functionality may require Todoist Pro")
        print("Alternative: Use 'complete' command to mark tasks as done")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_unarchive(args):
    """Unarchive a task"""
    api = get_api()
    try:
        success = api.unarchive_task(args.task_id)
        if success:
            print(f"Unarchived task {args.task_id}")
        else:
            print(f"Failed to unarchive task {args.task_id}")
    except AttributeError:
        print("Note: Unarchive functionality may require Todoist Pro")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_delete(args):
    """Delete a task permanently"""
    api = get_api()
    try:
        success = api.delete_task(args.task_id)
        if success:
            print(f"Deleted task {args.task_id}")
        else:
            print(f"Failed to delete task {args.task_id}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_move(args):
    """Move a task to a different project"""
    api = get_api()
    try:
        # Get project ID from name
        projects = api.get_projects()
        project_map = {p.name.lower(): p.id for p in projects}
        project_id = project_map.get(args.project.lower())

        if not project_id:
            # Try to find by partial match
            matches = [p for p in projects if args.project.lower() in p.name.lower()]
            if len(matches) == 1:
                project_id = matches[0].id
                print(f"Found project: {matches[0].name}")
            elif len(matches) > 1:
                print(f"Multiple projects match '{args.project}':")
                for m in matches:
                    print(f"  - {m.name}")
                return
            else:
                print(f"Project '{args.project}' not found")
                print("Available projects:")
                for p in projects:
                    print(f"  - {p.name}")
                return

        # Move the task by updating its project_id
        success = api.update_task(args.task_id, project_id=project_id)
        if success:
            # Get project name for confirmation
            project_name = next(
                (p.name for p in projects if p.id == project_id), project_id
            )
            print(f"Moved task {args.task_id} to project '{project_name}'")
        else:
            print(f"Failed to move task {args.task_id}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_update(args):
    """Update a task's content, due date, or other properties"""
    api = get_api()
    try:
        update_data = {}

        if args.content:
            update_data["content"] = args.content
        if args.due:
            update_data["due_string"] = args.due
        if args.project:
            projects = api.get_projects()
            project_map = {p.name.lower(): p.id for p in projects}
            project_id = project_map.get(args.project.lower())
            if not project_id:
                print(f"Project '{args.project}' not found")
                return
            update_data["project_id"] = project_id
        if args.priority:
            update_data["priority"] = args.priority
        if args.labels:
            update_data["labels"] = [l.strip() for l in args.labels.split(",")]

        if not update_data:
            print("No updates specified")
            return

        success = api.update_task(args.task_id, **update_data)
        if success:
            print(f"Updated task {args.task_id}")
        else:
            print(f"Failed to update task {args.task_id}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_projects(args):
    """List all projects"""
    api = get_api()
    try:
        projects = api.get_projects()
        for p in projects:
            print(f"[{p.id}] {p.name}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_labels(args):
    """List all labels"""
    api = get_api()
    try:
        labels = api.get_labels()
        for l in labels:
            print(f"[{l.id}] {l.name}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_today(args):
    """Show today's tasks"""
    api = get_api()
    try:
        tasks = get_all_tasks(api)
        today = datetime.now().strftime("%Y-%m-%d")
        today_tasks = [t for t in tasks if t.due and t.due.date == today]

        if args.json:
            print(
                json.dumps(
                    [
                        {
                            "id": t.id,
                            "content": t.content,
                            "priority": t.priority,
                        }
                        for t in today_tasks
                    ],
                    indent=2,
                )
            )
            return

        if not today_tasks:
            print("No tasks due today")
            return

        print(f"Tasks due today ({len(today_tasks)}):")
        for task in today_tasks:
            priority = "!" * task.priority if task.priority > 1 else ""
            print(f"  [{task.id}] {task.content} {priority}")

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_briefing(args):
    """Show daily briefing with overdue and today's tasks"""
    api = get_api()
    try:
        tasks = get_all_tasks(api)
        projects = api.get_projects()
        project_map = {p.id: p.name for p in projects}

        today = datetime.now().strftime("%Y-%m-%d")
        overdue = [t for t in tasks if t.due and t.due.date < today]
        today_tasks = [t for t in tasks if t.due and t.due.date == today]

        print("=" * 40)
        print("DAILY BRIEFING")
        print("=" * 40)

        if overdue:
            print(f"\nOVERDUE ({len(overdue)}):")
            for t in overdue:
                proj = project_map.get(t.project_id, "Inbox")
                priority = "!" * t.priority if t.priority > 1 else ""
                print(f"  [{proj}] {t.content} (due: {t.due.date}) {priority}")

        if today_tasks:
            print(f"\nTODAY ({len(today_tasks)}):")
            for t in today_tasks:
                proj = project_map.get(t.project_id, "Inbox")
                priority = "!" * t.priority if t.priority > 1 else ""
                print(f"  [{proj}] {t.content} {priority}")

        if not overdue and not today_tasks:
            print("\nNo overdue or due today tasks!")

        print("=" * 40)

    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Todoist CLI with rate limiting")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # List command
    p_list = subparsers.add_parser("list", aliases=["ls"], help="List tasks")
    p_list.add_argument("--project", "-p", help="Filter by project name")
    p_list.add_argument(
        "--overdue", "-o", action="store_true", help="Show only overdue"
    )
    p_list.add_argument("--today", "-t", action="store_true", help="Show today's tasks")
    p_list.add_argument(
        "--completed", "-c", action="store_true", help="Show completed tasks"
    )
    p_list.add_argument("--json", "-j", action="store_true", help="JSON output")
    p_list.set_defaults(func=cmd_list)

    # Add command
    p_add = subparsers.add_parser("add", help="Add a task")
    p_add.add_argument("content", help="Task content")
    p_add.add_argument("--due", "-d", help="Due date (natural language)")
    p_add.add_argument("--project", "-p", help="Project name")
    p_add.add_argument(
        "--priority", type=int, choices=[1, 2, 3, 4], help="Priority (1-4)"
    )
    p_add.add_argument("--labels", "-l", help="Comma-separated labels")
    p_add.set_defaults(func=cmd_add)

    # Complete command
    p_complete = subparsers.add_parser(
        "complete", aliases=["done"], help="Complete a task"
    )
    p_complete.add_argument("task_id", help="Task ID")
    p_complete.set_defaults(func=cmd_complete)

    # Archive command
    p_archive = subparsers.add_parser("archive", help="Archive a completed task")
    p_archive.add_argument("task_id", nargs="?", help="Task ID to archive")
    p_archive.add_argument(
        "--all", "-a", action="store_true", help="Archive all completed tasks"
    )
    p_archive.set_defaults(func=cmd_archive)

    # Unarchive command
    p_unarchive = subparsers.add_parser("unarchive", help="Unarchive a task")
    p_unarchive.add_argument("task_id", help="Task ID")
    p_unarchive.set_defaults(func=cmd_unarchive)

    # Delete command
    p_delete = subparsers.add_parser(
        "delete", aliases=["rm"], help="Delete a task permanently"
    )
    p_delete.add_argument("task_id", help="Task ID")
    p_delete.set_defaults(func=cmd_delete)

    p_move = subparsers.add_parser(
        "move", aliases=["mv"], help="Move task to different project"
    )
    p_move.add_argument("task_id", help="Task ID to move")
    p_move.add_argument("project", help="Target project name")
    p_move.set_defaults(func=cmd_move)

    p_update = subparsers.add_parser(
        "update", aliases=["edit"], help="Update task properties"
    )
    p_update.add_argument("task_id", help="Task ID to update")
    p_update.add_argument("--content", "-c", help="New task content")
    p_update.add_argument("--due", "-d", help="New due date (natural language)")
    p_update.add_argument("--project", "-p", help="Move to project")
    p_update.add_argument(
        "--priority", type=int, choices=[1, 2, 3, 4], help="Priority (1-4)"
    )
    p_update.add_argument("--labels", "-l", help="Comma-separated labels")
    p_update.set_defaults(func=cmd_update)

    # Projects command
    p_projects = subparsers.add_parser("projects", help="List projects")
    p_projects.set_defaults(func=cmd_projects)

    # Labels command
    p_labels = subparsers.add_parser("labels", help="List labels")
    p_labels.set_defaults(func=cmd_labels)

    # Today command
    p_today = subparsers.add_parser("today", help="Show today's tasks")
    p_today.add_argument("--json", "-j", action="store_true", help="JSON output")
    p_today.set_defaults(func=cmd_today)

    # Briefing command
    p_briefing = subparsers.add_parser("briefing", help="Daily briefing")
    p_briefing.set_defaults(func=cmd_briefing)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
