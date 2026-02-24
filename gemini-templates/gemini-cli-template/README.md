# Gemini CLI Gold Standard Template

This template configures the Gemini CLI to use Just-In-Time (JIT) context routing. It prevents context bloat by loading only the agent and tools required for the current task.

## Quickstart

To install the template:

1. Install Node.js, `npx`, and `jq`.
2. Run the installer in your project root:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/gemini-templates/gemini-cli-template/init-gemini.sh -o init-gemini.sh
   chmod +x init-gemini.sh
   ./init-gemini.sh
   ```
3. Configure your environment variables:
   ```bash
   cp .gemini/.env.example .env
   # Edit .env with your specific API keys
   ```
4. Launch the CLI:
   ```bash
   gemini chat
   ```
5. Trigger the Architect:
   ```text
   "I want to build a new feature. Please trigger the Architect."
   ```

## Architecture: JIT Context Routing

The root `GEMINI.md` acts as a global router. When you start a session, it analyzes your request and delegates the task to a specialized subagent in `.agents/`.

If the requested capability is missing, the router calls the **Catalog Manager** (`@catalog-manager.md`). This agent searches `external-catalog.json` and downloads the required agent or MCP server (such as the Standalone Browser) on demand.

### Migrating Existing Projects

If you already use a custom `.gemini/` directory, `init-gemini.sh` migrates your settings safely:

1. The script copies your existing setup to a backup folder.
2. It uses `jq` to merge your `settings.json` with the new template, keeping your custom MCP servers intact.
3. It installs the new `GEMINI.md` router and required hooks. You must manually copy your old custom instructions into the new overlay agents.

### Receiving Upstream Updates

To fetch new template updates without overwriting your custom configuration, run the update script:

```bash
curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/gemini-templates/gemini-cli-template/update-gemini.sh -o update-gemini.sh
chmod +x update-gemini.sh
./update-gemini.sh --version=main
```

## The Development Process

The template enforces three steps for building new features:

1. `@architect.md` interviews you to define requirements. Writes a formal specification to `.gemini/active-plan.md`.
2. `@planner.md` reads the specification and the codebase. Appends an implementation checklist to `.gemini/active-plan.md` and pauses for your approval.
3. `@implementer.md` writes the code and completes the checklist.

## Memory Protocol (Git-Synced SQLite)

The template routes persistent memory operations exclusively through `@pepk/mcp-memory-sqlite`. This is a drop-in replacement for the official Knowledge Graph that runs on SQLite with Write-Ahead Logging (WAL), allowing multi-agent concurrency.

**Syncing AI Memory to Git:**
If you want to version control the AI's mind alongside your codebase branches:
1. The `.sqlite-wal` and `.sqlite-shm` temporary files are strictly ignored.
2. Before you `git commit`, run `.gemini/hooks/sync-memory.sh`. This flushes the WAL and safely checkpoints the database.
3. You can safely commit `.gemini/memory.sqlite` to track the Graph state.

Short-term orchestration relies on the `.gemini/active-plan.md` file. Git ignores this file.

### Expanding Capabilities (Dynamic Integration)

The template follows a Zero-Trust architecture. Only essential local tools (like SQLite memory) are active by default. Expand your environment using the MCP Wizard:

1.  Codebase Detection: Run `sh .gemini/commands/detect-project.sh` to see recommended tools.
2.  The Wizard: Run `sh .gemini/commands/mcp-wizard.sh` to install extension from the catalog.
3.  Global Preferences: Customize tools in `.gemini/preferences.json`. The agents prioritize these recommendations (e.g., Obsidian over Confluence).

### JIT Capability Loading
Agents (like `@catalog-manager`) are preference-aware. If a task requires a missing tool, they:
- Search `external-catalog.json`.
- Propose a configuration patch to `.gemini/settings.json`.
- Wait for manual approval before installation.

---
You should then add any required API keys (e.g., `JIRA_API_TOKEN`) to your `.gemini/.env` file.

## Security

- `.gemini/hooks/block-secrets.sh` blocks exposed API keys from reaching the terminal.
- `.gemini/hooks/audit-logger.sh` records all commands executed by Gemini.
- `.gemini/policies/guardrails.toml` restricts dangerous commands (like `rm -rf`) and forces agents to explain their reasoning before running shell commands.
