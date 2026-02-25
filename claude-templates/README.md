# Claude Templates

A template repository for managing Claude Code configurations across diverse project types. Uses a **hybrid base-plus-overlays** architecture — think Docker layers or Kustomize overlays.

## Why?

Manually maintaining `.claude/` configuration across projects is tedious and inconsistent — every new project starts from scratch, rules drift between repos, and onboarding a teammate means copy-pasting config files. Claude Templates solves this with shared base standards plus domain-specific overlays that activate with one command. New project setup takes seconds, and when you improve a rule or fix a hook, every project picks up the change on the next refresh.

## Quick Start

```bash
# Install
curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/claude-templates/install.sh | bash

# Activate overlays on a project
~/.claude-templates/activate.sh ~/my-project web-dev quality-assurance

# Or use a pre-built composition
~/.claude-templates/activate.sh ~/my-project --composition fullstack-web

# Migrate an existing project
~/.claude-templates/migrate.sh ~/my-project

# Deactivate
~/.claude-templates/deactivate.sh ~/my-project

# Refresh projects after updating templates
~/.claude-templates/refresh.sh ~/my-project
```

## What You Get

After activation, your project has a fully configured `.claude/` directory:

```
my-project/
├── .claude/
│   ├── rules/
│   │   ├── base--security.md          ← symlink (shared standards)
│   │   ├── base--code-quality.md      ← symlink
│   │   ├── base--git-workflow.md      ← symlink
│   │   ├── base--memory-profile.md    ← copy (per-project, editable)
│   │   ├── base--memory-preferences.md
│   │   ├── base--memory-decisions.md
│   │   ├── base--memory-sessions.md
│   │   ├── webdev--frontend.md        ← symlink (overlay rules)
│   │   └── webdev--api-design.md      ← symlink
│   ├── skills/                        ← symlinks (personas + overlay skills)
│   ├── commands/                      ← symlinks (overlay commands)
│   ├── agents/                        ← symlinks (agent wrappers)
│   ├── hooks/
│   │   ├── pre-commit-safety.sh       ← copy (editable)
│   │   └── stop-learning-capture.sh   ← copy (editable)
│   ├── settings.json                  ← generated (merged from base + overlays)
│   └── .activated-overlays.json       ← generated (state for refresh/deactivate)
├── .mcp.json                          ← generated (merged MCP configs)
└── CLAUDE.md                          ← generated (from base template)
```

### What to commit

- **Commit**: `CLAUDE.md`, `.claude/settings.json`, `.mcp.json`, `.claude/.activated-overlays.json`, memory files (`base--memory-*.md`)
- **Optional**: Symlinked rules/skills — no harm either way since `refresh.sh` recreates them
- **Don't commit**: `node_modules/`, `.env`, or anything in your existing `.gitignore`

## Architecture

### Base Layer (always loaded)

The base layer provides universal standards that apply to every project:

| File | Purpose |
|------|---------|
| `base/CLAUDE.md` | Lightweight router (~75 lines) with quality standards, behavioral constraints, and memory auto-update rules |
| `base/rules/security.md` | No hardcoded secrets, parameterized queries, input validation |
| `base/rules/memory-management.md` | Context hygiene, when to persist vs. discard, memory file index |
| `base/rules/memory-profile.md` | Persistent facts about the user and project (editable) |
| `base/rules/memory-preferences.md` | User preferences for code style, communication, workflow (editable) |
| `base/rules/memory-decisions.md` | Dated decision log for consistency across sessions (editable) |
| `base/rules/memory-sessions.md` | Rolling summary of last 10 work sessions (editable) |
| `base/rules/code-quality.md` | Error handling, testing, naming conventions |
| `base/rules/git-workflow.md` | Commit format, branch naming, PR conventions |
| `base/settings.json` | Permission deny-list (blocks curl/wget, protects .env and credentials) + Stop hook |
| `base/hooks/pre-commit-safety.sh` | Scans staged files for secrets before commit |
| `base/hooks/stop-learning-capture.sh` | Nudges Claude to capture learnings when a session involves discoveries or fixes |

### Overlays (activated per project)

Each overlay adds domain-specific rules, skills, commands, and MCP server configurations:

| Overlay | Description | MCP Servers |
|---------|-------------|-------------|
| `web-dev` | React/Next.js frontend + API design | Playwright, Context7, Filesystem |
| `android-dev` | Kotlin/Compose + Material Design 3 | Mobile MCP, Android MCP |
| `gamedev` | Godot/Unity/Blender game development | GDAI, Unity MCP, Blender MCP |
| `ai-research` | ML experiment tracking + paper analysis | HuggingFace, arXiv, Sequential Thinking |
| `uxr` | UX research methodology + synthesis | — |
| `quality-assurance` | Testing standards + test plan generation | — |
| `research` | Web search + citation management | Brave Search, Exa |
| `knowledge-management` | Obsidian vault + note linking | Obsidian MCP, Memory |
| `worldbuilding` | Lore consistency + narrative design | Memory, Obsidian, MediaWiki |
| `wiki-management` | MediaWiki article editing + style | MediaWiki MCP |

