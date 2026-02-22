# Prompt: Generate a Modular Claude Code Template Repository

> **Usage**: Copy this entire prompt and paste it into a Claude Code session in an empty directory.
> After generation, review the output, test the activation script, and iterate.

---

## The Prompt

You are going to help me build a **template repository** for managing Claude Code configurations across diverse project types. This is a **hybrid base-plus-overlays** architecture — think Docker layers or Kustomize overlays.

### Core Architecture

**Lightweight CLAUDE.md router** (~60–80 lines, never exceeding 150):
- Contains only universal behavioral constraints (quality standards, error handling philosophy, git workflow)
- Uses `@import` references to point to modular files for architecture and conventions
- Does NOT `@import` reference docs directly — instead, describes *when* Claude should read specific files (progressive disclosure)
- Delegates domain-specific instructions entirely to `.claude/rules/` and overlays

**Always-on base layer** (loaded every session regardless of project type):
- `base/rules/security.md` — no secrets in code, parameterized queries, deny dangerous bash patterns
- `base/rules/memory-management.md` — context hygiene, compact discipline, when to persist vs. discard
- `base/rules/code-quality.md` — error handling, test requirements, naming conventions
- `base/rules/git-workflow.md` — commit message format, branch naming, PR conventions
- `base/settings.json` — base permission deny-list (block curl/wget, protect .env and credentials, restrict sensitive paths)
- `base/hooks/` — pre-commit safety validation

**Composable overlay modules** (activated per project via `activate.sh`):
Each overlay can contribute: rules (auto-loaded, path-scoped via YAML frontmatter), skills, agents, commands, MCP server configs, and output styles.

### Directory Structure

Generate this exact structure:

```
claude-templates/
├── README.md                         # How to use this template repo
├── activate.sh                       # Symlinks base + selected overlays into target .claude/
├── deactivate.sh                     # Removes symlinks, restores clean state
├── manifest.json                     # Registry of all overlays with metadata, deps, conflicts
│
├── base/                             # ALWAYS-ON
│   ├── CLAUDE.md                     # The lightweight router (~60-80 lines)
│   ├── rules/
│   │   ├── security.md
│   │   ├── memory-management.md
│   │   ├── code-quality.md
│   │   └── git-workflow.md
│   ├── settings.json                 # Base permissions (deny-first)
│   └── hooks/
│       └── pre-commit-safety.sh      # Block commits with secrets/credentials
│
├── overlays/
│   ├── web-dev/
│   │   ├── overlay.json              # { name, description, conflicts, depends, mcp_servers }
│   │   ├── rules/
│   │   │   ├── react-patterns.md     # paths: ["src/components/**/*", "**/*.tsx", "**/*.jsx"]
│   │   │   └── api-design.md         # paths: ["src/api/**/*", "**/routes/**/*"]
│   │   ├── skills/
│   │   │   └── frontend-review/
│   │   │       └── SKILL.md          # On-demand component review skill
│   │   ├── commands/
│   │   │   └── scaffold-component.md # /scaffold-component command
│   │   └── mcp.json                  # Playwright, Context7, Filesystem
│   │
│   ├── android-dev/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   ├── kotlin-style.md       # paths: ["**/*.kt"]
│   │   │   └── compose-patterns.md   # paths: ["**/ui/**/*", "**/*Screen.kt"]
│   │   ├── skills/
│   │   │   └── android-review/
│   │   │       └── SKILL.md
│   │   └── mcp.json                  # Mobile MCP, ADB server
│   │
│   ├── gamedev/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── engine-conventions.md
│   │   ├── skills/
│   │   │   └── asset-pipeline/
│   │   │       └── SKILL.md
│   │   └── mcp.json                  # GDAI (Godot), Unity MCP, BlenderMCP
│   │
│   ├── ai-research/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── experiment-tracking.md
│   │   ├── skills/
│   │   │   └── literature-review/
│   │   │       ├── SKILL.md          # context: fork, agent: Explore
│   │   │       └── references/
│   │   │           └── review-template.md
│   │   └── mcp.json                  # HuggingFace, arXiv, Sequential Thinking
│   │
│   ├── uxr/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── research-methodology.md
│   │   ├── skills/
│   │   │   └── analysis-synthesis/
│   │   │       └── SKILL.md
│   │   └── mcp.json
│   │
│   ├── quality-assurance/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── testing-standards.md
│   │   ├── skills/
│   │   │   └── test-plan-generator/
│   │   │       └── SKILL.md
│   │   └── mcp.json
│   │
│   ├── research/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── citation-standards.md
│   │   ├── skills/
│   │   │   └── deep-research/
│   │   │       ├── SKILL.md          # context: fork, allowed-tools: Read, Grep, Glob, WebFetch
│   │   │       └── references/
│   │   │           └── research-framework.md
│   │   └── mcp.json                  # Brave Search, MCP Omnisearch, Exa
│   │
│   ├── knowledge-management/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── note-conventions.md
│   │   ├── skills/
│   │   │   └── knowledge-graph/
│   │   │       └── SKILL.md
│   │   └── mcp.json                  # Obsidian MCP (cyanheads), Memory server
│   │
│   ├── worldbuilding/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── lore-consistency.md
│   │   ├── skills/
│   │   │   └── worldbuilder/
│   │   │       ├── SKILL.md
│   │   │       └── references/
│   │   │           └── lore-template.md
│   │   └── mcp.json                  # Memory, Obsidian, MediaWiki
│   │
│   └── wiki-management/
│       ├── overlay.json
│       ├── rules/
│       │   └── wiki-style-guide.md
│       ├── skills/
│       │   └── wiki-editor/
│       │       └── SKILL.md
│       └── mcp.json                  # MediaWiki MCP
│
├── personas/                         # Skill-first personas (indexed + discoverable)
│   ├── strict-reviewer/
│   │   └── SKILL.md                  # mode: true, allowed-tools: Read, Grep, Glob
│   ├── pair-programmer/
│   │   └── SKILL.md                  # mode: true
│   ├── research-analyst/
│   │   └── SKILL.md                  # mode: true, context: fork
│   ├── creative-writer/
│   │   └── SKILL.md                  # mode: true
│   └── architect/
│       └── SKILL.md                  # mode: true
│
├── agents/                           # Agent wrappers for delegated persona work
│   ├── strict-reviewer.md            # skills: strict-reviewer; disallowedTools: Write, Edit
│   ├── research-analyst.md           # skills: research-analyst; model: opus
│   └── worldbuilder.md               # skills: worldbuilder; model: opus
│
├── compositions/                     # Pre-built overlay combos
│   ├── fullstack-web.json            # ["web-dev", "quality-assurance"]
│   ├── android-app.json              # ["android-dev", "quality-assurance"]
│   ├── creative-worldbuilding.json   # ["worldbuilding", "knowledge-management"]
│   ├── ai-project.json               # ["ai-research", "research"]
│   └── obsidian-vault.json           # ["knowledge-management", "wiki-management"]
│
└── scripts/
    ├── merge-configs.py              # Deep-merges MCP and settings JSON files
    └── validate-overlay.sh           # Checks overlay.json schema, detects conflicts
```

