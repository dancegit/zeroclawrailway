#!/bin/sh
set -e

export HOME=/zeroclaw-data
WORKSPACE_DIR="/zeroclaw-data/.zeroclaw/workspace"
ZERCLAW_DIR="/zeroclaw-data/.zeroclaw"

mkdir -p "$ZERCLAW_DIR"
mkdir -p "$WORKSPACE_DIR"

# =============================================================================
# Extra Ubuntu Packages Installation
# =============================================================================

install_extra_packages() {
    [ -z "$ZEROCLAW_UBUNTU_INSTALL_EXTRA_PACKAGES" ] && return 0
    
    echo "Installing extra Ubuntu packages..."
    
    # Parse comma-separated list, handling spaces
    OLD_IFS="$IFS"
    IFS=','
    packages=""
    for pkg in $ZEROCLAW_UBUNTU_INSTALL_EXTRA_PACKAGES; do
        pkg=$(echo "$pkg" | tr -d ' ')
        [ -z "$pkg" ] && continue
        packages="$packages $pkg"
    done
    IFS="$OLD_IFS"
    
    if [ -n "$packages" ]; then
        echo "  Packages: $packages"
        apt-get update -qq && \
        apt-get install -y --no-install-recommends $packages && \
        rm -rf /var/lib/apt/lists/* && \
        echo "  ✓ Extra packages installed" || \
        echo "  ⚠️  Some packages may have failed to install"
    fi
}

install_extra_packages

setup_kokoro_tts() {
    [ "${ZEROCLAW_KOKORO_ENABLED:-false}" != "true" ] && return 0
    
    echo "Setting up Kokoro TTS..."
    
    KOKORO_MODEL_DIR="${ZEROCLAW_KOKORO_MODEL_DIR:-$WORKSPACE_DIR/.kokoro-models}"
    KOKORO_OUTPUT_DIR="${ZEROCLAW_KOKORO_OUTPUT_DIR:-$WORKSPACE_DIR/tts-output}"
    mkdir -p "$KOKORO_MODEL_DIR" "$KOKORO_OUTPUT_DIR"
    
    if [ ! -f "$KOKORO_MODEL_DIR/kokoro-v1.0.onnx" ]; then
        echo "  Downloading Kokoro model files (first run)..."
        (
            cd "$KOKORO_MODEL_DIR"
            echo "test" | /opt/venv/bin/kokoro-tts --voice "${ZEROCLAW_KOKORO_VOICE:-af_sarah}" - /dev/null 2>/dev/null || true
        )
        echo "  Model files ready"
    fi
    
    export KOKORO_MODEL_PATH="$KOKORO_MODEL_DIR"
    echo "  Voice: ${ZEROCLAW_KOKORO_VOICE:-af_sarah}"
    echo "  Output: $KOKORO_OUTPUT_DIR"
    echo "  Kokoro TTS configured"
}

setup_modal() {
    [ "${ZEROCLAW_MODAL_ENABLED:-false}" != "true" ] && return 0
    
    echo "Setting up Modal.com..."
    
    if [ -n "$ZEROCLAW_MODAL_TOKEN_ID" ] && [ -n "$ZEROCLAW_MODAL_TOKEN_SECRET" ]; then
        export MODAL_TOKEN_ID="$ZEROCLAW_MODAL_TOKEN_ID"
        export MODAL_TOKEN_SECRET="$ZEROCLAW_MODAL_TOKEN_SECRET"
        echo "  Modal credentials configured"
    elif [ -n "$MODAL_TOKEN_ID" ] && [ -n "$MODAL_TOKEN_SECRET" ]; then
        echo "  Modal credentials found in environment"
    else
        echo "  Modal enabled but no credentials found"
        echo "  Set ZEROCLAW_MODAL_TOKEN_ID and ZEROCLAW_MODAL_TOKEN_SECRET"
    fi
}

setup_kokoro_tts
setup_modal

# =============================================================================
# Todoist Integration
# =============================================================================

setup_todoist() {
    [ -z "$TODOIST_API_TOKEN" ] && return 0
    
    echo "Setting up Todoist integration..."
    
    if /opt/venv/bin/python3 -c "from todoist_api_python.api import TodoistAPI; api = TodoistAPI('$TODOIST_API_TOKEN'); api.get_projects()" >/dev/null 2>&1; then
        echo "  API token validated"
        echo "  Use: todoist-cli list|add|complete|today|briefing"
    else
        echo "  Invalid Todoist API token"
    fi
}

# =============================================================================
# Gmail/Google OAuth2 Integration
# =============================================================================

setup_gmail_oauth() {
    [ -z "$GMAIL_CLIENT_ID" ] && [ -z "$GMAIL_CLIENT_SECRET" ] && return 0
    
    echo "Setting up Gmail/Google OAuth2..."
    
    GMAIL_CREDENTIALS_DIR="${WORKSPACE_DIR}/.google-credentials"
    mkdir -p "$GMAIL_CREDENTIALS_DIR"
    
    if [ -n "$GMAIL_CLIENT_ID" ] && [ -n "$GMAIL_CLIENT_SECRET" ] && [ -n "$GMAIL_REFRESH_TOKEN" ]; then
        cat > "$GMAIL_CREDENTIALS_DIR/credentials.json" << GMAIL_CREDS
{
  "client_id": "$GMAIL_CLIENT_ID",
  "client_secret": "$GMAIL_CLIENT_SECRET",
  "refresh_token": "$GMAIL_REFRESH_TOKEN",
  "token_uri": "https://oauth2.googleapis.com/token"
}
GMAIL_CREDS
        chmod 600 "$GMAIL_CREDENTIALS_DIR/credentials.json"
        echo "  Credentials file created"
        echo "  Use: google-oauth-helper --validate to verify"
    else
        echo "  Partial credentials provided"
        echo "  Need: GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET, GMAIL_REFRESH_TOKEN"
        echo "  Run: google-oauth-helper to generate tokens"
    fi
}

# =============================================================================
# Obsidian Vault Integration
# =============================================================================

setup_obsidian() {
    OBSIDIAN_VAULT="${OBSIDIAN_VAULT_PATH:-$WORKSPACE_DIR/obsidian-vault}"
    
    mkdir -p "$OBSIDIAN_VAULT"
    
    [ ! -d "$OBSIDIAN_VAULT" ] && return 0
    
    if [ "$(ls -A $OBSIDIAN_VAULT 2>/dev/null)" ]; then
        note_count=$(find "$OBSIDIAN_VAULT" -name "*.md" 2>/dev/null | wc -l)
        echo "Obsidian vault configured ($note_count notes)"
    else
        echo "Obsidian vault initialized (empty)"
        mkdir -p "$OBSIDIAN_VAULT/Daily Notes"
        mkdir -p "$OBSIDIAN_VAULT/Attachments"
    fi
    
    export OBSIDIAN_VAULT_PATH="$OBSIDIAN_VAULT"
}

setup_todoist
setup_gmail_oauth
setup_obsidian

# =============================================================================
# Git Repository Cloning
# =============================================================================

clone_git_repos() {
    [ -z "$ZEROCLAW_GIT_REPOS" ] && return 0
    
    AUTH_TOKEN="${GITHUB_TOKEN:-$GH_TOKEN}"
    echo "Cloning git repos into workspace..."
    
    OLD_IFS="$IFS"
    IFS=','
    for repo in $ZEROCLAW_GIT_REPOS; do
        repo=$(echo "$repo" | tr -d ' ')
        [ -z "$repo" ] && continue
        
        case "$repo" in
            https://*|http://*|git@*)
                repo_url="$repo"
                repo_name=$(echo "$repo" | sed 's/.*\///; s/\.git$//')
                ;;
            *)
                repo_name=$(echo "$repo" | sed 's/.*\///')
                if [ -n "$AUTH_TOKEN" ]; then
                    repo_url="https://${AUTH_TOKEN}@github.com/${repo}.git"
                else
                    repo_url="https://github.com/${repo}.git"
                fi
                ;;
        esac
        
        clone_dir="$WORKSPACE_DIR/$repo_name"
        
        if [ -d "$clone_dir" ]; then
            echo "  ↳ $repo_name already exists, pulling latest..."
            (cd "$clone_dir" && git pull --rebase) || echo "  ⚠️  Failed to pull $repo_name"
        else
            echo "  ↳ Cloning $repo_name..."
            if git clone --depth 1 "$repo_url" "$clone_dir" 2>/dev/null; then
                echo "  ✓ Cloned $repo_name"
            else
                echo "  ⚠️  Failed to clone $repo_name (may need auth token)"
            fi
        fi
    done
    IFS="$OLD_IFS"
    echo "Git repos ready."
}

# =============================================================================
# Repository Analysis for SOUL.md Generation
# =============================================================================

analyze_repo_structure() {
    local repo_dir="$1"
    local depth="${ZEROCLAW_SOUL_ANALYZE_DEPTH:-2}"
    
    [ ! -d "$repo_dir" ] && return
    
    echo "### Directory Structure"
    echo '```'
    (cd "$repo_dir" && find . -maxdepth "$depth" -type f -name "*.rs" -o -name "*.ts" -o -name "*.tsx" -o -name "*.py" -o -name "*.go" -o -name "*.js" -o -name "*.json" -o -name "*.yaml" -o -name "*.yaml" -o -name "*.toml" -o -name "*.md" 2>/dev/null | head -50 | sort)
    echo '```'
    echo ""
}

detect_tech_stack() {
    local repo_dir="$1"
    local stack=""
    
    [ ! -d "$repo_dir" ] && return
    
    if [ -f "$repo_dir/Cargo.toml" ]; then
        stack="$stack- **Rust**: "
        stack="$stack$(grep -E "^name|^version" "$repo_dir/Cargo.toml" 2>/dev/null | tr '\n' ' ' | head -c 100)"
        stack="$stack\n"
    fi
    
    if [ -f "$repo_dir/package.json" ]; then
        stack="$stack- **Node.js/TypeScript**: "
        stack="$stack$(grep -E '"name"|"version"' "$repo_dir/package.json" 2>/dev/null | tr '\n' ' ' | head -c 100)"
        stack="$stack\n"
    fi
    
    if [ -f "$repo_dir/pyproject.toml" ] || [ -f "$repo_dir/requirements.txt" ] || [ -f "$repo_dir/setup.py" ]; then
        stack="$stack- **Python** project detected\n"
    fi
    
    if [ -f "$repo_dir/go.mod" ]; then
        stack="$stack- **Go**: "
        stack="$stack$(head -5 "$repo_dir/go.mod" 2>/dev/null | tr '\n' ' ')"
        stack="$stack\n"
    fi
    
    if [ -f "$repo_dir/Dockerfile" ] || [ -f "$repo_dir/docker-compose.yml" ]; then
        stack="$stack- **Docker** containerization\n"
    fi
    
    if [ -f "$repo_dir/sql/" ] || ls "$repo_dir"/*.sql 1>/dev/null 2>&1; then
        stack="$stack- **SQL/Database** schemas present\n"
    fi
    
    printf "%s" "$stack"
}

scan_dependencies() {
    local repo_dir="$1"
    local deps=""
    local max_deps=20
    
    [ ! -d "$repo_dir" ] && return
    
    if [ -f "$repo_dir/Cargo.toml" ]; then
        local cargo_deps=$(grep -A 100 "^\[dependencies\]" "$repo_dir/Cargo.toml" 2>/dev/null | grep -B 100 "^\[" | grep -v "^\[" | grep -v "^$" | grep "^[a-z]" | head -$max_deps | awk -F'=' '{print $1}' | tr -d ' ' | tr '\n' ', ' | sed 's/,$//')
        if [ -n "$cargo_deps" ]; then
            deps="$deps- **Rust (Cargo)**: $cargo_deps\n"
        fi
    fi
    
    if [ -f "$repo_dir/package.json" ]; then
        local npm_deps=$(cat "$repo_dir/package.json" 2>/dev/null | grep -A 100 '"dependencies"' | grep -B 100 "}" | grep ":" | grep -v "dependencies" | head -$max_deps | sed 's/[",:]//g' | awk '{print $1}' | tr '\n' ', ' | sed 's/,$//')
        if [ -n "$npm_deps" ]; then
            deps="$deps- **Node.js (npm)**: $npm_deps\n"
        fi
        local dev_deps=$(cat "$repo_dir/package.json" 2>/dev/null | grep -A 100 '"devDependencies"' | grep -B 100 "}" | grep ":" | grep -v "devDependencies" | head -10 | sed 's/[",:]//g' | awk '{print $1}' | tr '\n' ', ' | sed 's/,$//')
        if [ -n "$dev_deps" ]; then
            deps="$deps- **Dev Dependencies**: $dev_deps\n"
        fi
    fi
    
    if [ -f "$repo_dir/requirements.txt" ]; then
        local py_deps=$(grep -v "^#" "$repo_dir/requirements.txt" 2>/dev/null | grep -v "^$" | head -$max_deps | sed 's/[<>=!].*//' | tr '\n' ', ' | sed 's/,$//')
        if [ -n "$py_deps" ]; then
            deps="$deps- **Python (requirements)**: $py_deps\n"
        fi
    fi
    
    if [ -f "$repo_dir/pyproject.toml" ]; then
        local poetry_deps=$(grep -A 50 "^\[tool.poetry.dependencies\]" "$repo_dir/pyproject.toml" 2>/dev/null | grep -v "^\[" | grep -v "^$" | grep "^[a-z]" | head -$max_deps | awk -F'=' '{print $1}' | tr -d ' ' | tr '\n' ', ' | sed 's/,$//')
        if [ -n "$poetry_deps" ]; then
            deps="$deps- **Python (Poetry)**: $poetry_deps\n"
        fi
    fi
    
    if [ -f "$repo_dir/go.mod" ]; then
        local go_deps=$(grep "^\s*require" "$repo_dir/go.mod" 2>/dev/null | head -1 | sed 's/require//' | tr -d '()' | tr '\n' ' ' | awk '{for(i=1;i<=NF&&i<='$max_deps';i++) printf "%s, ", $i}' | sed 's/, $//')
        if [ -n "$go_deps" ]; then
            deps="$deps- **Go modules**: $go_deps\n"
        fi
    fi
    
    printf "%s" "$deps"
}

