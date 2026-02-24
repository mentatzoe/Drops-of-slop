# Gemini CLI Gold Standard Template

A zero-trust baseline configuration for the Gemini CLI ecosystem. This monolithic `.gemini/` template uses Just-In-Time (JIT) context routing and MCP-driven memory to run agentic workflows.

## Quickstart

Follow these steps to initialize the template in a new or existing project and trigger your first autonomous workflow:

1. **Prerequisites:** Ensure you have Node.js and `npx` installed globally. If you plan to migrate an existing Gemini setup, you must also have `jq` installed.
2. **Installation:** Download and execute the initialization script in the root of your target project:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/gemini-templates/gemini-cli-template/init-gemini.sh -o init-gemini.sh
   chmod +x init-gemini.sh
   ./init-gemini.sh
   ```
3. **Start a Session:** Launch the Gemini CLI in your project directory:
   ```bash
   gemini chat
   ```
4. **Trigger the Workflow:** Ask Gemini to build a new feature by explicitly triggering the Architect agent:
   ```text
   "I want to build a new feature. Please trigger the Architect."
   ```

## Architecture: JIT Context Routing

This template uses a single, centralized `.gemini/` directory. Rather than physically swapping files in and out, the root `GEMINI.md` file acts as a global capability router.

When you initiate a session, `GEMINI.md` analyzes your request and dynamically delegates tasks to one of 14+ specialized subagents located in `.gemini/agents/`. The CLI loads only the relevant persona and its specific tools into context. This prevents context bloat and maintains a single source of truth.

### Migrating Existing Projects

If you already have a `.gemini/` workspace initialized, `init-gemini.sh` will safely adapt your architecture without destroying your context:

1. **Automated Backup:** The script detects existing setups and prompts for migration, silently backing up your legacy files to a `.gemini.backup_<timestamp>` folder.
2. **Deep Merging (Phase 1):** It merges your existing `settings.json` with the new template using `jq`. This retains your custom MCP servers alongside the new zero-trust security hooks.
3. **Semantic Mapping (Phase 2):** To enforce the strict JIT routing constraints, the script overwrites the root `GEMINI.md`. It will instruct you to manually copy any custom system prompts from your backup into the appropriate specialized overlay agents (or define a new one).

### The Autonomous Workflow

For any new feature request or complex build, the template enforces a 3-stage autonomous pipeline.

1. **Architect (`@architect.md`):** Acts as a systems designer. It interviews you (strict limit of 3-5 questions) to resolve ambiguities and synthesizes a formal specification into a transient `.gemini/active-plan.md` file.
2. **Planner (`@planner.md`):** A completely read-only agent that investigates your codebase. It appends a visual, step-by-step implementation checklist (`- [ ]`) inside `.gemini/active-plan.md` and pauses for your explicit approval in the chat.
3. **Implementer (`@implementer.md`):** The execution agent. Once you say "Proceed", it follows the approved plan. It performs soft guardrail checks using meta-commentary and checks off items (- [x]) as it builds the application.

## Memory Protocol

Native flat-file persistence is strictly restricted.

To prevent context fragmentation, the template routes persistent memory operations exclusively through external MCPs (specifically, the `engram` graph database).

- **Auto-Update:** When you share a fact about your profile, preferences, or a system decision, the agents silently log it using the `engram:mem_save` tool.
- **Workflow State:** Short-term orchestration relies entirely on ephemeral local state (`.gemini/active-plan.md`), which is globally `.geminiignore`d so it does not pollute your Git history.

## Security & Hooks

Operating under a secure-by-design philosophy, the repository hardens the execution sandbox:

- **BeforeTool Hook:** `.gemini/hooks/block-secrets.sh` parses all arguments before shell executions and regex-blocks exposed API keys/secrets before they reach your system terminal.
- **AfterTool Hook:** `.gemini/hooks/audit-logger.sh` creates a local timeline log of all commands executed by Gemini.
- **Guardrails:** `.gemini/policies/guardrails.toml` restricts highly dangerous shell commands (e.g., `rm -rf`, `sudo`). It requires agents to write meta-commentary to explain their reasoning before executing native commands.
