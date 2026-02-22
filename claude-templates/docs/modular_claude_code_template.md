# Building a modular Claude Code template repository

**A hybrid base-plus-overlays architecture, powered by Claude Code's native `.claude/rules/` directory, `@import` syntax, and composable skills, provides the most robust foundation for a reusable, multi-use-case template system.** This approach mirrors proven patterns from Kustomize, GNU Stow, and Docker layers while aligning directly with Claude Code's file resolution mechanics. The core insight: Claude Code already supports modular composition natively — the template repository's job is to organize and activate these native features systematically across diverse project types.

This report synthesizes official Anthropic documentation, production configurations from teams processing billions of tokens monthly, community-tested patterns from 30+ open-source repositories, and security guidance from firms like Trail of Bits.

---

## CLAUDE.md works best as a lean router, not a manual

Claude Code loads CLAUDE.md files automatically into context at launch. The system reads from **four memory locations** in strict precedence: enterprise policy (system-level), project memory (`./CLAUDE.md`), user memory (`~/.claude/CLAUDE.md`), and local overrides (`./CLAUDE.local.md`). Files higher in the hierarchy load first and take priority.

The critical architectural mechanism is the **`@import` syntax**. CLAUDE.md files can reference external files with `@path/to/file.md`, supporting both relative and absolute paths, with recursive imports up to **5 hops deep**. Imports inside markdown code blocks are ignored. This makes the router pattern straightforward: a lean CLAUDE.md (~60-80 lines, well under the 150-line target) contains universal behavioral constraints and `@import` references to modular rule files.

```markdown
# CLAUDE.md — Operational Core
## Quality Standards
- Correctness > Maintainability > Performance
- Run tests before committing

## Architecture
See @docs/architecture.md for system overview
See @docs/api-patterns.md for API conventions

## Domain Rules
@.claude/rules/  # All .md files here auto-load
```

The **`.claude/rules/` directory** (available since v2.0.64) is the primary composition mechanism. All markdown files placed here load automatically with the same priority as CLAUDE.md itself. Rules support **path-specific targeting** via YAML frontmatter — a file with `paths: ["src/api/**/*.ts"]` only loads when Claude works with matching files. This is the foundation of the overlay system: different overlays contribute different rule files to this directory.

Practitioners report that frontier models can follow roughly **150–200 instructions**, and Claude Code's built-in system prompt already consumes about 50 of those slots. HumanLayer keeps their production CLAUDE.md under 60 lines. The team at Shrivu Shankar's company (billions of tokens/month for codegen) maintains a 13KB CLAUDE.md but strictly limits it to tools used by 30%+ of engineers. The empirical consensus: keep project CLAUDE.md lean and let the rules directory carry domain-specific weight.

