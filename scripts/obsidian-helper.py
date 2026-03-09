#!/usr/bin/env python3
"""
Obsidian Vault Helper

Utilities for working with Obsidian vaults programmatically.
Supports markdown file operations, frontmatter parsing, and search.

Commands:
    search      Search notes by content
    list        List notes (optionally by tag)
    create      Create a new note
    append      Append content to an existing note
    tags        List all tags in the vault
    daily       Create or append to daily note
"""

import argparse
import os
import re
import sys
from datetime import datetime
from pathlib import Path

try:
    import frontmatter
    import yaml
except ImportError:
    print("Error: Required packages not installed")
    print("Run: pip install python-frontmatter pyyaml")
    sys.exit(1)


def get_vault_path():
    path = os.environ.get('OBSIDIAN_VAULT_PATH')
    if not path:
        path = os.environ.get('ZEROCLAW_WORKSPACE', '/zeroclaw-data/.zeroclaw/workspace')
        path = os.path.join(path, 'obsidian-vault')
    
    path = Path(path)
    if not path.exists():
        path.mkdir(parents=True, exist_ok=True)
    return path


def find_markdown_files(vault_path: Path, subdir: str = None):
    base = vault_path / subdir if subdir else vault_path
    if not base.exists():
        return []
    return list(base.rglob('*.md'))


def cmd_search(args):
    vault = get_vault_path()
    pattern = re.compile(args.query, re.IGNORECASE) if args.regex else args.query.lower()
    
    results = []
    for md_file in find_markdown_files(vault):
        try:
            post = frontmatter.load(str(md_file))
            content = post.content.lower()
            rel_path = md_file.relative_to(vault)
            
            if args.regex:
                if pattern.search(post.content):
                    results.append(str(rel_path))
            else:
                if args.query.lower() in content:
                    results.append(str(rel_path))
        except Exception:
            continue
    
    if results:
        for r in results:
            print(r)
    else:
        print("No matches found")


def cmd_list(args):
    vault = get_vault_path()
    files = find_markdown_files(vault, args.subdir)
    
    if args.tag:
        tagged = []
        for md_file in files:
            try:
                post = frontmatter.load(str(md_file))
                tags = post.get('tags', [])
                if isinstance(tags, str):
                    tags = [tags]
                if args.tag in tags:
                    tagged.append(md_file)
            except Exception:
                continue
        files = tagged
    
    for md_file in sorted(files):
        rel_path = md_file.relative_to(vault)
        if args.full:
            try:
                post = frontmatter.load(str(md_file))
                title = post.get('title', md_file.stem)
                print(f"{rel_path} - {title}")
            except Exception:
                print(rel_path)
        else:
            print(rel_path)


def cmd_create(args):
    vault = get_vault_path()
    note_path = vault / args.path
    
    if not note_path.suffix:
        note_path = note_path.with_suffix('.md')
    
    note_path.parent.mkdir(parents=True, exist_ok=True)
    
    if note_path.exists() and not args.force:
        print(f"Error: {args.path} already exists. Use --force to overwrite.")
        sys.exit(1)
    
    metadata = {}
    if args.title:
        metadata['title'] = args.title
    if args.tags:
        metadata['tags'] = [t.strip() for t in args.tags.split(',')]
    if args.date:
        metadata['date'] = datetime.now().strftime('%Y-%m-%d')
    
    content = args.content or ''
    
    post = frontmatter.Post(content, **metadata)
    
    with open(note_path, 'w') as f:
        f.write(frontmatter.dumps(post))
    
    print(f"Created: {note_path.relative_to(vault)}")


def cmd_append(args):
    vault = get_vault_path()
    note_path = vault / args.path
    
    if not note_path.suffix:
        note_path = note_path.with_suffix('.md')
    
    if not note_path.exists():
        print(f"Error: {args.path} not found")
        sys.exit(1)
    
    with open(note_path, 'a') as f:
        if args.timestamp:
            f.write(f"\n\n---\n*{datetime.now().strftime('%Y-%m-%d %H:%M')}*\n")
        f.write(f"\n{args.content}\n")
    
    print(f"Appended to: {note_path.relative_to(vault)}")