### Compositions (pre-built combos)

| Composition | Overlays |
|-------------|----------|
| `fullstack-web` | web-dev + quality-assurance |
| `android-app` | android-dev + quality-assurance |
| `creative-worldbuilding` | worldbuilding + knowledge-management |
| `ai-project` | ai-research + research |
| `obsidian-vault` | knowledge-management + wiki-management |

To create your own composition, see [Create a Custom Composition](GUIDE.md#create-a-custom-composition) in the Usage Guide.

### Personas (always included)

Personas are switchable behavior modes invoked as skills (e.g., `/architect`, `/strict-reviewer`). They change how Claude approaches a task — tone, methodology, what it focuses on — but don't restrict tool access. Every persona is available in every activated project regardless of which overlays you chose.

| Persona | Description |
|---------|-------------|
| `strict-reviewer` | Meticulous read-only code reviewer |
| `pair-programmer` | Collaborative step-by-step coding partner |
| `research-analyst` | Systematic researcher with structured findings |
| `creative-writer` | Fiction and prose writing partner |
| `architect` | System design and trade-off analysis |

### Agents (delegated execution)

Agents are delegated execution contexts that wrap a persona with specific tool restrictions. Invoke them with `@agent <name>` (e.g., `@strict-reviewer`). Unlike personas, agents run in isolation — they can't modify files they shouldn't touch.

| Agent | Persona | Model | Restrictions |
|-------|---------|-------|-------------|
| `strict-reviewer` | strict-reviewer | default | Read-only (no Write/Edit) |
| `research-analyst` | research-analyst | opus | Full research tools |
| `worldbuilder` | worldbuilder | opus | Full write access |

## How Activation Works

`activate.sh` validates overlays and checks for conflicts → symlinks rules, skills, commands, and agents while merging MCP and settings configs → records state for clean deactivation. Memory files and hooks are **copied** (not symlinked) so each project can customize them independently. See [Set Up a New Project](GUIDE.md#set-up-a-new-project) in the Usage Guide for the full walkthrough.

### Memory System

The template includes a modular memory system that persists knowledge across sessions using four dedicated files in `.claude/rules/`:

| File | Updated when... |
|------|-----------------|
| `memory-profile.md` | User shares facts about themselves, their environment, or the project |
| `memory-preferences.md` | User states a preference for how work should be done |
| `memory-decisions.md` | A decision is made (logged with date and rationale) |
| `memory-sessions.md` | Substantive work is completed (rolling log, last 10 sessions) |

**How it works:**

- **CLAUDE.md** contains a mandatory auto-update instruction that tells Claude to update memory files *as it goes*, not at the end of a session
- **Stop hook** (`stop-learning-capture.sh`) pattern-matches conversation context when a session ends — if it detects discoveries, fixes, or workarounds, it nudges Claude to capture learnings
- **Memory files are copied** (not symlinked) during activation, so each project maintains its own memory. Re-running `activate.sh` preserves existing memory data

This is a "belt and suspenders" approach: the CLAUDE.md instruction handles ~90% of memory capture, and the Stop hook catches sessions where it was forgotten.

## Creating Custom Overlays

Create a directory under `overlays/` with an `overlay.json` and at least one rule file, register it in `manifest.json`, and validate with `validate-overlay.sh`. See [Create a Custom Overlay](GUIDE.md#create-a-custom-overlay) in the Usage Guide for the full walkthrough.

## Environment Variables

Some overlays require environment variables for MCP server access (e.g., `BRAVE_API_KEY` for the research overlay). See the [Environment Variables](GUIDE.md#environment-variables) table in the Usage Guide for the full list.

## Migrating Existing Projects

Already have `CLAUDE.md`, `.claude/`, or `.mcp.json`? The `migrate.sh` script auto-detects your frameworks, recommends overlays, backs up your existing config, and preserves all custom rules, skills, and MCP servers. Your work is safe — custom content gets a `custom--` prefix and keeps loading. See [Migrate an Existing Project](GUIDE.md#migrate-an-existing-project) in the Usage Guide for full details.

## Scripts

### Lifecycle scripts

User-facing scripts at the top level:

| Script | Purpose |
|--------|---------|
| `install.sh` | Install or update the template system |
| `activate.sh` | Set up overlays on a new project |
| `migrate.sh` | Adopt overlays on a project with existing config |
| `deactivate.sh` | Remove all template files from a project |
| `refresh.sh` | Re-link and re-merge after a template update |

### Helper scripts

Internal scripts under `scripts/`:

| Script | Purpose |
|--------|---------|
| `scripts/merge-configs.py` | Deep-merges MCP and settings JSON files |
| `scripts/validate-overlay.sh` | Validates overlay structure and schema |
| `scripts/detect-project.sh` | Analyzes a project and recommends overlays (JSON output) |
| `scripts/merge-claude-md.py` | Merges existing CLAUDE.md with the base template |
