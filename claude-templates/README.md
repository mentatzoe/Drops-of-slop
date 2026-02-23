# Claude Templates

A template repository for managing Claude Code configurations across diverse project types. Uses a **hybrid base-plus-overlays** architecture — think Docker layers or Kustomize overlays.

## Quick Start

```bash
# Migrate an existing project (auto-detects overlays, preserves custom config)
./migrate.sh ~/my-project

# Or activate overlays on a clean project
./activate.sh ~/my-project web-dev quality-assurance

# Or use a pre-built composition
./activate.sh ~/my-project --composition fullstack-web

# Deactivate when done
./deactivate.sh ~/my-project
```

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

### Personas (always included)

Persona skills are loaded into every activated project and appear as switchable modes:

| Persona | Description |
|---------|-------------|
| `strict-reviewer` | Meticulous read-only code reviewer |
| `pair-programmer` | Collaborative step-by-step coding partner |
| `research-analyst` | Systematic researcher with structured findings |
| `creative-writer` | Fiction and prose writing partner |
| `architect` | System design and trade-off analysis |

### Agents (delegated execution)

Agent wrappers run personas in isolated contexts with specific tool restrictions:

| Agent | Persona | Model | Restrictions |
|-------|---------|-------|-------------|
| `strict-reviewer` | strict-reviewer | default | Read-only (no Write/Edit) |
| `research-analyst` | research-analyst | opus | Full research tools |
| `worldbuilder` | worldbuilder | opus | Full write access |

## How Activation Works

When you run `activate.sh`:

1. **Validates** overlays exist and checks for conflicts (e.g., `web-dev` conflicts with `android-dev`)
2. **Resolves dependencies** — auto-includes any overlays listed in `depends`
3. **Symlinks base rules** into `.claude/rules/` with `base--` prefix (memory files are **copied** instead — see below)
4. **Symlinks overlay rules** with `{overlay}--` prefix
5. **Symlinks persona skills** (always included regardless of overlay selection)
6. **Symlinks overlay skills, commands, and agents** into `.claude/`
7. **Deep-merges MCP configs** from all selected overlays into `.mcp.json`
8. **Deep-merges settings** from base + overlays into `.claude/settings.json`
9. **Copies hooks** (not symlinked, so they survive deactivation cleanly)
10. **Generates CLAUDE.md** from base template
11. **Records state** in `.claude/.activated-overlays.json` for clean deactivation

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

1. Create a directory under `overlays/`:

```
overlays/my-overlay/
├── overlay.json
├── rules/
│   └── my-rules.md
├── skills/
│   └── my-skill/
│       └── SKILL.md
└── mcp.json
```

2. Define `overlay.json`:

```json
{
  "name": "my-overlay",
  "description": "What this overlay does",
  "conflicts": [],
  "depends": [],
  "mcp_servers": []
}
```

3. Add path-scoped rules with YAML frontmatter:

```markdown
---
description: What these rules cover
paths:
  - "src/**/*.ts"
  - "**/*.tsx"
---

# My Rules

- Rule 1
- Rule 2
```

4. Add the overlay to `manifest.json`

5. Validate: `./scripts/validate-overlay.sh overlays/my-overlay manifest.json`

## Environment Variables

MCP servers use `${ENV_VAR}` syntax. Set these before activation:

| Variable | Used By |
|----------|---------|
| `BRAVE_API_KEY` | research overlay (Brave Search) |
| `EXA_API_KEY` | research overlay (Exa) |
| `HUGGINGFACE_TOKEN` | ai-research overlay |
| `OBSIDIAN_REST_API_KEY` | knowledge-management, worldbuilding overlays |
| `MEDIAWIKI_URL` | worldbuilding, wiki-management overlays |
| `MEDIAWIKI_BOT_USERNAME` | worldbuilding, wiki-management overlays |
| `MEDIAWIKI_BOT_PASSWORD` | worldbuilding, wiki-management overlays |
| `ANDROID_HOME` | android-dev overlay |

## Migrating Existing Projects

The `migrate.sh` script analyzes an existing project, auto-detects appropriate overlays, and migrates to the overlay architecture while preserving all custom configuration.

### Usage

```bash
# Interactive: auto-detect overlays and confirm before applying
./migrate.sh ~/existing-project

# Auto mode: accept auto-detected overlays without confirmation
./migrate.sh ~/existing-project --auto

# Manual: specify overlays explicitly
./migrate.sh ~/existing-project --overlays web-dev quality-assurance

# Composition: use a pre-built overlay combo
./migrate.sh ~/existing-project --composition fullstack-web

# Dry run: preview changes without applying
./migrate.sh ~/existing-project --dry-run

# Skip backup (e.g., when re-running after fixing issues)
./migrate.sh ~/existing-project --no-backup
```

### What it does

1. **Analyzes the project** — detects languages, frameworks, test configs, and existing Claude Code configuration
2. **Recommends overlays** — maps detected signals to overlays (e.g., `package.json` with React deps -> `web-dev`)
3. **Backs up existing config** — saves CLAUDE.md, `.claude/`, and `.mcp.json` to `.claude/.migration-backup/<timestamp>/`
4. **Preserves custom content**:
   - Custom rules are renamed with `custom--` prefix (e.g., `my-rules.md` -> `custom--my-rules.md`)
   - Custom skills and commands are left in place
   - Custom MCP servers are merged with overlay servers
   - Custom CLAUDE.md content is preserved under a `## Project-Specific` section
   - Custom hooks are renamed with `custom-` prefix if they conflict with template hooks
5. **Applies the overlay system** — same as `activate.sh` but with merge-aware logic

### Detection signals

| Signal | Overlay |
|--------|---------|
| `package.json` with React/Next/Vue/Angular/Svelte deps | `web-dev` |
| `build.gradle` with Android plugin, `AndroidManifest.xml` | `android-dev` |
| `project.godot`, Unity project structure, `.blend` files | `gamedev` |
| Python deps with torch/tensorflow/sklearn/transformers | `ai-research` |
| `.obsidian/` directory | `knowledge-management` |
| `LocalSettings.php` | `wiki-management` |
| Test dirs (`test/`, `__tests__/`), test configs (jest, pytest, vitest) | `quality-assurance` |

### Re-migration

Running `migrate.sh` on an already-migrated project is safe — it deactivates the existing setup first, then re-migrates while preserving custom content.

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/merge-configs.py` | Deep-merges MCP and settings JSON files |
| `scripts/validate-overlay.sh` | Validates overlay structure and schema |
| `scripts/detect-project.sh` | Analyzes a project and recommends overlays (JSON output) |
| `scripts/merge-claude-md.py` | Merges existing CLAUDE.md with the base template |
