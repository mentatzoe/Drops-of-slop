# Audit: Autonomous Planning and Orchestration Workflow

This document provides a technical audit of the prompt provided in `docs/user-requirements.md` (Lines 7-21) regarding the implementation of a multi-agent autonomous development workflow. The audit evaluates the prompt's suitability and effectiveness against the established **Zero-Trust, MCP-Driven Architectural Blueprint**.

## 1. Architectural Suitability

### ✅ Alignments
- **Subagent Delegation:** The prompt correctly leverages the `.gemini/agents/` native architecture to enforce separation of concerns (`architect.md`, `planner.md`, `implementer.md`).
- **Tool Restriction:** Restricting the Architect to `[read_file]` and the Planner to read-only search tools (`[read_file, glob, search_file_content]`) perfectly aligns with the Zero-Trust execution model. It physically prevents planning agents from accidentally deploying or modifying code prematurely.
- **Root Router (`GEMINI.md`):** Using the root router to strictly enforce the workflow pipeline (Architect -> Planner -> Implementer) aligns with the blueprint's "JIT Context Routing" methodology, preventing context bloat.

### ❌ Conflicts & Vulnerabilities
- **Memory Violation:** The prompt requests the use of the native `/chat save <feature-name>` command to track changes. **This violates the core memory architecture.** Our blueprint strictly forbids native flat-file or chat-based memory tracking in favor of the `engram` MCP. Using `/chat save` fragments memory outside the graph database and causes context bloat on reload.
- **Missing Guardrails:** The `implementer.md` subagent is granted `write_file` and `run_shell_command`, but the prompt fails to mention enforcing the `@../policies/guardrails.toml` or the Glass Box transparency policy (`Meta-Commentary`). Without these, the implementer could blindly execute destructive shell commands without logging its reasoning.
- **Checkpointing Overhead:** Enabling `"general": { "checkpointing": { "enabled": true } }` in `settings.json` is redundant and potentially problematic if it relies on local filesystem caching rather than our established `.gemini/hooks/audit-logger.sh` and external MCP state tracking.

## 2. Operational Effectiveness

### The "Stuck in a Loop" Risk (The Interview Phase)
The Architect agent is instructed to use the implicit `ask_user` tool to resolve ambiguities *before* any planning begins. Because LLMs tend to be overly cautious, a "Senior System Architect" persona given an open-ended mandate to "ask targeted, clarifying questions" will almost certainly trigger endless clarification loops. 

Unless strictly capped (e.g., "Ask a maximum of 3 questions in a single numbered list"), the agent will refuse to transition to the Planner until the user has written a comprehensive PRD themselves, defeating the purpose of autonomous orchestration.

### Payload Handoff
The prompt implicitly assumes that the `planner` subagent will read the chat history to inherit the `architect`'s requirements. While true in a shared context window, rely purely on chat history is unstable over long sessions. 

**Better Approach:** The `architect` should be instructed to synthesize the final requirements and write them to a temporary state file (or `engram` node), and the `planner` should be explicitly instructed to read that node. 

## 3. Recommended Adjustments

To make this prompt safe to execute within the current `gemini-cli-template` repository, the following revisions are strictly necessary:

1. **Replace Chat Saving with MCP:** Reject the `/chat save` tracking mechanism. Instruct the Architect and Planner to log their states to `engram`.
2. **Enforce Glass Box Policies:** Mandate that all three agents must include `@../policies/guardrails.toml` and output `Meta-Commentary` before execution.
3. **Cap the Architect:** explicitly limit the Architect to a single, multi-part interview response, rather than an unbounded interview phase.
4. **State Handoff:** Ensure the Architect concludes by formulating a final `Spec` payload that the Planner natively reads, ensuring stateless transitions between subagents.