One notable reliability concern: an open GitHub issue (#3529) reports that subfolder CLAUDE.md files may not always be respected in practice. The `@import` and `.claude/rules/` mechanisms are more reliable than nested directory CLAUDE.md files for modular configuration.

---

## Persistent memory spans sessions through multiple mechanisms

Claude Code provides three memory persistence layers. **Auto memory** stores Claude's own learnings at `~/.claude/projects/<project>/memory/`, including a `MEMORY.md` index file (first 200 lines loaded per session), plus topic-specific files like `debugging.md` or `api-conventions.md`. The project path derives from the git repository root, so all subdirectories share one memory directory. Git worktrees get separate memory directories.

For **in-repo persistent memory** (implementation-agnostic across CLI and IDE), the recommended pattern uses the rules directory and imported reference files rather than auto memory alone. Store architectural decisions, coding conventions, and domain knowledge as markdown files that Claude reads on demand:

```
docs/
├── architecture.md      # System design, module relationships
├── decisions/           # ADR-style decision records
│   ├── 001-auth-flow.md
│   └── 002-db-choice.md
└── conventions/
    ├── api-patterns.md
    └── testing-guide.md
```

Reference these from CLAUDE.md with descriptive "when to read" hints rather than `@`-importing them (which would embed them into context every session). The progressive disclosure pattern — brief descriptions in CLAUDE.md pointing to separate files — keeps context lean while making knowledge available.

Users can add quick memories with the `#` shortcut (CLI only) or by telling Claude to "remember that we use pnpm." The `/memory` command opens a file selector for extensive edits. Both CLI and VS Code extension read the same filesystem-based memory files, making these patterns implementation-agnostic.

---

## Security requires layered defense: settings, hooks, and sandboxing

Claude Code's security model uses a **deny → ask → allow** evaluation order where the first matching rule wins and deny rules always take precedence. The permission system in `settings.json` supports granular control:

```json
{
  "permissions": {
    "allow": ["Bash(npm test)", "Bash(npm run lint)", "Read"],
    "ask": ["Bash(git push:*)", "Bash(docker run:*)"],
    "deny": [
      "WebFetch", "Bash(curl:*)", "Bash(wget:*)",
      "Read(.env*)", "Read(~/.ssh/**)", "Read(~/.aws/**)"
    ]
  }
}
```

**Settings files follow a strict precedence hierarchy**: managed policies (system-level, cannot be overridden) → command-line arguments → `.claude/settings.local.json` (personal, gitignored) → `.claude/settings.json` (team-shared) → `~/.claude/settings.json` (user global). The official JSON schema is at `https://json.schemastore.org/claude-code-settings.json`.

**Sandboxing** reduces permission prompts by **84%** in Anthropic's internal usage while creating OS-level isolation. On macOS it uses the Seatbelt framework; on Linux, bubblewrap plus socat. Enable it via `/sandbox` or in settings:

```json
{
  "sandbox": {
    "enabled": true,
    "autoAllowBashIfSandboxed": true,
    "allowUnsandboxedCommands": false,
    "network": {
      "allowedDomains": ["github.com", "*.npmjs.org"]
    }
  }
}
```

Setting `"allowUnsandboxedCommands": false` is critical — it closes the `dangerouslyDisableSandbox` escape hatch. Network filtering restricts domains but does not inspect traffic content, so domain fronting attacks remain a theoretical risk.

**Hooks provide deterministic enforcement** that CLAUDE.md instructions cannot. CLAUDE.md is behavioral guidance that Claude follows as best practice but can be influenced by context; hooks are guaranteed execution with exit code 2 blocking operations unconditionally. A `PreToolUse` hook can block access to sensitive files regardless of what the prompt says:

```json
{
  "hooks": {
    "PreToolUse": [{
      "matcher": "Write|Edit|MultiEdit",
      "hooks": [{
        "type": "command",
        "command": "python3 -c \"import json,sys; data=json.load(sys.stdin); path=data.get('tool_input',{}).get('file_path',''); sys.exit(2 if any(p in path for p in ['.env','credentials','secret']) else 0)\""
      }]
    }]
  }
}
```

For MCP server security, authentication is optional in the MCP spec and must be implemented by developers. Claude Code permissions can scope MCP tools with patterns like `mcp__servername__*`. For remote servers, OAuth 2.1 with PKCE is the standard, and all authorization endpoints must be served over HTTPS. The critical enterprise controls are `allowedMcpServers` and `deniedMcpServers` in managed settings, plus never setting `"enableAllProjectMcpServers": true` in production.

API keys should be stored in encrypted keystores (macOS Keychain is used automatically) or retrieved via the `apiKeyHelper` setting, which runs a shell script to generate credentials on demand. Never include secrets in CLAUDE.md, settings files, or `.mcp.json`.

---

## Skills and output styles replace traditional persona systems

Claude Code's persona system operates through **output styles**, which completely replace the system prompt while preserving all tool capabilities. Custom styles are markdown files with frontmatter stored in `~/.claude/output-styles/` (personal) or `.claude/output-styles/` (project):

```yaml
---
name: architect-mode
description: Senior software architect focusing on system design
keep-coding-instructions: true
---
You are a senior software architect. Focus on:
- System design trade-offs and scalability
- Architecture decision records
- Design pattern selection with rationale
```

Switch with `/output-style architect-mode`. The `keep-coding-instructions: true` flag retains coding behavior while changing personality.

**Skills** (the evolution of slash commands) live in `.claude/skills/<name>/SKILL.md` with YAML frontmatter. They support progressive disclosure: only name and description (~100 tokens) load at startup, with full instructions loading on invocation. The context budget for skill descriptions is **2% of the context window**. Skills can restrict tools with `allowed-tools`, fork into subagent contexts with `context: fork`, and bundle scripts and templates in subdirectories:

```yaml
---
name: deep-research
description: Thoroughly researches a topic using web search and file analysis
argument-hint: [topic]
context: fork
agent: Explore
allowed-tools: Read, Grep, Glob, WebFetch
---
Research $ARGUMENTS thoroughly:
1. Search for authoritative sources
2. Cross-reference findings
3. Compile a structured summary with citations
```

Legacy `.claude/commands/*.md` files still work and create `/command-name` interfaces. The `$ARGUMENTS` placeholder captures user input after the command name. Subdirectory namespacing creates colon-separated commands: `.claude/commands/frontend/component.md` becomes `/frontend:component`.

**Custom subagents** defined in `.claude/agents/` extend the built-in Explore, Plan, and general-purpose agents. They support model selection (`sonnet`, `opus`, `haiku`), tool restrictions, and worktree isolation. One important constraint: subagents cannot spawn other subagents, preventing infinite nesting.

---

## MCP servers compose through layered configuration scopes

MCP server configuration follows the same layering pattern as settings. **Project-scoped servers** go in `.mcp.json` at the project root (version-controlled, team-shared). **User-scoped servers** go in `~/.claude.json`. **Local-scoped servers** are stored per-project path in `~/.claude.json`. Precedence: local > project > user.

The configuration format supports stdio (local processes), HTTP (recommended for remote), and SSE (deprecated) transports. Environment variable expansion with `${VAR}` and `${VAR:-default}` syntax works in command, args, env, url, and headers fields:

```json
{
  "mcpServers": {
    "github": {
      "type": "http",
      "url": "https://api.githubcopilot.com/mcp/",
      "headers": { "Authorization": "Bearer ${GITHUB_TOKEN}" }
    },
    "playwright": {
      "command": "npx",
      "args": ["-y", "@playwright/mcp"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "context7-mcp"]
    }
  }
}
```

For the user's specific use cases, the most relevant MCP servers are:

**Web development**: Playwright (`@playwright/mcp` — Microsoft's official browser automation), Context7 (up-to-date docs for 9,000+ libraries), Filesystem (`@modelcontextprotocol/server-filesystem`), and Fetch (`@modelcontextprotocol/server-fetch`).

**Android development**: Mobile MCP (`@mobilenext/mobile-mcp@latest` for cross-platform automation), Android MCP Server (ADB control via `minhalvp/android-mcp-server`), and Expo MCP (`https://mcp.expo.dev/sse` for React Native).

**Videogame development**: GDAI MCP (`gdaimcp.com` — the most feature-rich Godot server), Unity MCP (`@nurture-tech/unity-mcp-runner` with 31 tools), BlenderMCP (`ahujasid/blender-mcp` with 37 tools for 3D modeling), and GameDev MCP Hub (aggregates 165+ tools across engines).

**AI research**: Hugging Face MCP (900K+ models, 200K+ datasets), arXiv MCP (scholarly article search), Sequential Thinking (`@modelcontextprotocol/server-sequential-thinking`), and MCP Pandas (containerized data analysis).

**Personal knowledge management and Obsidian**: The cyanheads Obsidian MCP server (full vault management via Local REST API plugin) is the most fully featured. The Memory server (`@modelcontextprotocol/server-memory`) provides knowledge-graph-based persistence. For wiki management, the Professional Wiki MediaWiki MCP (`@professional-wiki/mediawiki-mcp-server@latest`) supports full CRUD with OAuth 2.0.

**Broad research**: Brave Search (`@modelcontextprotocol/server-brave-search`), MCP Omnisearch (aggregates Tavily, Brave, Kagi, Perplexity), and Exa (semantic web search).

Key MCP registries for discovery include Smithery (smithery.ai — hosting plus CLI), MCP.so (17,786+ servers cataloged), Glama.ai (daily updates, API access), and the official GitHub registry at `modelcontextprotocol/registry`. The `wong2/awesome-mcp-servers` and `punkpeye/awesome-mcp-servers` GitHub repos are the most curated community lists.

---

## The recommended directory structure maps overlays to native Claude Code features

The hybrid architecture uses a template repository with a base layer and composable overlay modules. Activation scripts create symlinks into the target project's `.claude/` directory, leveraging Claude Code's native file resolution:

```
claude-templates/
├── activate.sh                     # Symlinks base + overlays into target project
├── manifest.json                   # Registry of all overlays with metadata
│
├── base/                           # ALWAYS-ON — loaded every session
│   ├── CLAUDE.md                   # Core router (~60 lines)
│   ├── rules/
│   │   ├── security.md             # No secrets, parameterized queries
│   │   ├── memory-management.md    # Context hygiene, compact discipline
│   │   ├── code-quality.md         # Error handling, test requirements
│   │   └── git-workflow.md         # Commit conventions, branch rules
│   ├── settings.json               # Base permissions (deny dangerous ops)
│   └── hooks/
│       └── validate-command.sh     # Pre-commit safety hook
│
├── overlays/                       # COMPOSABLE — activated per project
│   ├── web-dev/
│   │   ├── overlay.json            # Metadata, deps, conflicts
│   │   ├── CLAUDE.md               # Web-specific instructions
│   │   ├── rules/
│   │   │   ├── react-patterns.md   # paths: src/components/**/*
│   │   │   └── api-design.md       # paths: src/api/**/*.ts
│   │   ├── skills/
│   │   │   └── frontend-review/
│   │   │       └── SKILL.md
│   │   ├── commands/
│   │   │   └── scaffold-component.md
│   │   └── mcp.json                # Playwright, Context7, etc.
│   │
│   ├── android-dev/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   ├── kotlin-style.md
│   │   │   └── compose-patterns.md
│   │   ├── skills/
│   │   │   └── android-review/SKILL.md
│   │   └── mcp.json                # Mobile MCP, ADB server
│   │
│   ├── gamedev/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── engine-conventions.md
│   │   └── mcp.json                # GDAI, Unity, BlenderMCP
│   │
│   ├── ai-research/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── experiment-tracking.md
│   │   └── mcp.json                # HuggingFace, arXiv, Pandas
│   │
│   ├── worldbuilding/
│   │   ├── overlay.json
│   │   ├── rules/
│   │   │   └── lore-consistency.md
│   │   └── mcp.json                # Memory, Obsidian, MediaWiki
│   │
│   └── personas/
│       ├── strict-reviewer/
│       │   └── output-style.md
│       └── pair-programmer/
│           └── output-style.md
│
├── compositions/                   # Pre-built overlay combos
│   ├── fullstack-react.json        # ["web-dev", "devops"]
│   └── creative-worldbuilding.json # ["worldbuilding", "personas/pair-programmer"]
│
└── scripts/
    ├── activate.sh
    ├── deactivate.sh
    └── merge-configs.py            # JSON-merges MCP and settings
```

The activation script symlinks rule files into `.claude/rules/` with overlay-prefixed names (e.g., `web-dev--react-patterns.md`) to prevent collisions, generates a CLAUDE.md with `@import` references to overlay files, and deep-merges MCP configurations from base and selected overlays. Symlinks are optimal because Claude Code's rules directory transparently resolves them, path-specific YAML frontmatter works correctly through symlinks, and changes to the source are reflected immediately without re-running activation.

The `overlay.json` metadata file enables tooling for conflict detection and dependency resolution:

```json
{
  "name": "web-dev",
  "description": "Web frontend development with React/Next.js",
  "conflicts": ["android-dev"],
  "depends": [],
  "mcp_servers": ["playwright", "context7", "filesystem"]
}
```

This pattern draws directly from Kustomize's base-plus-overlays model, GNU Stow's symlink farm management, and Docker's additive layer system.

---

## CLI and VS Code extension share configs but diverge on features

The VS Code extension reads the same `settings.json` files, CLAUDE.md hierarchy, `.claude/rules/`, `.mcp.json`, and hooks as the CLI. Authentication, models, permissions, and memory are shared. However, several features remain **CLI-only**: MCP server configuration UI (must configure via CLI first, then extension uses them), the `#` shortcut for quick memory, `!` for direct bash commands, conversation rewinding, checkpoints, and tab completion.

The VS Code extension offers unique features: native sidebar UI, plan mode with editable plans, auto-accept edits mode, inline diffs, and `@-mention` files with specific line ranges.

**The key compatibility gotcha** is MCP tool approval — an open issue (#10801) where VS Code may not respect `bypassPermissions` configuration that works in the CLI. Also, pseudo-TTY limitations mean interactive prompts (checklists, selection UIs) may not render correctly in VS Code's integrated terminal.

For implementation-agnostic design, all configuration should live in filesystem-based `settings.json` files, MCP servers should be configured via CLI first (then they work in both environments), and workflows should avoid relying on CLI-only shortcuts. The `env` key in `~/.claude/settings.json` is the recommended place for provider configuration shared between environments.

---

## Orchestration patterns scale from single-agent to parallel pipelines

**Headless mode** (`claude -p`) runs non-interactively for CI/CD integration. Key flags include `--output-format` (text, json, stream-json), `--max-turns` (prevent runaway), `--allowedTools` (permission scoping), and `--permission-mode` (plan, default, bypassPermissions). Trust verification is disabled in `-p` mode — only use with trusted codebases.

The official GitHub Action (`anthropics/claude-code-action@v1`) enables `@claude` mentions in PRs and issues, automated code review, and security review. A minimal workflow:

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
    claude_args: "--max-turns 10"
```

**Git worktrees** are what Boris Cherny (Claude Code creator) calls the "#1 productivity unlock." Claude Code has native support via `claude --worktree feature-auth`, which creates `.claude/worktrees/feature-auth/` with a new branch. Multiple sessions run simultaneously in separate terminals. Subagents can use worktree isolation with `isolation: worktree` in their agent definition, ensuring messy experimental work stays isolated from the main context.

The hook system supports **10 lifecycle events**: PreToolUse, PostToolUse, PostToolUseFailure, Notification, UserPromptSubmit, SessionStart, SessionEnd, Stop, SubagentStart, SubagentStop, and PreCompact. The most impactful patterns are block-at-submit hooks (e.g., requiring tests to pass before `git commit`) and notification hooks (alerting when Claude needs input). Practitioners recommend avoiding block-at-write hooks because they confuse the agent mid-plan.

For multi-agent orchestration, the expert consensus favors a "master-clone" architecture over "lead-specialist" — rather than specialized subagents with restricted context, spawn general-purpose agents that can access the full codebase. Claude Opus 4.6 has "a strong predilection for subagents" and may overuse them, so include guidance about when delegation is and isn't warranted.

---

## Community patterns reveal what works at scale

The most valuable open-source references are **ChrisWiles/claude-code-showcase** (3,800+ stars — the most complete production example with hooks, skills, agents, and CI workflows), **serpro69/claude-starter-kit** (a GitHub template repo with 4 MCP servers, 47 Task Master commands, and template sync infrastructure), and **abhishekray07/claude-md-templates** (focused on CLAUDE.md philosophy with the insight that instruction-following quality degrades uniformly as instruction count increases).

The strongest practitioner patterns converge on several themes. Keep CLAUDE.md as a "living constitution" — start minimal, add rules when Claude makes mistakes ("every mistake becomes a rule"), and regularly prune when it exceeds 80 lines. Use progressive disclosure: brief descriptions in CLAUDE.md pointing to separate files rather than `@`-importing everything into context. Prefer linters and formatters for style rules rather than burning CLAUDE.md instruction slots. Let Claude write some of its own memory over time, making CLAUDE.md a co-evolved document.

The community has also identified clear anti-patterns: never auto-generate CLAUDE.md with `/init` (it's too high-leverage for automation), don't use negative-only constraints without alternatives (agents get stuck), avoid building extensive slash command libraries (defeats natural language interaction), and don't `@`-mention reference docs from CLAUDE.md (bloats context every session — instead, tell Claude when to read specific files).

Trail of Bits' production CLAUDE.md exemplifies the principle-over-command approach: "No speculative features — don't add features, flags, or configuration unless users actively need them" and "Replace, don't deprecate — when a new implementation replaces an old one, remove the old one entirely."

---

## Conclusion

The template repository architecture maps cleanly to Claude Code's native capabilities. The `.claude/rules/` directory with path-targeted YAML frontmatter is the primary composition mechanism — overlays contribute rule files via symlinks, and Claude Code's file resolution handles the rest transparently. The `@import` syntax in CLAUDE.md provides the routing layer, and the tiered settings hierarchy (managed → project → user → local) enables security policies that cannot be overridden.

Three design principles emerge from production experience. First, **context is a finite resource** — every instruction, every `@`-imported file, every MCP server tool description consumes tokens from a limited budget. The overlay system's value lies not just in adding capabilities but in loading only what's relevant. Second, **deterministic beats probabilistic for security** — hooks with exit code 2 provide guaranteed enforcement that CLAUDE.md behavioral guidance cannot match. Third, **the activation script is the key bridge** between the template repository's organization and Claude Code's flat `.claude/` directory model. Without it, the overlay pattern is just directory structure; with it, switching between web development, game development, and AI research configurations becomes a single command.

The most sophisticated teams run 5–10 parallel Claude instances across git worktrees, each with use-case-specific overlays activated, treating context management discipline (not prompt engineering) as the primary lever for output quality.