scan_code_patterns() {
    local repo_dir="$1"
    local patterns=""
    
    [ ! -d "$repo_dir" ] && return
    
    if [ -f "$repo_dir/Cargo.toml" ]; then
        local has_async=$(grep -r "async fn" "$repo_dir/src" 2>/dev/null | head -1)
        local has_trait=$(grep -r "^pub trait" "$repo_dir/src" 2>/dev/null | head -1)
        local has_impl=$(grep -r "^impl" "$repo_dir/src" 2>/dev/null | head -1)
        local has_error=$(grep -r "thiserror\|anyhow\|Result<" "$repo_dir/src" 2>/dev/null | head -1)
        
        if [ -n "$has_async" ] || [ -n "$has_trait" ]; then
            patterns="$patterns- **Rust patterns**: "
            [ -n "$has_async" ] && patterns="$patterns async/await,"
            [ -n "$has_trait" ] && patterns="$patterns traits,"
            [ -n "$has_impl" ] && patterns="$patterns impl blocks,"
            [ -n "$has_error" ] && patterns="$patterns Result-based error handling"
            patterns="$patterns\n"
        fi
    fi
    
    if [ -f "$repo_dir/package.json" ]; then
        local has_async=$(grep -r "async function\|async (" "$repo_dir/src" "$repo_dir/lib" 2>/dev/null | head -1)
        local has_class=$(grep -r "^class\|^export class" "$repo_dir/src" "$repo_dir/lib" 2>/dev/null | head -1)
        local has_hooks=$(grep -r "use[A-Z]" "$repo_dir/src" "$repo_dir/lib" 2>/dev/null | head -1)
        local has_ts=$(ls "$repo_dir/src"/*.ts "$repo_dir/src"/*.tsx 2>/dev/null | head -1)
        
        if [ -n "$has_async" ] || [ -n "$has_class" ] || [ -n "$has_hooks" ]; then
            patterns="$patterns- **TypeScript/JS patterns**: "
            [ -n "$has_ts" ] && patterns="$patterns TypeScript,"
            [ -n "$has_async" ] && patterns="$patterns async/await,"
            [ -n "$has_class" ] && patterns="$patterns class-based,"
            [ -n "$has_hooks" ] && patterns="$patterns React hooks"
            patterns="$patterns\n"
        fi
    fi
    
    if [ -f "$repo_dir/pyproject.toml" ] || [ -f "$repo_dir/requirements.txt" ]; then
        local has_class=$(grep -r "^class " "$repo_dir/src" "$repo_dir/app" "$repo_dir/lib" 2>/dev/null | head -1)
        local has_async=$(grep -r "async def\|await " "$repo_dir/src" "$repo_dir/app" 2>/dev/null | head -1)
        local has_dataclass=$(grep -r "@dataclass" "$repo_dir/src" "$repo_dir/app" 2>/dev/null | head -1)
        
        if [ -n "$has_class" ] || [ -n "$has_async" ]; then
            patterns="$patterns- **Python patterns**: "
            [ -n "$has_class" ] && patterns="$patterns class-based,"
            [ -n "$has_async" ] && patterns="$patterns async/await,"
            [ -n "$has_dataclass" ] && patterns="$patterns dataclasses"
            patterns="$patterns\n"
        fi
    fi
    
    if [ -f "$repo_dir/go.mod" ]; then
        local has_interface=$(grep -r "^type.*interface" "$repo_dir" 2>/dev/null | head -1)
        local has_struct=$(grep -r "^type.*struct" "$repo_dir" 2>/dev/null | head -1)
        local has_goroutine=$(grep -r "go func\|go " "$repo_dir" 2>/dev/null | head -1)
        
        if [ -n "$has_interface" ] || [ -n "$has_struct" ]; then
            patterns="$patterns- **Go patterns**: "
            [ -n "$has_interface" ] && patterns="$patterns interfaces,"
            [ -n "$has_struct" ] && patterns="$patterns structs,"
            [ -n "$has_goroutine" ] && patterns="$patterns goroutines"
            patterns="$patterns\n"
        fi
    fi
    
    printf "%s" "$patterns"
}

get_repo_readme_summary() {
    local repo_dir="$1"
    local readme=""
    
    # Try common README names
    for name in README.md README.rst README.txt readme.md; do
        if [ -f "$repo_dir/$name" ]; then
            readme="$repo_dir/$name"
            break
        fi
    done
    
    if [ -n "$readme" ]; then
        echo "### README Summary"
        echo '```'
        head -30 "$readme" 2>/dev/null
        echo '```'
        echo ""
    fi
}

# =============================================================================
# SOUL.md Generation
# =============================================================================

generate_soul_md() {
    local soul_file="$WORKSPACE_DIR/SOUL.md"
    local generate_dynamic="${ZEROCLAW_SOUL_GENERATE_DYNAMIC:-false}"
    local base_input="${ZEROCLAW_SOUL_DESCRIPTION_INPUT:-}"
    local max_size_kb="${ZEROCLAW_SOUL_MAX_SIZE_KB:-50}"
    
    echo "Generating agent soul context..."
    
    # Start with header
    cat > "$soul_file" << SOUL_HEADER
# Agent Soul Context

> Auto-generated on $(date -u +"%Y-%m-%dT%H:%M:%SZ")
> Provider: ${ZEROCLAW_PROVIDER:-unknown}
> Model: ${ZEROCLAW_MODEL:-unknown}

---

SOUL_HEADER

    # Add base input if provided
    if [ -n "$base_input" ]; then
        echo "$base_input" >> "$soul_file"
        echo "" >> "$soul_file"
        echo "---" >> "$soul_file"
        echo "" >> "$soul_file"
    fi

    # Add dynamic analysis if enabled
    if [ "$generate_dynamic" = "true" ] && [ -n "$ZEROCLAW_GIT_REPOS" ]; then
        echo "## Repository Context" >> "$soul_file"
        echo "" >> "$soul_file"
        echo "Configured repositories: \`$ZEROCLAW_GIT_REPOS\`" >> "$soul_file"
        echo "" >> "$soul_file"
        
        OLD_IFS="$IFS"
        IFS=','
        for repo in $ZEROCLAW_GIT_REPOS; do
            repo=$(echo "$repo" | tr -d ' ')
            repo_name=$(echo "$repo" | sed 's/.*\///; s/\.git$//')
            repo_dir="$WORKSPACE_DIR/$repo_name"
            
            if [ -d "$repo_dir" ]; then
                echo "### $repo_name" >> "$soul_file"
                echo "" >> "$soul_file"
                
                # Tech stack detection
                tech_stack=$(detect_tech_stack "$repo_dir")
                if [ -n "$tech_stack" ]; then
                    echo "**Technology Stack:**" >> "$soul_file"
                    printf "%s" "$tech_stack" >> "$soul_file"
                    echo "" >> "$soul_file"
                fi
                
                # Dependency analysis
                deps=$(scan_dependencies "$repo_dir")
                if [ -n "$deps" ]; then
                    echo "**Dependencies:**" >> "$soul_file"
                    printf "%s" "$deps" >> "$soul_file"
                    echo "" >> "$soul_file"
                fi
                
                # Code patterns
                patterns=$(scan_code_patterns "$repo_dir")
                if [ -n "$patterns" ]; then
                    echo "**Code Patterns:**" >> "$soul_file"
                    printf "%s" "$patterns" >> "$soul_file"
                    echo "" >> "$soul_file"
                fi
                
                # Structure analysis
                analyze_repo_structure "$repo_dir" >> "$soul_file"
                
                # README summary
                get_repo_readme_summary "$repo_dir" >> "$soul_file"
            fi
        done
        IFS="$OLD_IFS"
    fi

    # Add integration capabilities section
    INTEGRATIONS=""
    [ -n "$TODOIST_API_TOKEN" ] && INTEGRATIONS="$INTEGRATIONS- **Todoist**: Task management via \`todoist-cli\`\n"
    [ -n "$GMAIL_REFRESH_TOKEN" ] && INTEGRATIONS="$INTEGRATIONS- **Gmail**: Email access via Google API\n"
    [ -d "$OBSIDIAN_VAULT_PATH" ] || [ -d "$WORKSPACE_DIR/obsidian-vault" ] && INTEGRATIONS="$INTEGRATIONS- **Obsidian**: Note management via \`obsidian-helper\`\n"
    [ "${ZEROCLAW_KOKORO_ENABLED:-false}" = "true" ] && INTEGRATIONS="$INTEGRATIONS- **TTS**: Text-to-speech via \`kokoro-tts\`\n"
    [ "${ZEROCLAW_MODAL_ENABLED:-false}" = "true" ] && INTEGRATIONS="$INTEGRATIONS- **Modal GPU**: Serverless GPU acceleration\n"
    [ -n "$RSS_FEEDS" ] && INTEGRATIONS="$INTEGRATIONS- **News/RSS**: Feed aggregation available\n"
    
    if [ -n "$INTEGRATIONS" ]; then
        cat >> "$soul_file" << INTEGRATIONS_SECTION

## Integration Capabilities

$(printf "%s" "$INTEGRATIONS")

**CLI Tools Available:**
- \`todoist-cli list|add|complete|today|briefing\` - Task management
- \`obsidian-helper search|list|create|daily\` - Note operations
- \`google-oauth-helper\` - OAuth token management
- \`kokoro-tts\` - Text-to-speech synthesis
INTEGRATIONS_SECTION
    fi

    # Add operating context
    cat >> "$soul_file" << SOUL_FOOTER

## Operating Context

- **Workspace**: \`$WORKSPACE_DIR\`
- **Autonomy Level**: ${ZEROCLAW_AUTONOMY_LEVEL:-full}
- **Git Author**: ${GIT_AUTHOR_NAME:-unknown} <${GIT_AUTHOR_EMAIL:-unknown}>

## Agent Instructions

When working on tasks:
1. Always check the workspace directory for repository context
2. Follow existing code patterns and conventions
3. Run appropriate tests before marking work complete
4. Commit changes with descriptive messages
5. Report progress via task comments
6. Use available integrations (Todoist, Obsidian, Gmail) when relevant

## Skills Reference

Detailed skill documentation is available in \`$WORKSPACE_DIR/.zeroclaw/skills/\`:

- **kokoro-tts.md** - Text-to-speech synthesis, voice options, sending audio via Telegram
- **telegram-attachments.md** - How to send files/images/audio via Telegram (ALWAYS use absolute paths)
- **todoist-cli.md** - Task management commands and workflows

**Critical for TTS/Audio tasks:**
- Generate audio: \`echo "text" | kokoro-tts --voice af_sarah - /zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav\`
- Send attachment: Use ABSOLUTE path like \`/zeroclaw-data/.zeroclaw/workspace/tts-output/output.wav\`
- Relative paths will NOT work for attachments

---
*This file is regenerated on container restart. Manual changes will be lost.*
SOUL_FOOTER

    # Check size limit
    size_kb=$(wc -c < "$soul_file" | awk '{print int($1/1024)}')
    if [ "$size_kb" -gt "$max_size_kb" ]; then
        echo "  ⚠️  SOUL.md exceeds ${max_size_kb}KB limit (${size_kb}KB), truncating..."
        # Keep header and first sections, truncate analysis
        head -100 "$soul_file" > "${soul_file}.tmp"
        echo "" >> "${soul_file}.tmp"
        echo "*[Content truncated due to size limit]*" >> "${soul_file}.tmp"
        mv "${soul_file}.tmp" "$soul_file"
    fi
    
    echo "  ✓ Generated SOUL.md ($size_kb KB)"
}

# =============================================================================
# AGENTS.md Generation (Optional)
# =============================================================================

generate_agents_md() {
    local agents_file="$WORKSPACE_DIR/AGENTS.md"
    local generate="${ZEROCLAW_AGENTS_GENERATE_DYNAMIC:-false}"
    
    [ "$generate" != "true" ] && return
    
    echo "Generating agent role definitions..."
    
    cat > "$agents_file" << AGENTS_HEADER
# Available Agent Roles

> Auto-generated from taskboard configuration

---

AGENTS_HEADER

    # Add base input if provided
    if [ -n "$ZEROCLAW_AGENTS_DESCRIPTION_INPUT" ]; then
        echo "$ZEROCLAW_AGENTS_DESCRIPTION_INPUT" >> "$agents_file"
        echo "" >> "$agents_file"
    fi

    # Add role definitions
    cat >> "$agents_file" << 'AGENT_ROLES'

## Core Development Agents

| Role | ID | Focus |
|------|-----|-------|
| Main Agent | `main` | General coordination, task execution |
| Architect | `architect` | System design, patterns, scalability |
| Security Auditor | `security-auditor` | Security review, compliance |
| Code Reviewer | `code-reviewer` | Code quality, best practices |
| UX Manager | `ux-manager` | User experience, interface design |

## Personal Assistant Agents

| Role | ID | Focus |
|------|-----|-------|
| Task Manager | `task-manager` | Todoist integration, task prioritization |
| Email Assistant | `email-assistant` | Gmail/IMAP, email triage, drafting |
| Note Keeper | `note-keeper` | Obsidian vault, knowledge management |
| News Curator | `news-curator` | RSS feeds, news summarization |
| Daily Briefing | `daily-briefing` | Morning summaries, agenda planning |
| Calendar Manager | `calendar-manager` | Google Calendar, scheduling |

## Development Specialists

| Role | ID | Focus |
|------|-----|-------|
| Frontend Developer | `frontend-dev` | UI implementation, client-side |
| Backend Developer | `backend-dev` | API, services, server-side |
| Data Engineer | `data-engineer` | Data pipelines, databases |
| DevOps Engineer | `devops-engineer` | Infrastructure, deployment |
| Test Engineer | `test-agent` | Testing, QA |
| Verification Engineer | `verification-engineer` | Verification, validation |

## Planning & Management

| Role | ID | Focus |
|------|-----|-------|
| Product Owner | `product-owner` | Requirements, priorities |
| Business Analyst | `business-analyst` | Analysis, documentation |
| UX Designer | `ux-designer` | Design, user research |
| Scrum Master | `scrum-master` | Process, coordination |

---

## Role Resolution

Agents use a fallback chain for resilience:
- Primary agent is tried first
- If unavailable, fallback agents are attempted
- Final fallback is always `main`

Example: `ux-designer` → `ux-manager` → `main`

---

## Personal Assistant System Prompts

### Task Manager (`task-manager`)
```
You are a task management specialist integrated with Todoist.
Help users organize, prioritize, and track tasks efficiently.
Suggest task breakdowns and time estimates.
Generate daily briefings from task lists.
Use todoist-cli commands to manage tasks programmatically.
```

### Email Assistant (`email-assistant`)
```
You are an email management assistant with Gmail/IMAP access.
Help users triage, summarize, and draft emails.
Identify urgent messages and action items.
Draft professional email responses.
Maintain inbox zero principles when organizing.
```

### Note Keeper (`note-keeper`)
```
You are a knowledge management assistant for Obsidian vaults.
Help users capture, organize, and retrieve notes.
Maintain consistent frontmatter and tagging.
Create connections between related notes.
Generate daily and weekly summaries from notes.
```

### News Curator (`news-curator`)
```
You are a news aggregation and summarization assistant.
Monitor RSS feeds and news sources.
Filter and prioritize news by relevance.
Generate concise news summaries.
Identify trending topics and key developments.
```

### Daily Briefing (`daily-briefing`)
```
You are a daily briefing generator combining multiple sources.
Aggregate tasks from Todoist, emails, calendar events, and news.
Create prioritized morning briefings.
Highlight urgent items and deadlines.
Suggest daily focus areas based on workload.
```

---

## Available CLI Tools Reference

### Task Management: `todoist-cli`

| Command | Description |
|---------|-------------|
| `todoist-cli list` | List all tasks |
| `todoist-cli list --project NAME` | Filter by project |
| `todoist-cli list --overdue` | Show only overdue |
| `todoist-cli list --json` | JSON output |
| `todoist-cli add "Task" --due "tomorrow"` | Add task with due date |
| `todoist-cli add "Task" --project Work --priority 4` | Add with project and priority |
| `todoist-cli add "Task" --labels "urgent,work"` | Add with labels |
| `todoist-cli complete TASK_ID` | Complete a task |
| `todoist-cli projects` | List all projects |
| `todoist-cli labels` | List all labels |
| `todoist-cli today` | Tasks due today |
| `todoist-cli today --json` | Today's tasks as JSON |
| `todoist-cli briefing` | Generate daily briefing |

### Obsidian Vault: `obsidian-helper`

| Command | Description |
|---------|-------------|
| `obsidian-helper list` | List all markdown notes |
| `obsidian-helper list --subdir Notes` | List notes in subdirectory |
| `obsidian-helper list --tag project` | Filter by frontmatter tag |
| `obsidian-helper list --full` | Show with titles |
| `obsidian-helper search "keyword"` | Full-text search |
| `obsidian-helper search "re.gex" --regex` | Regex search |
| `obsidian-helper create "path/note"` | Create new note |
| `obsidian-helper create "note" --title "Title" --tags "tag1,tag2"` | Create with metadata |
| `obsidian-helper create "note" --content "Body text"` | Create with content |
| `obsidian-helper append "path/note" "Add this"` | Append to existing note |
| `obsidian-helper append "note" "text" --timestamp` | Append with timestamp |
| `obsidian-helper daily` | Create/append daily note |
| `obsidian-helper daily --content "Entry"` | Append to today's note |
| `obsidian-helper tags` | List all tags in vault |
| `obsidian-helper read "path/note"` | Read note content |

### Google OAuth: `google-oauth-helper`

| Command | Description |
|---------|-------------|
| `google-oauth-helper` | Show setup instructions |
| `google-oauth-helper --client-id X --client-secret Y --scopes all` | Generate refresh token |
| `google-oauth-helper --scopes gmail` | Gmail-only scopes |
| `google-oauth-helper --scopes calendar` | Calendar-only scopes |
| `google-oauth-helper --validate --refresh-token X --client-id Y --client-secret Z` | Validate existing token |
| `google-oauth-helper --output json` | Output as JSON |

### Text-to-Speech: `kokoro-tts`

| Command | Description |
|---------|-------------|
| `echo "text" \| kokoro-tts --voice af_sarah - output.wav` | stdin to audio |
| `kokoro-tts --voice am_adam --speed 1.2 input.txt output.wav` | File to audio |
| Voices: `af_sarah`, `af_nicole`, `af_sky`, `am_adam`, `bf_emma`, `bm_george` | Available voices |

### Modal GPU: `modal`

| Command | Description |
|---------|-------------|
| `modal token new` | Generate new tokens (run locally) |
| `modal run app.py` | Run function on GPU |
| `modal deploy app.py` | Deploy as endpoint |

---

## Core Development Agent Prompts

### Main Agent (`main`)
```
You are a versatile software agent capable of handling diverse development tasks.
Focus on understanding the user's intent and delivering working solutions.
Use available tools to read, write, and execute code as needed.
Report progress clearly and ask for clarification when requirements are ambiguous.
```

### Architect (`architect`)
```
You are a software architect focused on system design and technical decisions.
Evaluate trade-offs between approaches (performance vs maintainability vs cost).
Document architectural decisions with rationale.
Consider scalability, security, and operational concerns.
Propose concrete implementation plans, not just high-level ideas.
```

### Security Auditor (`security-auditor`)
```
You are a security-focused agent reviewing code and systems for vulnerabilities.
Check for: injection risks, authentication issues, data exposure, misconfigurations.
Reference OWASP guidelines and security best practices.
Provide specific remediation steps, not just problem identification.
Prioritize findings by severity and exploitability.
```

### Code Reviewer (`code-reviewer`)
```
You are a code reviewer focused on quality, maintainability, and best practices.
Check for: code smells, naming conventions, error handling, test coverage.
Suggest improvements that are actionable and specific.
Balance strictness with pragmatism - not every style issue needs fixing.
Focus on changes that measurably improve the codebase.
```

### Backend Developer (`backend-dev`)
```
You are a backend developer focused on APIs, services, and data processing.
Design RESTful/GraphQL APIs with clear contracts.
Handle errors gracefully and log appropriately.
Consider database performance and query optimization.
Write tests for critical paths and edge cases.
```

### Frontend Developer (`frontend-dev`)
```
You are a frontend developer focused on user interfaces and client-side logic.
Create responsive, accessible UI components.
Manage state efficiently and handle loading/error states.
Optimize for performance (lazy loading, code splitting).
Follow existing component patterns and design system.
```

### DevOps Engineer (`devops-engineer`)
```
You are a DevOps engineer focused on infrastructure and deployment.
Automate repetitive tasks with scripts and CI/CD pipelines.
Monitor system health and set up alerting.
Document infrastructure and runbooks.
Consider cost optimization and security hardening.
```

### Test Engineer (`test-agent`)
```
You are a test engineer focused on quality assurance.
Write unit, integration, and end-to-end tests as appropriate.
Focus on edge cases, error conditions, and boundary values.
Ensure tests are maintainable and not brittle.
Report test results clearly with reproduction steps for failures.
```

### Data Engineer (`data-engineer`)
```
You are a data engineer focused on data pipelines and storage.
Design efficient ETL/ELT processes.
Ensure data quality and handle schema evolution.
Consider scalability for large datasets.
Document data models and transformation logic.
```

---
*This file is regenerated on container restart.*
AGENT_ROLES

    echo "  ✓ Generated AGENTS.md"
}

# =============================================================================
# Copy Skills to Workspace
# =============================================================================

copy_skills_to_workspace() {
    local skills_src="/zeroclaw-skills"
    local skills_dest="$WORKSPACE_DIR/.zeroclaw/skills"
    
    if [ -d "$skills_src" ]; then
        mkdir -p "$skills_dest"
        cp -r "$skills_src"/* "$skills_dest/" 2>/dev/null || true
        echo "  ✓ Copied skills to workspace"
    fi
}

# =============================================================================
# Main Execution
# =============================================================================

clone_git_repos
copy_skills_to_workspace
generate_soul_md
generate_agents_md

# Gateway binds to localhost only - NOT exposed to internet
# Telegram channel works independently and doesn't need public gateway
REQUIRE_PAIRING="${ZEROCLAW_REQUIRE_PAIRING:-true}"
ALLOW_PUBLIC_BIND="${ZEROCLAW_ALLOW_PUBLIC_BIND:-false}"

# Set default allowed users if not provided (must be valid TOML array with quoted strings)
TELEGRAM_ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-[\"*\"]}"

# Autonomy level: "read_only", "supervised", or "full" (default: full for max autonomy)
AUTONOMY_LEVEL="${ZEROCLAW_AUTONOMY_LEVEL:-full}"

# Whether to restrict operations to workspace directory only
WORKSPACE_ONLY="${ZEROCLAW_WORKSPACE_ONLY:-false}"

# Whether to block high-risk commands (rm -rf, etc.)
BLOCK_HIGH_RISK="${ZEROCLAW_BLOCK_HIGH_RISK:-false}"

# Maximum tool iterations before stopping (default: 200)
MAX_TOOL_ITERATIONS="${ZEROCLAW_MAX_TOOL_ITERATIONS:-200}"

# Context compaction - set to false for large context models (e.g., glm-5 with 200k tokens)
# Default true is optimized for 13B or smaller models
COMPACT_CONTEXT="${ZEROCLAW_COMPACT_CONTEXT:-false}"

# Maximum history messages to retain (default: 50)
# Increase for large context models - glm-5 can handle 200+ messages easily
MAX_HISTORY_MESSAGES="${ZEROCLAW_MAX_HISTORY_MESSAGES:-200}"

# Build config.toml - leave values empty to let env vars take precedence via apply_env_overrides()
cat > "$ZERCLAW_DIR/config.toml" << EOF
# Provider config - env vars (ZEROCLAW_*) take precedence via apply_env_overrides()
api_key = ""
default_provider = ""
default_model = ""
default_temperature = 0.7

[memory]
backend = "sqlite"
auto_save = true

[gateway]
port = 42617
host = "127.0.0.1"
require_pairing = ${REQUIRE_PAIRING}
allow_public_bind = ${ALLOW_PUBLIC_BIND}

[agent]
max_tool_iterations = ${MAX_TOOL_ITERATIONS}
compact_context = ${COMPACT_CONTEXT}
max_history_messages = ${MAX_HISTORY_MESSAGES}

[autonomy]
level = "${AUTONOMY_LEVEL}"
workspace_only = ${WORKSPACE_ONLY}
max_actions_per_hour = 100
max_cost_per_day_cents = 1000
require_approval_for_medium_risk = false
block_high_risk_commands = ${BLOCK_HIGH_RISK}

allowed_commands = [
    "git", "gh",
    "npm", "node", "npx", "yarn", "pnpm",
    "cargo", "rustc", "rustup", "rustfmt",
    "go", "gofmt", "goimports",
    "python3", "pip3", "pip", "poetry", "black", "ruff", "pytest",
    "curl", "wget", "http", "https",
    "psql", "mysql", "redis-cli", "sqlite3",
    "aws", "vault",
    "eslint", "prettier", "jest", "vitest", "sg",
    "jq", "yq", "lnav",
    "ls", "cat", "grep", "find", "echo", "pwd", "wc", "head", "tail", "date",
    "mkdir", "mv", "cp", "touch", "rm",
    "vim", "nano",
    "htop", "ps", "kill",
    "todoist-cli",
    "google-oauth-helper",
    "obsidian-helper",
    "kokoro-tts",
    "modal"
]

forbidden_paths = []

shell_env_passthrough = [
    "GITHUB_TOKEN",
    "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL",
    "GIT_COMMITTER_NAME", 
    "GIT_COMMITTER_EMAIL",
    "GH_TOKEN",
    "MODAL_TOKEN_ID",
    "MODAL_TOKEN_SECRET",
    "KOKORO_MODEL_PATH",
    "TODOIST_API_TOKEN",
    "GMAIL_CLIENT_ID",
    "GMAIL_CLIENT_SECRET",
    "GMAIL_REFRESH_TOKEN",
    "OBSIDIAN_VAULT_PATH",
    "OPENCODE_API_KEY"
]

allowed_roots = []

auto_approve = ["file_read", "memory_recall"]

always_ask = []

non_cli_excluded_tools = []
EOF

if [ -n "$TELEGRAM_BOT_TOKEN" ]; then
cat >> "$ZERCLAW_DIR/config.toml" << EOF

[channels_config]
cli = true

[channels_config.telegram]
bot_token = "${TELEGRAM_BOT_TOKEN}"
allowed_users = ${TELEGRAM_ALLOWED_USERS}
EOF
fi

chmod 600 "$ZERCLAW_DIR/config.toml"

echo "=== ZeroClaw Ready ==="
echo "  Workspace: $WORKSPACE_DIR"
echo "  Config:    $ZERCLAW_DIR/config.toml"
echo "  SOUL.md:   $WORKSPACE_DIR/SOUL.md"
[ -f "$WORKSPACE_DIR/AGENTS.md" ] && echo "  AGENTS.md: $WORKSPACE_DIR/AGENTS.md"
echo ""

exec "$@"
