# README vs. Reality: Documentation Audit

This document provides an audit of `README.md` compared to the actual state of the `gemini-cli-template` repository. The goal is to identify discrepancies, missing components, and unclear instructions that would prevent a user from successfully utilizing the template.

## 1. Critical Structural Discrepancies (The "Base + Overlays" Illusion)

The README heavily advertises a "Base + Overlays" composable file system architecture. However, the physical repository **does not contain this structure**.

*   **Missing Directories:** The `base/` and `overlays/` folders do not exist.
*   **Missing Activation Scripts:** `activate.sh` and `deactivate.sh` are not present in the repository root.
*   **Monolithic `.gemini/`:** Instead of a dynamic, composable setup, all rules, hooks (e.g., `block-secrets.sh`, `audit-logger.sh`), and agents are hardcoded directly into a monolithic `.gemini/` configuration directory. 
*   **Agent Clutter:** The README claims overlays provide specialized agents for domains like `web-dev` or `obsidian-pkm`. In reality, all 14+ specialized personas (`android-engineer.md`, `game-designer.md`, `lore-master.md`, etc.) are dumped simultaneously into `.gemini/agents/`. This completely defeats the "prevent context bloat" promise of the overlays architecture.

## 2. Missing Prerequisites & Installation Steps

The README explains the philosophy but fails to explain *how to actually run the software*.

*   **Gemini CLI:** No mention of how to install or invoke the Gemini CLI itself.
*   **MCP Servers:** The `settings.json` file registers 18 different MCP servers (GitHub, Figma, Vercel, Engram, Obsidian, etc.). The README fails to instruct the user to run `npm install` or ensure `npx` is available to execute these external binaries. The memory protocol relies entirely on `engram:mem_save`, but there are no instructions on how to initialize the Engram local database.

## 3. Ambiguous Usage Instructions

*   **Triggering the Workflow:** The README explains the 3-stage autonomous pipeline (Architect -> Planner -> Implementer) but never shows the user the actual command to start it. 
    *   *Need to add:* `gemini chat --agent architect` or an explicit user prompt instruction.
*   **Approval Mechanic:** It says the Planner "pauses for your approval", but doesn't explain *how* the user approves it (e.g., typing "Looks good, proceed" in the CLI, or modifying `.gemini/active-plan.md` manually).

## 4. Recommendations for Remediation

To fix these gaps, you must choose one of two paths:

**Path A (Fix the Code to match the README):**
1. Move the core `.gemini/` files into a new `base/` directory.
2. Group the specialized agents into `overlays/web-dev/`, `overlays/game-dev/`, etc.
3. Re-implement the `activate.sh` and `deactivate.sh` symlink scripts.

**Path B (Fix the README to match the Code):**
1. Remove all mentions of "Base + Overlays" and `activate.sh`.
2. Document the repository as a "Monolithic JIT-Routed" template, where `GEMINI.md` handles all delegation without physical file swapping.

**Universal Requirements:**
*   Add an "Installation & Prerequisites" section detailing Node.js, `npx`, and Gemini CLI requirements.
*   Add a "Quick Start" section with explicit CLI commands (e.g., `gemini chat "I want to build a new feature"`).
