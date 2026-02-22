# Claude Code's four configuration layers and when each one matters

**Skills, output styles, agents, and rules are not interchangeable — they modify different parts of Claude's processing pipeline and cannot be freely substituted.** The core architectural insight: output styles replace the system prompt, CLAUDE.md and rules inject user messages after the system prompt, skills inject context on-demand via tool calls, and agents spawn entirely separate context windows. Your structural problem — personas stored as output styles being invisible to the skill system — is a direct consequence of these being parallel, non-intersecting pipelines with no built-in dual-registration mechanism.

This report maps the precise boundaries between all four systems, documents the composability constraints, and proposes concrete patterns for the hybrid base-plus-overlays architecture you're building.

---

## How each mechanism actually modifies Claude's context

Understanding where each system injects its content into Claude's processing pipeline is the foundation for every architectural decision.

**Output styles** directly replace Claude Code's default system prompt. When you activate a custom output style, all software engineering personality instructions are stripped out unless you set `keep-coding-instructions: true`. The output style's markdown body becomes the new system prompt personality. Only **one output style can be active at a time** — selection persists per-project in `.claude/settings.local.json`. This is the most powerful behavioral override available, but also the most destructive: it removes Claude's coding best practices entirely by default.

**CLAUDE.md and rules** are injected as **user messages following the system prompt** — they do not modify the system prompt itself. This is a critical distinction. CLAUDE.md files load hierarchically (enterprise → project → user → local), with parent directories traversed recursively upward from cwd. Rules in `.claude/rules/` load at the same priority as `.claude/CLAUDE.md` but support **path-scoping** via YAML `paths:` frontmatter, meaning a rule like `api-conventions.md` with `paths: ["src/api/**/*.ts"]` only loads when Claude works on matching files. Both are always-on within their scope — there's no way to "switch off" a loaded CLAUDE.md or unscoped rule mid-session.

**Skills** use a fundamentally different injection pattern. At session start, only skill **metadata** (name + description, ~100 tokens each) loads into an `<available_skills>` XML block embedded in the Skill tool's description. The full SKILL.md body loads **only when the skill is invoked** — either by the user typing `/skill-name` or by Claude autonomously deciding the skill is relevant based on description matching. This progressive disclosure architecture means skills have effectively unbounded content capacity since supporting files in `references/` and `scripts/` directories load only on demand.

**Agents** operate in **entirely separate context windows**. Each agent gets its own system prompt (the markdown body of the agent definition), its own tool set, potentially a different model, and independent conversation history. Results are summarized and returned to the main conversation. Agents cannot spawn other agents (preventing infinite nesting), and their context is fully isolated from the main thread.

| Mechanism | Injection point | Scope | Persistence | Can combine? |
|-----------|----------------|-------|-------------|--------------|
| Output style | Replaces system prompt | Session-wide | Per-project setting | No — one at a time |
| CLAUDE.md | User message after system prompt | Session-wide | Always loaded | Yes — hierarchical |
| Rules | User message (same as CLAUDE.md) | Global or path-scoped | Auto-loaded | Yes — all matching rules load |
| Skills | On-demand context via tool call | Per-invocation | Progressive disclosure | Yes — multiple simultaneously |
| Agents | Separate context window | Per-delegation | Fresh each invocation | N/A — isolated |

---

## Skills versus output styles: the precise mechanical boundary

A skill is a **directory** containing a required `SKILL.md` file with YAML frontmatter and optional supporting directories (`scripts/`, `references/`, `assets/`). Skills live in `~/.claude/skills/` (personal), `.claude/skills/` (project), or bundled with plugins. The frontmatter supports these Claude Code-specific fields:

```yaml
---
name: my-skill                    # kebab-case, max 64 chars
description: What it does         # max 1024 chars — CRITICAL for discovery
context: fork                     # runs in isolated subagent
agent: Explore                    # which subagent to use with fork
disable-model-invocation: true    # only user can invoke via /slash
user-invocable: false             # only Claude can invoke (background knowledge)
allowed-tools: Read, Grep, Glob   # restricts + auto-approves tools
model: claude-opus-4-20250514     # override model
mode: true                        # appears in "modes" section of skill list
---
```

An output style is a **single markdown file** in `~/.claude/output-styles/` or `.claude/output-styles/` with minimal frontmatter:

