#!/usr/bin/env python3
import argparse
import json
import os
import sys
from datetime import datetime

try:
    from todoist_api_python.api import TodoistAPI
except ImportError:
    print("Error: todoist-api-python not installed")
    print("Run: pip install todoist-api-python")
    sys.exit(1)


def get_api():
    token = os.environ.get('TODOIST_API_TOKEN')
    if not token:
        print("Error: TODOIST_API_TOKEN not set")
        sys.exit(1)
    return TodoistAPI(token)


def get_all_tasks(api):
    """Get all tasks handling pagination (iterator of lists)."""
    all_tasks = []
    try:
        tasks_iter = api.get_tasks()
        for task_list in tasks_iter:
            all_tasks.extend(task_list)
        return all_tasks
    except Exception as e:
        print(f"Error fetching tasks: {e}")
        return []


def cmd_list(args):
    api = get_api()
    try:
        tasks = get_all_tasks(api)
        
        if args.project:
            projects = api.get_projects()
            project_map = {p.name.lower(): p.id for p in projects}
            if args.project.lower() in project_map:
                project_id = project_map[args.project.lower()]
                tasks = [t for t in tasks if t.project_id == project_id]
            else:
                print(f"Project '{args.project}' not found")
                return
        
        if args.overdue:
            today = datetime.now().strftime('%Y-%m-%d')
            tasks = [t for t in tasks if t.due and t.due.date < today]
        
        if args.json:
            print(json.dumps([{
                'id': t.id,
                'content': t.content,
                'due': t.due.date if t.due else None,
                'priority': t.priority,
                'project_id': t.project_id,
            } for t in tasks], indent=2))
            return
        
        for task in tasks:
            due = f" [due: {task.due.date}]" if task.due else ""
            priority = "!" * task.priority if task.priority > 1 else ""
            print(f"[{task.id}] {task.content}{due} {priority}")
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_add(args):
    api = get_api()
    try:
        task_data = {'content': args.content}
        
        if args.due:
            task_data['due_string'] = args.due
        
        if args.project:
            projects = api.get_projects()
            project_map = {p.name.lower(): p.id for p in projects}
            if args.project.lower() in project_map:
                task_data['project_id'] = project_map[args.project.lower()]
        
        if args.priority:
            task_data['priority'] = args.priority
        
        if args.labels:
            task_data['labels'] = [l.strip() for l in args.labels.split(',')]
        
        task = api.add_task(**task_data)
        print(f"Created task [{task.id}]: {task.content}")
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_complete(args):
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


def cmd_projects(args):
    api = get_api()
    try:
        projects = api.get_projects()
        for p in projects:
            print(f"[{p.id}] {p.name}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_labels(args):
    api = get_api()
    try:
        labels = api.get_labels()
        for l in labels:
            print(f"[{l.id}] {l.name}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_today(args):
    api = get_api()
    try:
        tasks = get_all_tasks(api)
        today = datetime.now().strftime('%Y-%m-%d')
        today_tasks = [t for t in tasks if t.due and t.due.date == today]
        
        if args.json:
            print(json.dumps([{
                'id': t.id,
                'content': t.content,
                'priority': t.priority,
            } for t in today_tasks], indent=2))
            return
        
        if not today_tasks:
            print("No tasks due today")
            return
        
        print(f"Tasks due today ({today}):")
        for t in today_tasks:
            priority = "!" * t.priority if t.priority > 1 else ""
            print(f"  [{t.id}] {t.content} {priority}")
            
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def cmd_briefing(args):
    api = get_api()
    try:
        tasks = get_all_tasks(api)
        projects = api.get_projects()
        project_map = {p.id: p.name for p in projects}
        
        today = datetime.now().strftime('%Y-%m-%d')
        overdue = [t for t in tasks if t.due and t.due.date < today]
        today_tasks = [t for t in tasks if t.due and t.due.date == today]
        
        print("=" * 40)
        print("DAILY BRIEFING")
        print("=" * 40)
        
        if overdue:
            print(f"\nOVERDUE ({len(overdue)}):")
            for t in overdue:
                proj = project_map.get(t.project_id, 'Inbox')
                print(f"  [{proj}] {t.content} (due: {t.due.date})")
        
        if today_tasks:
            print(f"\nTODAY ({len(today_tasks)}):")
            for t in today_tasks:
                proj = project_map.get(t.project_id, 'Inbox')
                print(f"  [{proj}] {t.content}")
        
        if not overdue and not today_tasks:
            print("\nNo overdue or due today tasks!")
        
        print("=" * 40)
        
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description='Todoist CLI')
    subparsers = parser.add_subparsers(dest='command', required=True)
    
    p_list = subparsers.add_parser('list', help='List tasks')
    p_list.add_argument('--project', '-p', help='Filter by project name')
    p_list.add_argument('--overdue', '-o', action='store_true', help='Show only overdue')
    p_list.add_argument('--json', '-j', action='store_true', help='JSON output')
    p_list.set_defaults(func=cmd_list)
    
    p_add = subparsers.add_parser('add', help='Add a task')
    p_add.add_argument('content', help='Task content')
    p_add.add_argument('--due', '-d', help='Due date (natural language)')
    p_add.add_argument('--project', '-p', help='Project name')
    p_add.add_argument('--priority', type=int, choices=[1,2,3,4], help='Priority (1-4)')
    p_add.add_argument('--labels', '-l', help='Comma-separated labels')
    p_add.set_defaults(func=cmd_add)
    
    p_complete = subparsers.add_parser('complete', help='Complete a task')
    p_complete.add_argument('task_id', help='Task ID')
    p_complete.set_defaults(func=cmd_complete)
    
    p_projects = subparsers.add_parser('projects', help='List projects')
    p_projects.set_defaults(func=cmd_projects)
    
    p_labels = subparsers.add_parser('labels', help='List labels')
    p_labels.set_defaults(func=cmd_labels)
    
    p_today = subparsers.add_parser('today', help="Show today's tasks")
    p_today.add_argument('--json', '-j', action='store_true', help='JSON output')
    p_today.set_defaults(func=cmd_today)
    
    p_briefing = subparsers.add_parser('briefing', help='Daily briefing')
    p_briefing.set_defaults(func=cmd_briefing)
    
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
