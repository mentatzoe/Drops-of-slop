# Gemini CLI Gold Standard Template

A highly structured, "Zero-Trust" baseline repository for the Gemini CLI ecosystem. This workspace emphasizes advanced Agentic Workflows, MCP-driven memory, and a "Base + Overlays" composable file system architecture.

## 🏗️ Architecture: Base + Overlays

This template breaks your agent context into a kernel/user-space analogy to prevent context bloat:
- **Base (`base/`)**: The immutable core. Contains global security hooks (`block-secrets.sh`, `audit-logger.sh`), system-wide memory policies, and base routers.
- **Overlays (`overlays/`)**: Domain-specific contexts (e.g., `web-dev`, `obsidian-pkm`). Overlays provide specialized agents, rule sets, and system instructions loaded dynamically.

### Managing Workspaces

To initialize the template in a local project, use the built-in activation scripts. These manage the `.gemini/` configuration directory via safe symbolic links:

```bash
# Activate a specific profile (e.g., web-dev)
./activate.sh web-dev

# Tear down the active profile, returning to a clean state
./deactivate.sh
```

## 🤖 The Autonomous Workflow

For any new feature request, the template enforces a strict, 3-stage autonomous pipeline to minimize hallucination and maximize human-in-the-loop safety:

1. **Architect (`@architect.md`)**: Acts as a systems designer. It interviews you to resolve ambiguities and synthesize a formal specification into a transient `.gemini/active-plan.md` file.
2. **Planner (`@planner.md`)**: A completely read-only agent that investigates your codebase. It generates a visual, step-by-step implementation checklist inside `.gemini/active-plan.md` and pauses for your approval.
3. **Implementer (`@implementer.md`)**: The execution agent. It strictly follows the approved plan, performs soft guardrail checks, checks off items inline (`- [x]`), and logs actions transparently.

## 🧠 Memory Protocol

**Native flat-file persistence is strictly restricted.** 
To prevent context fragmentation across projects, persistent memory operations are routed exclusively through external MCPs (like the `engram` graph database).
- Fact, Profile, or Decision updates are saved asynchronously using `engram:mem_save`.
- Short-term feature orchestration relies entirely on ephemeral local state (`.gemini/active-plan.md`), which is globally `.geminiignore`d.

## 🛡️ Security & Hooks

Operating under a "Secure by Design" philosophy:
- **`BeforeTool` Hook:** `block-secrets.sh` parses all shell executions and regex-blocks exposed API keys/secrets before they reach your system.
- **`AfterTool` Hook:** `audit-logger.sh` creates a local timeline log of all commands executed by Gemini.
- **`guardrails.toml`**: Restricts highly dangerous shell commands (e.g., `rm -rf`, `sudo`) and enforces transparent reasoning via required `Meta-Commentary` before execution.
