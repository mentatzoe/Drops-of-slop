# Template Migration System Plan

## Objective
Provide a seamless, LLM-driven upgrade path for projects that have already been initialized using the standard Gemini CLI `/init` command. The goal is to safely adapt their existing architecture and context into the new "Gold Standard" JIT-routed format.

## 1. Automated Detection & Prompt
When `init-gemini.sh` is executed, it actively checks for the existence of `.gemini/` and `GEMINI.md`. 
- If none exist, it performs a **Clean Install**.
- If either exists, it pauses execution and prompts the user: `⚠️ Existing Gemini configuration detected. [y/N] Migrate existing setup to Gold Standard?`.

## 2. Backup Protocol (Safety First)
Before modifying any files, the script will create a full timestamped backup of the current state:
- Copies `.gemini/` to `.gemini.backup_<timestamp>/`
- Copies existing `GEMINI.md` to `GEMINI.backup_<timestamp>.md`

## 3. Migration Mechanics (Context Preservation)

Rather than simply overwriting files with Bash `cp`, the migration process uses Gemini itself to analyze and adapt the user's legacy configurations. The script will invoke a specialized `migrator.md` subagent (part of the template) to execute the following logic:

### A. The Root Config (`GEMINI.md`)
- **Analysis:** The migrator agent reads the user's raw `GEMINI.md` context.
- **Action:** It extracts the user's custom environment instructions and prompts the user for approval to convert them into a dedicated `@agents/local-context.md` subagent. It then overwrites `GEMINI.md` with the strict Gold Standard JIT-Router schema.

### B. Configuration (`settings.json`)
- **Analysis:** The script reads the user's existing `settings.json` to identify custom MCP servers, auto-approval thresholds, or tools payload.
- **Action:** Using either a native `jq` merge function (or via the migrator agent), it injects the template's mandatory `AfterTool`/`BeforeTool` hooks and standard MCPs *without* deleting or overwriting the user's custom server blocks.

### C. Legacy Agents (`.gemini/agents/`)
- **Analysis:** The migrator scans existing `.md` or `.yaml` files in the user's agents directory.
- **Action:** It copies the Gold Standard agents directly in alongside the legacy files. The migrator then analyzes the legacy agents to see if any conflict with the new standard (e.g., if the user already had a `planner.md`). It suggests renamed paths or routing adaptations to the user for approval.

## 4. Execution Flow
1. User runs `init-gemini.sh`
2. Bash detects `.gemini/` -> Prompts `[y/N] Migrate?`
3. Execute localized backups.
4. Bash fetches the template to a `/tmp` folder.
5. Bash deep-merges `settings.json` using `jq`.
6. Bash drops `migrator.md` into the user's `.gemini/agents/` and invokes it via CLI (`gemini chat --agent migrator ...`).
7. The `migrator` subagent handles the analysis -> proposal -> approval loop for `GEMINI.md` and legacy agents.