### Implementation Requirements

#### `activate.sh`
- Takes a target project path and one or more overlay names (or a composition name)
- Creates `.claude/` directory structure in target project if it doesn't exist
- Symlinks base rules into `.claude/rules/` with `base--` prefix (e.g., `base--security.md`)
- Symlinks overlay rules with `{overlay}--` prefix (e.g., `web-dev--react-patterns.md`)
- Symlinks persona skills into `.claude/skills/` — these are ALWAYS included regardless of overlay selection
- Symlinks selected overlay skills, commands, agents into `.claude/`
- Deep-merges MCP configs from base + selected overlays into `.mcp.json`
- Deep-merges settings from base + overlays into `.claude/settings.json`
- Copies hooks
- Generates CLAUDE.md from base template
- Records activation state in `.claude/.activated-overlays.json` for deactivation
- Validates no conflicting overlays (check overlay.json `conflicts` field)
- Resolves overlay dependencies (check overlay.json `depends` field)

#### `deactivate.sh`
- Reads `.claude/.activated-overlays.json`
- Removes all symlinks created by activation
- Removes generated `.mcp.json` and `.claude/settings.json`
- Leaves any user-created files untouched

#### `manifest.json`
```json
{
  "version": "1.0.0",
  "overlays": {
    "web-dev": {
      "description": "Web frontend development with React/Next.js",
      "conflicts": ["android-dev"],
      "depends": [],
      "mcp_servers": ["playwright", "context7", "filesystem"]
    }
  },
  "compositions": {
    "fullstack-web": {
      "overlays": ["web-dev", "quality-assurance"],
      "description": "Full-stack web development with QA integration"
    }
  }
}
```

### Skill Design Principles

For EVERY skill SKILL.md, follow these principles:

1. **Description is king** — the description field determines auto-invocation reliability. Use "USE WHEN:" patterns with concrete trigger phrases. Budget: ~100 tokens per description.
2. **Progressive disclosure** — only name + description (~100 tokens) load at startup. Full body loads on invocation. Don't worry about skill body length.
3. **Atomic scope** — each skill does ONE thing well. "frontend-review" reviews frontend code. "scaffold-component" scaffolds components. Don't combine.
4. **`mode: true` for personas** — persona skills use `mode: true` in frontmatter so they appear in a grouped "modes" section of the skills list.
5. **Context isolation for heavy work** — skills that do extensive reading/searching use `context: fork` to avoid bloating the main conversation context.
6. **Tool restrictions match the role** — `strict-reviewer` gets `allowed-tools: Read, Grep, Glob` (read-only). `scaffold-component` gets Write access. Principle of least privilege.
7. **Reference files for domain knowledge** — put templates, checklists, and style guides in `references/` subdirectories, not inline in SKILL.md.

### Persona Architecture

Personas are implemented as **skill-first with optional agent wrappers**:

