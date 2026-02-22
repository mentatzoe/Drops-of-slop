# Claude Templates

A template repository for managing Claude Code configurations across diverse project types. Uses a **hybrid base-plus-overlays** architecture — think Docker layers or Kustomize overlays.

## Quick Start

```bash
# Activate overlays in your project
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
| `base/CLAUDE.md` | Lightweight router (~60 lines) with quality standards and behavioral constraints |
| `base/rules/security.md` | No hardcoded secrets, parameterized queries, input validation |
| `base/rules/memory-management.md` | Context hygiene, when to persist vs. discard |
| `base/rules/code-quality.md` | Error handling, testing, naming conventions |
| `base/rules/git-workflow.md` | Commit format, branch naming, PR conventions |
| `base/settings.json` | Permission deny-list (blocks curl/wget, protects .env and credentials) |
| `base/hooks/pre-commit-safety.sh` | Scans staged files for secrets before commit |

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
3. **Symlinks base rules** into `.claude/rules/` with `base--` prefix
4. **Symlinks overlay rules** with `{overlay}--` prefix
5. **Symlinks persona skills** (always included regardless of overlay selection)
6. **Symlinks overlay skills, commands, and agents** into `.claude/`
7. **Deep-merges MCP configs** from all selected overlays into `.mcp.json`
8. **Deep-merges settings** from base + overlays into `.claude/settings.json`
9. **Copies hooks** (not symlinked, so they survive deactivation cleanly)
10. **Generates CLAUDE.md** from base template
11. **Records state** in `.claude/.activated-overlays.json` for clean deactivation

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

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/merge-configs.py` | Deep-merges MCP and settings JSON files |
| `scripts/validate-overlay.sh` | Validates overlay structure and schema |
