# User feedback

## Pending

### Autonomous planning and orchestration
Analyse this prompt based on the existing architecture, and provide an audit of its suitability and effectiveness.
```
Please update my current workspace to implement a multi-agent, autonomous development workflow. I want to ensure that for any new feature request, the system automatically interviews me, formulates a plan, waits for my validation, and tracks changes securely. 

Please implement this using the experimental Subagents architecture. Execute the following steps:

1. Enable Prerequisites: Update `.gemini/settings.json` to enable subagents and checkpointing. Set `"experimental": { "enableAgents": true }` and `"general": { "checkpointing": { "enabled": true } }`.

2. Create the Architect Subagent: Create a file at `.gemini/agents/architect.md`. Use YAML frontmatter to set `name: architect`, `description: "Use this agent FIRST for any new feature or task. It gathers requirements and interviews the user to resolve ambiguities."`, and restrict its tools to `[read_file]`. In the markdown body, instruct it to act as a Senior System Architect whose sole job is to ask targeted, clarifying questions using the `ask_user` tool (implicitly or explicitly) and wait for my answers before any planning begins.

3. Create the Planner Subagent: Create a file at `.gemini/agents/planner.md`. Set its frontmatter `name: planner`, `description: "Use this agent after requirements are gathered by the architect. It creates strategic implementation plans."`, and restrict its tools to `[read_file, glob, search_file_content]`. In the body, instruct it to investigate the codebase and output a step-by-step markdown checklist. Emphasize that it is strictly read-only and must pause to await my explicit approval before implementation.

4. Create the Implementer Subagent: Create a file at `.gemini/agents/implementer.md`. Set its frontmatter `name: implementer`, `description: "Use this agent ONLY after the user has explicitly approved a plan from the planner. It writes code and executes shell commands."`. Give it standard tools including `[write_file, replace, run_shell_command]`. In the body, instruct it to execute the approved plan step-by-step, verifying its work as it goes.

5. Update the Root Router: Modify the root `GEMINI.md` to establish the workflow rules. Instruct the implicit `generalist_agent` to enforce a strict pipeline: Architect -> Planner -> Implementer. Also, add a rule that before transitioning to the Implementer, the agent should remind me to use the `/chat save <feature-name>` command to isolate this specific plan's context and track its changes independently.
```

## Complete
### Based on commit 308df4bb400ad08635636e96637fab76db1e986a

- Missing memory instruction to save as we go, such as:
```
### Auto-Update Memory (MANDATORY)

**Update memory files AS YOU GO, not at the end.** When you learn something new, update immediately.

| Trigger | Action |
|---------|--------|
| User shares a fact about themselves | → Update `memory-profile.md` |
| User states a preference | → Update `memory-preferences.md` |
| A decision is made | → Update `memory-decisions.md` with date |
| Completing substantive work | → Add to `memory-sessions.md` |

**Skip:** Quick factual questions, trivial tasks with no new info.

**DO NOT ASK. Just update the files when you learn something.**
```
- Missing AfterTool hook for logging and memory updates.