```yaml
---
name: My Custom Style
description: Displayed in /output-style menu
keep-coding-instructions: true    # retain coding guidance (default: false)
---
```

**Can a skill include behavioral/persona instructions?** Yes — explicitly. The official docs state "Your SKILL.md can contain anything." Skills can teach behavioral patterns, persona instructions, domain knowledge, and procedural workflows. The distinction between "reference content" (conventions, style guides) and "task content" (step-by-step actions) is a design guideline, not an enforcement boundary.

**Can an output style be invoked as a skill?** No. These are completely parallel systems with no cross-referencing mechanism. Output styles have no `name` field compatible with the skill index, no progressive disclosure, and no way to appear in the `<available_skills>` block. Conversely, skills cannot modify the system prompt — they inject content as user messages via tool calls.

**What happens when skill instructions conflict with the active output style?** The output style controls the system prompt; the skill injects a user message. In practice, the system prompt (output style) establishes baseline personality and domain framing, while skill instructions arrive later as task-specific context. Claude will attempt to follow both, but **system prompt instructions generally take precedence** over user message instructions when they directly conflict, since the system prompt frames Claude's fundamental operating parameters.

**Can multiple skills be active simultaneously?** Yes. "Claude can load multiple skills simultaneously. Your skill should work well alongside others, not assume it's the only capability available." Skills stack in the conversation context — `test-driven-development` + `systematic-debugging` + `using-git-worktrees` can all be active at once. However, each invoked skill adds **1,500–5,000+ tokens** to the main conversation context, and skill invocations accumulate until compaction.

**Can multiple output styles be combined?** No. Only one output style is active at a time. Switching styles replaces the entire system prompt modification.

