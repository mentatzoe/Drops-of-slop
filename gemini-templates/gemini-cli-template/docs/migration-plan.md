# Template Migration System Plan

## Objective
Provide a seamless upgrade path for projects that have already been initialized using the standard Gemini CLI `/init` command. The goal is to safely adapt their existing architecture and context into the new "Gold Standard" JIT-routed format, without polluting or confusing the strict `GEMINI.md` router.

## 1. Automated Detection
When `init-gemini.sh` is executed, it actively checks for the existence of `.gemini/` and `GEMINI.md`. 
- If none exist, it performs a **Clean Install**.
- If either exists, it pauses execution and prompts the user: `⚠️ Existing Gemini configuration detected. [y/N] Migrate existing setup to Gold Standard?`.

## 2. Backup Protocol (Safety First)
Before modifying any files, the script will create a full timestamped backup of the current state:
- Copies `.gemini/` to `.gemini.backup_<timestamp>/`
- Copies existing `GEMINI.md` to `GEMINI.backup_<timestamp>.md`

## 3. Two-Phase Migration Mechanics

Migrating an existing setup requires handling JSON configuration independently from semantic markdown agents to preserve the architectural boundaries.

### Phase 1: Automated JSON & Hooks Integration (Via Bash)
- **Configuration (`settings.json`):** The script reads the user's existing `settings.json` to identify custom MCP servers, auto-approval thresholds, or tools payload. Using a native `jq` deep merge, it injects the template's mandatory `AfterTool`/`BeforeTool` hooks and standard MCPs *without* deleting or overwriting the user's custom server blocks.
- **External Catalog (`external-catalog.json`):** Drops the new Gold Standard catalog definition into the root allowing JIT dynamic routing of remote agents via the newly added Catalog Manager.
- **Legacy Agents (`.gemini/agents/`):** The bash script copies the new Gold Standard agents directly into the user's agent directory alongside their legacy files seamlessly.

### Phase 2: Manual Semantic Context Mapping (Guided via CLI)
- **The Root Config (`GEMINI.md`):** The migration script overwrites the root `GEMINI.md` to strictly enforce the Gold Standard JIT-Router schema. 
- **User Action:** At the end of the installation, the script explicitly instructs the user to manually review `.gemini.backup_<timestamp>/GEMINI.md`. The user should extract their custom environment instructions and manually paste them into a dedicated `@agents/local-context.md` subagent.
*Reasoning: We explicitly avoid using an LLM to blindly refactor the JIT router to enforce the Zero-Trust execution model.*

## 4. Execution Flow
1. User runs `init-gemini.sh`
2. Bash detects `.gemini/` -> Prompts `[y/N] Migrate?`
3. Execute localized backups.
4. Bash fetches the template to a `/tmp` folder.
5. Bash deep-merges `settings.json` using `jq`.
6. Bash drops `GEMINI.md` and Gold Standard agents into the workspace.
7. Terminal prints explicit instructions on how the user should port custom legacy instructions from their backup into the new architecture.
