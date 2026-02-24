# Gemini CLI Gold Standard Template

A highly structured, "Zero-Trust" baseline repository configuration for the Gemini CLI ecosystem. This workspace template provides a robust, monolithic `.gemini/` configuration featuring advanced Agentic Workflows, MCP-driven memory, and Just-In-Time (JIT) context routing.

## 🏗️ Architecture: JIT Context Routing

This template uses a single, centralized `.gemini/` directory. Rather than physically swapping files in and out, the root `GEMINI.md` file acts as a **Global Capability Router**.

When you initiate a session, `GEMINI.md` analyzes your request and dynamically delegates tasks to one of 14+ specialized subagents located in `.gemini/agents/`. This ensures that only the relevant persona (e.g., `web-developer.md`, `qa-automation.md`, or `ai-researcher.md`) and its specific tools are loaded into context, preventing context bloat while maintaining a single source of truth.

### Initialization & Prerequisites

To use this template:
1. Copy the `.gemini/` folder and other repository files directly into the root of your local project workspace.
2. Ensure you have Node.js and `npx` installed globally, as the `settings.json` relies on local binary execution for Model Context Protocol (MCP) servers (like `github-mcp` or `engram-mcp`).

## 🤖 The Autonomous Workflow

For any new feature request or complex build, the template strictly enforces a 3-stage autonomous pipeline to minimize hallucination and maximize human-in-the-loop safety. 

To trigger this workflow, ask Gemini to start a new feature block:
`gemini chat "I want to build a new feature. Please trigger the Architect."`

1. **Architect (`@architect.md`)**: Acts as a systems designer. It interviews you (strict limit of 3-5 questions) to resolve ambiguities and synthesizes a formal specification into a transient `.gemini/active-plan.md` file.
2. **Planner (`@planner.md`)**: A completely read-only agent that investigates your codebase. It appends a visual, step-by-step implementation checklist (`- [ ]`) inside `.gemini/active-plan.md` and pauses for your explicit approval in the chat.
3. **Implementer (`@implementer.md`)**: The execution agent. Once you say "Proceed", it strictly follows the approved plan, performs soft guardrail checks via Meta-Commentary, and checks off items inline (`- [x]`) as it builds your application.

## 🧠 Memory Protocol

**Native flat-file persistence is strictly restricted.** 
To prevent context fragmentation across projects, persistent memory operations are routed exclusively through external MCPs (specifically, the `engram` graph database).
- **Auto-Update:** Whenever you share a fact about your profile, preferences, or a system decision, the agents are instructed to silently log it using the `engram:mem_save` tool.
- **Workflow State:** Short-term orchestration (like the workflow above) relies entirely on ephemeral local state (`.gemini/active-plan.md`), which is globally `.geminiignore`d so it does not pollute your Git history.

## 🛡️ Security & Hooks

Operating under a "Secure by Design" philosophy, the repository hardens the execution sandbox:
- **`BeforeTool` Hook:** `.gemini/hooks/block-secrets.sh` parses all arguments before shell executions and regex-blocks exposed API keys/secrets before they reach your system terminal.
- **`AfterTool` Hook:** `.gemini/hooks/audit-logger.sh` creates a local timeline log of all commands executed by Gemini.
- **`guardrails.toml`**: Restricts highly dangerous shell commands (e.g., `rm -rf`, `sudo`) and enforces transparent reasoning via required `Meta-Commentary` before native execution is permitted.
