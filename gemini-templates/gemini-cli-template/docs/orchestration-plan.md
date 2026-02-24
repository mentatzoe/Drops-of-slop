# Refined Orchestration Workflow Plan

Based on the audit and user preferences, here is the architecture-safe adaptation for the **Architect -> Planner -> Implementer** orchestration workflow.

## 1. Selected Design Decisions
1. **Handoff (Pending Recommendation):** 
   - *Option A (MCP)* vs *Option B (Temp File)* is currently being evaluated. We need to decide whether to pollute the graph database with transient feature specs or manage a temporary local manifest.
2. **Capped Interview Protocol:** 
   - The Architect will be limited to 3-5 questions. It MUST present the user with an explicit menu of terminal actions *in addition to their actual answers*: `[1] Recommend an approach, [2] Skip question, [3] Proceed to planning`.
3. **Checklist Formatting:** 
   - The Planner will output visually tracked markdown checklists (`- [ ]`) inside the `.gemini/active-plan.md` file so the Implementer can verify steps visually as it executes them.
4. **Soft Guardrails (Implementer):** 
   - The Implementer will explicitly include `@../policies/guardrails.toml` and log violations via the `Meta-Commentary` system, ensuring there is a textual audit trail if it attempts a risky native sandbox command.

## 2. Implementation Steps

1. **Update Root Router (`GEMINI.md`):**
   - Add the strict pipeline transition rules: "You MUST trigger `@agents/architect.md`. Upon Architect completion, trigger `@agents/planner.md`. Upon Planner completion and user approval, trigger `@agents/implementer.md`."

2. **Update Ignore File (`.geminiignore`):**
   - Add `.gemini/active-plan.md` to prevent git tracking of the transient payload.

3. **Create Subagents:**
   - **`architect.md`**: Tool `[write_file]`. Instruction: "Ask 3-5 clarifying questions with options: [Recommend an approach, Skip question, Proceed]. Upon 'Proceed', synthesize requirements and write them to `.gemini/active-plan.md`."
   - **`planner.md`**: Tools `[read_file, glob, search_file_content, write_file]`. Instruction: "Read `.gemini/active-plan.md`. Audit the codebase natively. Append a visual markdown checklist `- [ ]` to the file with step-by-step instructions. PAUSE and await user approval."
   - **`implementer.md`**: Tools `[read_file, write_file, replace, run_shell_command]`. Instruction: "Include `@../policies/guardrails.toml`. Read `.gemini/active-plan.md`. Execute the plan step-by-step, logging any Guardrail violations via Meta-Commentary. Mark checklist items as `- [x]` upon completion."
