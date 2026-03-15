# Memcode Flashcard CLI

Spaced repetition flashcard management via Memcode API.

## IMPORTANT: Environment Already Configured

The following environment variables are **ALREADY SET** in the system. Do NOT ask the user for them:

- `MEMCODE_API_URL` - Already configured (Memcode production instance)
- `MEMCODE_API_KEY` - Already configured
- `MEMCODE_DEFAULT_USER` - Already configured
- `MEMCODE_DEFAULT_EMAIL` - Already configured
- `MEMCODE_DEFAULT_PASSWORD` - Already configured

**To verify connectivity, simply run:**
```bash
flashcard health
```

If that returns success, everything is configured and working. Proceed with flashcard operations.

## Commands

### Health Check

```bash
flashcard health
```

### Authentication

```bash
flashcard auth
```

Returns JWT token for the default user.

### List Flashcards

```bash
flashcard list
flashcard list --course 3
flashcard list --json
flashcard list --limit 20
```

### Create Flashcard

**Q&A Card (separateAnswer):**
```bash
flashcard create "What is 2+2?" --answer "4"
flashcard create "Capital of France?" --answer "Paris" --course 3
```

**Cloze Deletion Card (inlinedAnswers):**
```bash
flashcard create "The capital of {{France}} is {{Paris}}." --cloze
flashcard create "In {{1492}}, Columbus sailed the ocean blue." --cloze --course 3
```

### Delete Flashcard

```bash
flashcard delete 123
flashcard delete 123 456 789
flashcard rm 123
```

### Courses

```bash
flashcard courses
flashcard courses --json
```

### Create Course

```bash
flashcard course create "My Deck"
flashcard course create "Spanish Vocabulary" --description "Spanish words and phrases"
```

### Study / Review

```bash
flashcard study
flashcard study --course 3
flashcard review
```

### Quiz Mode

```bash
flashcard quiz
flashcard quiz --course 3 --limit 10
```

Interactive quiz with scoring and explanations.

### Search

```bash
flashcard search "python"
flashcard search "regex" --course 3
flashcard search "function" --json
```

## JSON Output

Most commands support `--json` for programmatic use:

```bash
flashcard list --json | jq '.[] | select(.content.content | contains("important"))'
flashcard courses --json | jq '.[] | {id, title}'
```

## Common Workflows

### Daily Review

```bash
flashcard review
```

### Quick Capture

```bash
flashcard create "New concept I learned" "The explanation"
```

### Bulk Add

```bash
flashcard create "Q1" "A1" && flashcard create "Q2" "A2"
```

### Study Specific Topic

```bash
flashcard study --course 3
```

## Card Types

### separateAnswer (Q&A)
Front: Question
Back: Answer

```bash
flashcard create "Question?" "Answer"
```

### inlinedAnswers (Cloze)
Text with hidden portions marked by `{{...}}`

```bash
flashcard create "The {{Moon}} orbits {{Earth}}." --cloze
```

## Troubleshooting

### "MEMCODE_API_URL not set"
Set the environment variable to your Memcode instance URL.

### "MEMCODE_API_KEY not set"
Set the API key from your Memcode settings.

### "Course not found"
Check available courses with `flashcard courses`
Use `--course ID` to specify the correct course.

### "Invalid API key"
Verify `MEMCODE_API_KEY` is correct in environment variables.

## Quick Reference

| Command | Description |
|---------|-------------|
| `flashcard health` | Check API connection |
| `flashcard auth` | Get JWT token |
| `flashcard list` | List all flashcards |
| `flashcard list --course ID` | List cards in course |
| `flashcard create Q A` | Create Q&A card |
| `flashcard create TEXT --cloze` | Create cloze card |
| `flashcard delete ID` | Delete flashcard |
| `flashcard courses` | List courses |
| `flashcard course create TITLE` | Create new course |
| `flashcard study` | Interactive study session |
| `flashcard quiz` | Quiz mode |
| `flashcard search QUERY` | Search flashcards |
