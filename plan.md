# Plan: Modular Memory System

## Overview

Adapt the "split memory files + auto-update instructions + Stop hook" pattern from the inspiration comment into the existing claude-templates architecture. The template already has `.claude/rules/` as its composition mechanism and a base CLAUDE.md router — this plan extends it with dedicated memory files, auto-update instructions, and a learning-capture Stop hook.

## What changes and what doesn't

The template already follows the "CLAUDE.md as router, rules directory carries the weight" philosophy. The inspiration comment's pattern fits naturally: memory files become new rule files in the base layer, the CLAUDE.md gets a mandatory auto-update section, and the Stop hook becomes a new hook alongside the existing `pre-commit-safety.sh`.

---

## Step 1: Create four memory rule files in `base/rules/`

Create the following files in `claude-templates/base/rules/`:

### `memory-profile.md`
- YAML frontmatter: `description: Persistent facts about the user and project`
- Initial structure with sections: Identity, Environment, Project Context
- Includes placeholder comments indicating Claude should fill these in
- Prefixed `base--memory-profile.md` when symlinked by activate.sh (already handled)

### `memory-preferences.md`
- YAML frontmatter: `description: User preferences for how work should be done`
- Sections: Code Style, Communication, Workflow, Tools & Environment
- Empty/placeholder sections for Claude to populate

### `memory-decisions.md`
- YAML frontmatter: `description: Past decisions with dates for consistency`
- Format template showing date + decision + rationale structure
- Initially empty log section

### `memory-sessions.md`
- YAML frontmatter: `description: Rolling summary of recent work sessions`
- Format template showing date + summary + outcomes structure
- Cap guidance: keep only last 10 sessions, prune oldest entries

These replace the generic "Knowledge Externalization" bullet points currently in `memory-management.md`. The existing `memory-management.md` remains but gets updated to reference these new files and focus on context hygiene (its real purpose).

## Step 2: Update `base/rules/memory-management.md`

- Remove the generic "Knowledge Externalization" section (now handled by the dedicated memory files)
- Add a new section "Memory Files" that lists the four memory-*.md files and their purposes
- Keep the Context Hygiene, When to Persist vs. Discard, and Compact Discipline sections intact

## Step 3: Add mandatory auto-update section to `base/CLAUDE.md`

Add a `## Auto-Update Memory (MANDATORY)` section to the base CLAUDE.md. Key elements from the inspiration:

```markdown
## Auto-Update Memory (MANDATORY)

Update memory files AS YOU GO, not at the end. When you learn something new, update immediately.

| Trigger | Action |
|---------|--------|
| User shares a fact about themselves | → Update memory-profile.md |
| User states a preference | → Update memory-preferences.md |
| A decision is made | → Update memory-decisions.md with date |
| Completing substantive work | → Add to memory-sessions.md |

Skip: Quick factual questions, trivial tasks with no new info.

DO NOT ASK. Just update the files when you learn something.
```

This fits within the ~60-80 line target. The current CLAUDE.md is 58 lines, adding ~15 lines keeps it under 75 — well within the 150-line ceiling.

## Step 4: Create Stop hook for learning capture

Create `base/hooks/stop-learning-capture.sh`:

- Reads conversation context from stdin
- Pattern-matches for strong signals (fixed, workaround, gotcha, discovered, realized, turns out) and weak signals (error, bug, issue, problem, fail)
- Strong match: returns `{"decision": "approve", "systemMessage": "..."}` nudging to capture learnings
- Weak match: returns softer nudge
- No match: returns plain approve
- Adapted from the inspiration but integrated with the template's existing hook style (set -euo pipefail, consistent formatting)

## Step 5: Register the Stop hook in `base/settings.json`

Add a `hooks` section to the base settings.json:

```json
{
  "permissions": { ... },
  "hooks": {
    "Stop": [{
      "matcher": "",
      "hooks": [{
        "type": "command",
        "command": ".claude/hooks/stop-learning-capture.sh"
      }]
    }]
  }
}
```

**Note:** The existing activate.sh already copies hooks from `base/hooks/` to the target project's `.claude/hooks/` and generates settings — but it only copies hooks and doesn't wire them into settings.json. The settings merge script will handle this since hooks are now in base settings.json.

## Step 6: Update `activate.sh` to handle memory files specially

The memory-*.md files need to be **copied** (not symlinked) to target projects, because Claude needs to edit them in-place during sessions. Symlinked files would modify the template source, which is wrong.

Add logic after the existing base rules symlinking to:
- Copy (not symlink) any `base/rules/memory-*.md` files to the target
- Skip symlinking those same files (they were already copied)
- Track copied memory files in the activation state

## Step 7: Update documentation

Update `claude-templates/README.md` to document:
- The memory system (what the four files are, how auto-update works)
- The Stop hook behavior
- That memory files are copied (not symlinked) so they're project-specific

---

## Files to create
1. `claude-templates/base/rules/memory-profile.md`
2. `claude-templates/base/rules/memory-preferences.md`
3. `claude-templates/base/rules/memory-decisions.md`
4. `claude-templates/base/rules/memory-sessions.md`
5. `claude-templates/base/hooks/stop-learning-capture.sh`

## Files to modify
1. `claude-templates/base/CLAUDE.md` — add auto-update memory section
2. `claude-templates/base/rules/memory-management.md` — update to reference memory files
3. `claude-templates/base/settings.json` — add Stop hook registration
4. `claude-templates/activate.sh` — copy (not symlink) memory files
5. `claude-templates/README.md` — document the memory system

## Design decisions

**Why copy instead of symlink for memory files?** Memory files are meant to be edited by Claude during sessions. Symlinks would mutate the template source, contaminating it with project-specific data. Copies let each project maintain its own memory.

**Why keep memory-management.md?** It serves a different purpose — context hygiene and compaction discipline. The memory-*.md files are for _persistent knowledge_; memory-management.md is for _session behavior_.

**Why not a `/reflect` skill?** The inspiration comment mentions `/reflect` but we can add that as a follow-up. The core system (auto-update + Stop hook) covers the primary use case. A `/reflect` skill that explicitly reviews the session and updates memory files would be a natural extension.
