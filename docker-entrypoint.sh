#!/bin/sh
set -e

export HOME=/zeroclaw-data
WORKSPACE_DIR="/zeroclaw-data/.zeroclaw/workspace"
ZERCLAW_DIR="/zeroclaw-data/.zeroclaw"

mkdir -p "$ZERCLAW_DIR"
mkdir -p "$WORKSPACE_DIR"

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
    
    # Rust
    if [ -f "$repo_dir/Cargo.toml" ]; then
        stack="$stack- **Rust**: "
        stack="$stack$(grep -E "^name|^version" "$repo_dir/Cargo.toml" 2>/dev/null | tr '\n' ' ' | head -c 100)"
        stack="$stack\n"
    fi
    
    # Node.js/TypeScript
    if [ -f "$repo_dir/package.json" ]; then
        stack="$stack- **Node.js/TypeScript**: "
        stack="$stack$(grep -E '"name"|"version"' "$repo_dir/package.json" 2>/dev/null | tr '\n' ' ' | head -c 100)"
        stack="$stack\n"
    fi
    
    # Python
    if [ -f "$repo_dir/pyproject.toml" ] || [ -f "$repo_dir/requirements.txt" ] || [ -f "$repo_dir/setup.py" ]; then
        stack="$stack- **Python** project detected\n"
    fi
    
    # Go
    if [ -f "$repo_dir/go.mod" ]; then
        stack="$stack- **Go**: "
        stack="$stack$(head -5 "$repo_dir/go.mod" 2>/dev/null | tr '\n' ' ')"
        stack="$stack\n"
    fi
    
    # Docker
    if [ -f "$repo_dir/Dockerfile" ] || [ -f "$repo_dir/docker-compose.yml" ]; then
        stack="$stack- **Docker** containerization\n"
    fi
    
    # Database
    if [ -f "$repo_dir/sql/" ] || ls "$repo_dir"/*.sql 1>/dev/null 2>&1; then
        stack="$stack- **SQL/Database** schemas present\n"
    fi
    
    printf "%s" "$stack"
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
                
                # Structure analysis
                analyze_repo_structure "$repo_dir" >> "$soul_file"
                
                # README summary
                get_repo_readme_summary "$repo_dir" >> "$soul_file"
            fi
        done
        IFS="$OLD_IFS"
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
*This file is regenerated on container restart.*
AGENT_ROLES

    echo "  ✓ Generated AGENTS.md"
}

# =============================================================================
# Main Execution
# =============================================================================

clone_git_repos
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
    "htop", "ps", "kill"
]

forbidden_paths = []

shell_env_passthrough = [
    "GITHUB_TOKEN",
    "GIT_AUTHOR_NAME",
    "GIT_AUTHOR_EMAIL",
    "GIT_COMMITTER_NAME", 
    "GIT_COMMITTER_EMAIL",
    "GH_TOKEN"
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
