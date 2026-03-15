#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
from functools import wraps
from datetime import datetime
from typing import Optional, Callable, Any

try:
    import requests
except ImportError:
    print("Error: requests not installed")
    print("Run: pip install requests")
    sys.exit(1)


MAX_RETRIES = 3
RETRY_DELAY = 2
TOKEN_CACHE: dict[str, Any] = {"token": None, "expires": 0}


def get_config() -> dict:
    config = {
        "api_url": os.environ.get("MEMCODE_API_URL", ""),
        "api_key": os.environ.get("MEMCODE_API_KEY", ""),
        "default_course_id": os.environ.get("MEMCODE_DEFAULT_COURSE_ID", ""),
    }
    missing = [k for k, v in config.items() if not v and k in ["api_url", "api_key"]]
    if missing:
        print(f"Error: Missing environment variables: {', '.join(missing)}")
        print("Required: MEMCODE_API_URL, MEMCODE_API_KEY")
        print("Optional: MEMCODE_DEFAULT_COURSE_ID")
        sys.exit(1)
    return config


def rate_limit(max_retries: int = MAX_RETRIES, retry_delay: float = RETRY_DELAY):
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(max_retries):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    error_msg = str(e).lower()
                    if "429" in error_msg or "rate" in error_msg:
                        if attempt < max_retries - 1:
                            wait = retry_delay * (2**attempt)
                            print(
                                f"Rate limited. Retrying in {wait}s... ({attempt + 1}/{max_retries})"
                            )
                            time.sleep(wait)
                            continue
                    raise
            return None

        return wrapper

    return decorator