**How does `context: fork` interact with output styles?** A forked skill runs in a subagent with its own context window. The subagent does **not** inherit the main conversation's output style — it gets the default system prompt (or its custom agent's prompt if `agent:` is specified). This means a persona defined via output style won't propagate into forked skill execution. Important caveat: there's a known issue (GitHub #17283) where `context: fork` and `agent:` fields may be ignored when skills are invoked programmatically via the Skill tool.

---

## Agents complete the triangle with isolated execution contexts

Custom agents are markdown files in `.claude/agents/` with richer configuration than either skills or output styles:

```yaml
---
name: code-reviewer
description: Reviews code for quality and best practices
tools: Read, Grep, Glob           # tool allowlist (inherits all if omitted)
disallowedTools: Write, Edit      # tool denylist alternative
model: sonnet                     # sonnet, opus, haiku, or inherit
permissionMode: plan              # default, acceptEdits, bypassPermissions, plan
skills: skill1, skill2            # auto-load these skills into agent context
maxTurns: 10                      # turn limit
---
You are a senior code reviewer ensuring high standards of code quality...
```

The markdown body **is** the agent's system prompt — it absolutely can and should contain persona-like behavioral instructions. This is the intended design. The built-in agents demonstrate this: **Explore** uses Haiku for speed with strictly read-only tools, while **Plan** uses Sonnet with read-only access for research before presenting plans.

**Can agents invoke skills?** Yes — the `skills:` frontmatter field accepts a comma-separated list of skill names to auto-load when the agent starts. This is the only cross-system composition mechanism that exists natively.

**For "I want Claude to behave as a strict code reviewer" — which mechanism?** The answer depends on scope:

- **Session-wide personality shift** (Claude always acts as reviewer) → output style
- **On-demand capability** (review when asked, normal otherwise) → skill with behavioral instructions
- **Delegated task** (review this PR, return findings) → agent with reviewer persona + scoped tools
- **Always-on constraints** (never approve code without tests) → rules in `.claude/rules/`

The "strict reviewer" case is actually best served by an **agent** — it benefits from context isolation (review findings don't clutter the main conversation), tool restrictions (read-only access prevents accidental edits), and a focused system prompt. But if you want the *main* Claude to persistently behave as a reviewer, that's an output style.

---

## The 2% budget and what happens at scale with 20+ skills

The skill discovery system imposes a **character budget of 2% of the context window** (with a **16,000-character fallback**) for the combined text of all skill descriptions in the `<available_skills>` block. For a 200K-token context window, this translates to roughly **4,000 tokens** for all skill metadata combined.

Each skill's metadata entry consumes approximately **100 tokens** (name + description). With 20+ skills, you're consuming 2,000+ tokens of the budget — still within limits for most context windows, but discovery reliability degrades. Multiple practitioners report that **Claude's auto-invocation success rate drops significantly** as the number of installed skills increases, because the LLM-based routing (pure forward-pass reasoning, no algorithmic matching) becomes less reliable with more options.

Community testing data on skill activation rates reveals the challenge:

- **No optimization**: ~20% auto-activation rate
- **Optimized descriptions with "USE WHEN" patterns**: ~50%
- **Descriptions with real examples**: 72–90%
- **Hook-driven forced evaluation**: ~84%

Skills with `disable-model-invocation: true` are excluded from the metadata budget entirely until explicitly invoked — a useful optimization when you have many skills but only some should auto-trigger.

**Token impact comparison across mechanisms**: The system prompt (including output style) consumes ~2.7K tokens. Custom agent definitions consume ~1.3K tokens. Memory files (CLAUDE.md + rules) consume ~7.4K tokens on average. Skills metadata adds ~1K tokens for a moderate collection. The **autocompact buffer** is hardcoded at **33K tokens** (~16.5% of a 200K window), and autocompaction triggers at ~167K tokens used. Each inline skill invocation adds 2–5K tokens to the main context, while an agent delegation returns only ~500 tokens of summary — making agents **3–5× more context-efficient** for heavy operations.

---

## Where personas should actually live in your architecture

This is the crux of your structural problem. The answer requires distinguishing between four types of behavioral modification:

**Always-on constraints** (coding standards, security rules, naming conventions) belong in **`.claude/rules/`** with path-scoping where appropriate. These auto-load, require no invocation, and can be scoped to relevant file patterns. Keep each rule file focused — `code-style.md`, `testing.md`, `security.md` — rather than one monolithic file. The recommended ceiling for CLAUDE.md is **~150 lines**; beyond that, instructions get silently ignored.

**Session-wide personality transformations** ("you are a worldbuilder," "you are a research analyst") belong as **output styles**. This is the only mechanism that actually replaces Claude's core personality. But output styles are invisible to the skill system and cannot be composed.

**On-demand expertise with behavioral instructions** ("when reviewing code, be extremely strict and pedantic") should be **skills** with behavioral preambles. A skill can absolutely contain persona instructions alongside procedural ones — "You are a meticulous code reviewer. Check every function for..." is perfectly valid skill content. The behavioral instructions load on-demand and stack with whatever output style is active.

**Delegated specialist work** ("review this PR as a security expert, then report back") belongs in **agents**. The agent's markdown body defines the persona, its tool restrictions enforce the role, and context isolation prevents cross-contamination.

**The switchable persona pattern**: For modes that change Claude's behavior globally for a session, the cleanest mechanism is actually **shell function aliases** that launch Claude Code with different `--append-system-prompt` and `--mcp-config` flags:

```bash
cc()  { claude "$@" }                                          # Default
ccr() { claude "$@" --append-system-prompt "You are a strict code reviewer..." }
ccw() { claude "$@" --append-system-prompt "You are a worldbuilder..." }
```

This avoids the output style limitation (only one at a time, replaces coding instructions) while providing session-wide behavioral priming via `--append-system-prompt`, which **appends to** rather than replaces the system prompt. Within a session, you can also use the `mode: true` frontmatter on skills to create switchable modes that appear in a special section of the skills list.

---

## Solving the template structure problem with practical patterns

Your core challenge: **personas stored as output styles can't be invoked as skills, and personas stored as skills won't modify the system prompt.** There is no native dual-registration mechanism. Here are the viable architectural patterns:

**Pattern 1: Skill-first personas with behavioral preambles.** Store personas as skills, not output styles. The skill's SKILL.md contains both the behavioral persona instructions AND task-specific guidance. When invoked (via `/persona-name` or auto-invocation), the persona instructions inject into the conversation context as a user message. This doesn't replace the system prompt, but it does prime Claude's behavior for the remainder of the interaction. Use `mode: true` in frontmatter so these appear grouped in the skills list.

```yaml
---
name: strict-reviewer
description: Activate strict code review mode. Use when reviewing PRs, auditing code quality, or doing security reviews.
mode: true
allowed-tools: Read, Grep, Glob
---
# Strict Reviewer Mode
You are now operating as an extremely meticulous code reviewer. Your standards are:
- Every function MUST have error handling
- No magic numbers without named constants
- All public APIs require documentation
[... behavioral instructions ...]
## Review Process
1. Scan for structural issues first
2. Check error handling coverage
[... procedural instructions ...]
```

**Pattern 2: Agent-backed personas for heavy workflows.** Define the persona as an agent in `.claude/agents/`, with skills auto-loaded via the `skills:` field. The agent's markdown body contains the persona, while the referenced skills provide procedural knowledge. This is the most composable approach — one agent persona can load multiple skill modules.

```yaml
---
name: worldbuilder
description: Creative worldbuilding agent for fiction and game design
model: opus
skills: naming-conventions, lore-consistency-check, map-generation
---
You are a master worldbuilder. You approach every creative decision with...
```

**Pattern 3: The hook-driven activation pattern** (pioneered by diet103/claude-code-infrastructure-showcase). Create a `skill-rules.json` configuration and a `UserPromptSubmit` hook that reads the config, matches keywords and intent patterns in the user's prompt, and injects skill activation suggestions. This achieves ~84% reliable activation without requiring manual `/skill-name` invocation, effectively making skills behave like always-on personas when their triggers match.

**Pattern 4: Thin output style + companion skill.** If you truly need system-prompt-level personality modification, create a minimal output style for the persona's communication style and a companion skill for the domain expertise. The output style handles *how* Claude communicates; the skill handles *what* it knows. This isn't true dual-registration — they're separate files invoked separately — but it achieves the composite effect. The context cost is the output style (always loaded, replaces system prompt) plus the skill metadata (~100 tokens always, full body on-demand).

**The directory structure** that maximizes indexability:

```
.claude/
├── skills/
│   ├── strict-reviewer/
│   │   ├── SKILL.md              # Persona + procedures (indexed as skill)
│   │   └── references/
│   │       └── checklist.md
│   ├── pair-programmer/
│   │   └── SKILL.md
│   └── worldbuilder/
│       ├── SKILL.md
│       └── references/
│           └── lore-template.md
├── agents/
│   ├── strict-reviewer.md        # Agent wrapper (can auto-load the skill)
│   └── worldbuilder.md
├── output-styles/
│   └── creative-mode.md          # Only if you need system prompt replacement
└── rules/
    ├── always-test.md            # Always-on constraints
    └── security.md
```

**Critical caveat about directory traversal**: Unlike CLAUDE.md, the `skills/`, `agents/`, and `output-styles/` directories do **not** traverse parent directories (GitHub issue #26489). In a monorepo, skills placed in the root `.claude/skills/` won't be discovered when Claude Code is launched from a subdirectory. The workaround is **symlinks**: `ln -s ../../.claude/skills .claude/skills` in each package directory.

**Performance cost of dual registration** (skill + agent referencing the same persona content): The skill metadata adds ~100 tokens to every session. The agent definition adds ~200–500 tokens. When the skill is invoked inline, it adds 2–5K tokens to the main context. When the agent is delegated to, it consumes its own context window but returns only ~500 tokens of summary. The total overhead is modest — **dual registration costs roughly 300–600 extra tokens at baseline** and provides maximum flexibility for both inline and delegated usage patterns.

---

## Conclusion: the architectural decision tree

The four configuration layers form a clear hierarchy of behavioral control. **Output styles** own the system prompt and define global personality — use them only when you need to fundamentally redefine Claude's operating domain (research analyst, creative writer) and accept that only one can be active. **Rules and CLAUDE.md** provide always-on guardrails injected as user messages — use them for constraints that must never be forgotten (testing requirements, security policies, coding standards). **Skills** provide on-demand expertise with progressive disclosure — use them for switchable personas and repeatable workflows, leveraging the `mode: true` flag for persona-like modes. **Agents** provide isolated execution with custom system prompts — use them for delegated specialist work where context isolation and tool restriction matter.

The pattern that best solves your template repository problem is **skill-first personas with optional agent wrappers**: store each persona as a skill (ensuring it's indexed, discoverable, and composable), then create companion agents that reference those skills via the `skills:` field for cases requiring isolated execution. Avoid output styles for personas unless you genuinely need system prompt replacement — the tradeoff (invisible to skill system, mutually exclusive, strips coding instructions) rarely justifies the benefit over well-crafted skill-based personas. For always-on behavioral constraints that should apply regardless of active persona, use path-scoped rules. This layered approach gives you indexability, composability, and clean separation of concerns without fighting the architecture.