def cmd_tags(args):
    vault = get_vault_path()
    all_tags = set()
    
    for md_file in find_markdown_files(vault):
        try:
            post = frontmatter.load(str(md_file))
            tags = post.get('tags', [])
            if isinstance(tags, str):
                tags = [tags]
            all_tags.update(tags)
        except Exception:
            continue
    
    for tag in sorted(all_tags):
        print(f"#{tag}")


def cmd_daily(args):
    vault = get_vault_path()
    today = datetime.now().strftime('%Y-%m-%d')
    
    daily_dir = vault / 'Daily Notes'
    daily_dir.mkdir(parents=True, exist_ok=True)
    
    note_path = daily_dir / f"{today}.md"
    
    if not note_path.exists():
        metadata = {
            'title': f'Daily Note - {today}',
            'date': today,
            'tags': ['daily']
        }
        content = f"# {today}\n\n"
        if args.content:
            content += args.content + "\n"
        
        post = frontmatter.Post(content, **metadata)
        with open(note_path, 'w') as f:
            f.write(frontmatter.dumps(post))
        print(f"Created daily note: {today}")
    else:
        if args.content:
            with open(note_path, 'a') as f:
                f.write(f"\n{args.content}\n")
            print(f"Appended to daily note: {today}")
        else:
            print(f"Daily note exists: {today}")


def cmd_read(args):
    vault = get_vault_path()
    note_path = vault / args.path
    
    if not note_path.suffix:
        note_path = note_path.with_suffix('.md')
    
    if not note_path.exists():
        print(f"Error: {args.path} not found")
        sys.exit(1)
    
    print(note_path.read_text())


def main():
    parser = argparse.ArgumentParser(description='Obsidian Vault Helper')
    subparsers = parser.add_subparsers(dest='command', required=True)
    
    p_search = subparsers.add_parser('search', help='Search notes')
    p_search.add_argument('query', help='Search query')
    p_search.add_argument('--regex', '-r', action='store_true', help='Use regex')
    p_search.set_defaults(func=cmd_search)
    
    p_list = subparsers.add_parser('list', help='List notes')
    p_list.add_argument('--subdir', '-d', help='Subdirectory to search')
    p_list.add_argument('--tag', '-t', help='Filter by tag')
    p_list.add_argument('--full', '-f', action='store_true', help='Show titles')
    p_list.set_defaults(func=cmd_list)
    
    p_create = subparsers.add_parser('create', help='Create note')
    p_create.add_argument('path', help='Note path')
    p_create.add_argument('--content', '-c', help='Note content')
    p_create.add_argument('--title', '-t', help='Note title')
    p_create.add_argument('--tags', help='Comma-separated tags')
    p_create.add_argument('--date', action='store_true', help='Add date')
    p_create.add_argument('--force', '-f', action='store_true', help='Overwrite')
    p_create.set_defaults(func=cmd_create)
    
    p_append = subparsers.add_parser('append', help='Append to note')
    p_append.add_argument('path', help='Note path')
    p_append.add_argument('content', help='Content to append')
    p_append.add_argument('--timestamp', '-t', action='store_true', help='Add timestamp')
    p_append.set_defaults(func=cmd_append)
    
    p_tags = subparsers.add_parser('tags', help='List all tags')
    p_tags.set_defaults(func=cmd_tags)
    
    p_daily = subparsers.add_parser('daily', help='Daily note operations')
    p_daily.add_argument('--content', '-c', help='Content to add')
    p_daily.set_defaults(func=cmd_daily)
    
    p_read = subparsers.add_parser('read', help='Read note content')
    p_read.add_argument('path', help='Note path')
    p_read.set_defaults(func=cmd_read)
    
    args = parser.parse_args()
    args.func(args)


if __name__ == '__main__':
    main()