def get_jwt_token(config: dict) -> str:
    global TOKEN_CACHE
    if TOKEN_CACHE["token"] and TOKEN_CACHE["expires"] > time.time():
        return TOKEN_CACHE["token"]

    resp = requests.get(
        f"{config['api_url']}/api/auth/api-login",
        headers={"X-API-Key": config["api_key"]},
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    TOKEN_CACHE["token"] = data["token"]
    TOKEN_CACHE["expires"] = time.time() + 3600
    return data["token"]


@rate_limit()
def api_request(config: dict, method: str, endpoint: str, data: dict = None) -> dict:
    token = get_jwt_token(config)
    url = f"{config['api_url']}{endpoint}"
    headers = {
        "X-API-Key": config["api_key"],
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    if method == "GET":
        resp = requests.get(url, headers=headers, timeout=30)
    elif method == "POST":
        resp = requests.post(url, headers=headers, json=data, timeout=30)
    elif method == "DELETE":
        resp = requests.delete(url, headers=headers, timeout=30)
    else:
        raise ValueError(f"Unknown method: {method}")
    resp.raise_for_status()
    return resp.json()


def resolve_course_id(config: dict, course_id: Optional[str]) -> int:
    if course_id:
        return int(course_id)
    if config["default_course_id"]:
        return int(config["default_course_id"])
    courses = api_request(config, "POST", "/api/CourseApi.getMyCourses", {})
    if courses and len(courses) > 0:
        return courses[0]["id"]
    print(
        "Error: No courses found. Create a course first with 'memcode-cli course create'"
    )
    sys.exit(1)


def cmd_health(args):
    config = get_config()
    resp = requests.get(f"{config['api_url']}/api/health", timeout=10)
    resp.raise_for_status()
    if args.json:
        print(json.dumps(resp.json(), indent=2))
    else:
        print(f"Status: {resp.json().get('status', 'unknown')}")


def cmd_login(args):
    config = get_config()
    token = get_jwt_token(config)
    if args.json:
        print(json.dumps({"token": token}, indent=2))
    else:
        print(f"Token: {token[:50]}...")


def cmd_list(args):
    config = get_config()
    course_id = resolve_course_id(config, args.course_id)
    problems = api_request(
        config, "POST", "/api/ProblemApi.getAll", {"courseId": course_id}
    )

    if args.json:
        print(json.dumps(problems, indent=2))
        return

    if not problems:
        print("No flashcards found.")
        return

    print(f"Flashcards in course {course_id}:\n")
    for p in problems:
        content = p.get("content", {})
        question = content.get("content", "")[:60]
        answer = content.get("answer", "")[:40] if content.get("answer") else ""
        print(
            f"  [{p['id']}] {p['type']}: {question}{'...' if len(content.get('content', '')) > 60 else ''}"
        )
        if answer:
            print(
                f"       Answer: {answer}{'...' if len(content.get('answer', '')) > 40 else ''}"
            )


def cmd_get(args):
    config = get_config()
    problem = api_request(config, "POST", "/api/ProblemApi.get", {"problemId": args.id})

    if args.json:
        print(json.dumps(problem, indent=2))
        return

    content = problem.get("content", {})
    print(f"ID: {problem['id']}")
    print(f"Type: {problem['type']}")
    print(f"Question: {content.get('content', '')}")
    if content.get("answer"):
        print(f"Answer: {content['answer']}")
    if content.get("explanation"):
        print(f"Explanation: {content['explanation']}")


def cmd_create(args):
    config = get_config()
    course_id = resolve_course_id(config, args.course_id)

    if args.cloze:
        content = {"content": args.question, "explanation": args.answer or ""}
        problem_type = "inlinedAnswers"
    else:
        content = {"content": args.question, "answer": args.answer or ""}
        problem_type = "separateAnswer"

    problem = api_request(
        config,
        "POST",
        "/api/ProblemApi.create",
        {"problem": {"type": problem_type, "content": content, "courseId": course_id}},
    )

    if args.json:
        print(json.dumps(problem, indent=2))
    else:
        print(f"Created flashcard {problem['id']} in course {course_id}")


def cmd_delete(args):
    config = get_config()
    for pid in args.ids:
        api_request(config, "POST", "/api/ProblemApi.delete", {"problemId": int(pid)})
        print(f"Deleted flashcard {pid}")


def cmd_courses(args):
    config = get_config()
    courses = api_request(config, "POST", "/api/CourseApi.getMyCourses", {})

    if args.json:
        print(json.dumps(courses, indent=2))
        return

    if not courses:
        print("No courses found.")
        return

    print("Your courses:\n")
    for c in courses:
        visibility = "public" if c.get("ifPublic") else "private"
        print(f"  [{c['id']}] {c['title']} ({visibility})")
        if c.get("description"):
            print(f"       {c['description'][:60]}")


def cmd_course_create(args):
    config = get_config()
    course = api_request(
        config,
        "POST",
        "/api/CourseApi.createCourse",
        {
            "course": {
                "title": args.title,
                "description": args.description or "",
                "ifPublic": args.public,
            }
        },
    )

    if args.json:
        print(json.dumps(course, indent=2))
    else:
        print(f"Created course {course['id']}: {course['title']}")
        print(f"Set as default: MEMCODE_DEFAULT_COURSE_ID={course['id']}")


def cmd_review(args):
    config = get_config()
    course_id = resolve_course_id(config, args.course_id)
    problems = api_request(
        config, "POST", "/api/ProblemApi.getAll", {"courseId": course_id}
    )

    if not problems:
        print("No flashcards to review.")
        return

    import random

    random.shuffle(problems)

    correct = 0
    total = min(len(problems), args.limit or len(problems))

    print(f"Starting review: {total} cards\n")

    for i, p in enumerate(problems[:total]):
        content = p.get("content", {})
        print(f"[{i + 1}/{total}] {content.get('content', '')}")
        input("\nPress Enter to show answer...")

        if content.get("answer"):
            print(f"\nAnswer: {content['answer']}")
        if content.get("explanation"):
            print(f"Explanation: {content['explanation']}")

        response = input("\nDid you get it right? (y/n/q): ").lower().strip()
        if response == "q":
            break
        elif response == "y":
            correct += 1
        print()

    print(f"\nReview complete: {correct}/{min(i + 1, total)} correct")


def main():
    parser = argparse.ArgumentParser(
        description="Memcode Flashcard CLI",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--json", action="store_true", help="Output as JSON")

    subs = parser.add_subparsers(dest="command", help="Commands")

    sub = subs.add_parser("health", help="Check API health")
    sub.set_defaults(func=cmd_health)

    sub = subs.add_parser("login", help="Get JWT token")
    sub.set_defaults(func=cmd_login)

    sub = subs.add_parser("list", aliases=["ls"], help="List flashcards")
    sub.add_argument(
        "--course-id", "-c", help="Course ID (uses default if not specified)"
    )
    sub.set_defaults(func=cmd_list)

    sub = subs.add_parser("get", help="Get flashcard details")
    sub.add_argument("id", type=int, help="Flashcard ID")
    sub.set_defaults(func=cmd_get)

    sub = subs.add_parser("create", aliases=["add"], help="Create a flashcard")
    sub.add_argument("question", help="Question text (use {{answer}} for cloze)")
    sub.add_argument("--answer", "-a", help="Answer text")
    sub.add_argument("--course-id", "-c", help="Course ID")
    sub.add_argument(
        "--cloze", action="store_true", help="Create as cloze deletion card"
    )
    sub.set_defaults(func=cmd_create)

    sub = subs.add_parser("delete", aliases=["rm"], help="Delete flashcards")
    sub.add_argument("ids", nargs="+", help="Flashcard IDs to delete")
    sub.set_defaults(func=cmd_delete)

    sub = subs.add_parser("courses", help="List courses")
    sub.set_defaults(func=cmd_courses)

    sub = subs.add_parser("course", help="Course management")
    course_subs = sub.add_subparsers(dest="course_command")

    sub = course_subs.add_parser("create", help="Create a course")
    sub.add_argument("title", help="Course title")
    sub.add_argument("--description", "-d", help="Course description")
    sub.add_argument("--public", action="store_true", help="Make course public")
    sub.set_defaults(func=cmd_course_create)

    sub = subs.add_parser("review", help="Interactive review session")
    sub.add_argument("--course-id", "-c", help="Course ID")
    sub.add_argument("--limit", "-n", type=int, help="Max cards to review")
    sub.set_defaults(func=cmd_review)

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if hasattr(args, "course_command") and args.course_command:
        args.func(args)
    elif hasattr(args, "func"):
        args.func(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