- **Skill** (`.claude/skills/{persona}/SKILL.md`): Contains behavioral instructions + procedural guidance. `mode: true` makes it switchable. Indexed, discoverable, composable with other skills.
- **Agent** (`.claude/agents/{persona}.md`): Wraps the skill for delegated execution. Has its own context window, tool restrictions, and optionally a different model. Uses `skills: {persona-skill-name}` to auto-load the companion skill.
- **NOT output styles** — output styles replace the system prompt and are invisible to the skill index. Only use output styles if you genuinely need to replace Claude's core personality (rare).

Persona skills should include:
- Behavioral preamble (how to think, what to prioritize)
- Quality criteria (what "good" looks like in this mode)
- Process steps (what to do when activated)
- Anti-patterns (what NOT to do)

### Rules Design Principles

1. **Path-scope where possible** — use YAML `paths:` frontmatter so rules only load when working with relevant files
2. **Instruction budget** — Claude can follow ~150 instructions reliably; the system prompt consumes ~50. Budget ~100 across all loaded rules.
3. **Positive framing** — "Always do X" works better than "Never do Y". If you must use negatives, pair with alternatives.
4. **Linters over instructions** — don't burn instruction slots on formatting rules that a linter can enforce.
5. **Each rule file: 15-30 lines max** — focused, scannable, one concern per file.

### Security Requirements

#### `base/settings.json`
```json
{
  "permissions": {
    "deny": [
      "WebFetch",
      "Bash(curl:*)", "Bash(wget:*)",
      "Bash(rm -rf:*)",
      "Read(.env*)", "Read(~/.ssh/**)", "Read(~/.aws/**)",
      "Read(**/*secret*)", "Read(**/*credential*)"
    ],
    "ask": [
      "Bash(git push:*)",
      "Bash(docker:*)",
      "Bash(npm publish:*)"
    ],
    "allow": [
      "Read", "Grep", "Glob",
      "Bash(npm test)", "Bash(npm run lint)",
      "Bash(git status)", "Bash(git diff:*)", "Bash(git log:*)"
    ]
  }
}
```

#### MCP Server Security
- All MCP configs use `${ENV_VAR}` for secrets, NEVER hardcoded values
- Include a comment in each `mcp.json` listing required environment variables
- Remote MCP servers use HTTPS only
- Add server-specific permission scoping via `mcp__servername__*` patterns in settings

#### Hooks
- `pre-commit-safety.sh`: scan staged files for API keys, tokens, passwords. Exit code 2 blocks the commit unconditionally.
- Use hooks for **deterministic enforcement** — CLAUDE.md is behavioral guidance (probabilistic); hooks are guaranteed execution.

### MCP Server Configurations

Use these specific servers in the overlay `mcp.json` files:

| Overlay | MCP Servers |
|---------|-------------|
| web-dev | `@playwright/mcp`, `context7-mcp`, `@modelcontextprotocol/server-filesystem` |
| android-dev | `@mobilenext/mobile-mcp@latest`, `minhalvp/android-mcp-server` |
| gamedev | `gdaimcp.com` (Godot), `@nurture-tech/unity-mcp-runner`, `ahujasid/blender-mcp` |
| ai-research | HuggingFace MCP, arXiv MCP, `@modelcontextprotocol/server-sequential-thinking` |
| research | `@modelcontextprotocol/server-brave-search`, Exa MCP |
| knowledge-management | Obsidian MCP (cyanheads, via Local REST API), `@modelcontextprotocol/server-memory` |
| worldbuilding | `@modelcontextprotocol/server-memory`, Obsidian MCP, `@professional-wiki/mediawiki-mcp-server@latest` |
| wiki-management | `@professional-wiki/mediawiki-mcp-server@latest` |

Format each `mcp.json` as:
```json
{
  "_comment": "Required env vars: GITHUB_TOKEN, BRAVE_API_KEY",
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "package-name"],
      "env": { "API_KEY": "${API_KEY}" }
    }
  }
}
```

### What to Write in Each File

Every file should contain **real, useful content** — not placeholders or TODOs. For example:

- `security.md` should contain actual security rules (no hardcoded secrets, input validation, parameterized queries, etc.)
- `strict-reviewer/SKILL.md` should contain a complete reviewer persona with behavioral instructions, quality criteria, and review process steps
- `worldbuilder/SKILL.md` should contain worldbuilding methodology, consistency checks, and lore management procedures
- `lore-consistency.md` should contain rules for maintaining narrative consistency across documents

### Generation Instructions

1. Generate ALL files with complete, production-ready content
2. Make `activate.sh` and `deactivate.sh` executable bash scripts that actually work
3. Use real MCP server package names and configurations
4. Write meaningful skill descriptions optimized for auto-invocation (use "USE WHEN:" patterns)
5. Path-scope all overlay rules with appropriate YAML `paths:` frontmatter
6. Keep base CLAUDE.md under 80 lines
7. Keep each rule file under 30 lines
8. Include the `mode: true` frontmatter on all persona skills
9. Test that the directory structure is self-consistent (no broken references)

Start by generating the directory structure and all files. Work through it systematically — base layer first, then overlays, then personas, then agents, then scripts.
