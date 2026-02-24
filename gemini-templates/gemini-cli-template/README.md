# Gemini CLI Gold Standard Template

This template configures the Gemini CLI to use Just-In-Time (JIT) context routing. It prevents context bloat by loading only the agent and tools required for the current task.

## Quickstart

To install the template:

1. **Install Prerequisites**: Install Node.js, `npx`, and `jq`.
2. **Initialize Workspace**: Run the installer in your project root:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/gemini-templates/gemini-cli-template/init-gemini.sh -o init-gemini.sh
   chmod +x init-gemini.sh
   ./init-gemini.sh
   ```
3. **Start Gemini**: Launch the CLI:
   ```bash
   gemini chat
   ```
4. **Request a Feature**: Trigger the Architect:
   ```text
   "I want to build a new feature. Please trigger the Architect."
   ```

## Architecture: JIT Context Routing

The root `GEMINI.md` acts as a global router. When you start a session, it analyzes your request and delegates the task to a specialized subagent in `.agents/`.

If the requested capability is missing, the router calls the **Catalog Manager** (`@catalog-manager.md`). This agent searches `external-catalog.json` and downloads the required agent or MCP server (such as the Standalone Browser) on demand.

### Migrating Existing Projects

If you already use a custom `.gemini/` directory, `init-gemini.sh` migrates your settings safely:

1. **Backup:** The script copies your existing setup to a backup folder.
2. **Merge Settings:** It uses `jq` to merge your `settings.json` with the new template, keeping your custom MCP servers intact.
3. **Apply Template:** It installs the new `GEMINI.md` router and required hooks. You must manually copy your old custom instructions into the new overlay agents.

### Receiving Upstream Updates

To fetch new template updates without overwriting your custom configuration, run the update script:

```bash
curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/gemini-templates/gemini-cli-template/update-gemini.sh -o update-gemini.sh
chmod +x update-gemini.sh
./update-gemini.sh --version=main
```

## The Development Process

The template enforces three steps for building new features:

1. **Architect (`@architect.md`):** Interviews you to define requirements. Writes a formal specification to `.gemini/active-plan.md`.
2. **Planner (`@planner.md`):** Reads the specification and the codebase. Appends an implementation checklist to `.gemini/active-plan.md` and pauses for your approval.
3. **Implementer (`@implementer.md`):** Writes the code and completes the checklist.

## Memory Protocol

The template routes persistent memory operations exclusively through the `engram` graph database MCP. Agents log decisions and preferences automatically using the `engram:mem_save` tool.

Short-term orchestration relies on the `.gemini/active-plan.md` file. Git ignores this file.

## Security

- **Before execution:** `.gemini/hooks/block-secrets.sh` blocks exposed API keys from reaching the terminal.
- **After execution:** `.gemini/hooks/audit-logger.sh` records all commands executed by Gemini.
- **Guardrails:** `.gemini/policies/guardrails.toml` restricts dangerous commands (like `rm -rf`) and forces agents to explain their reasoning before running shell commands.
