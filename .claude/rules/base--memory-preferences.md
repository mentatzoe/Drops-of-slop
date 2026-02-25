---
description: User preferences for how work should be done
---

# Preferences

<!-- Claude: Update this file whenever the user states a preference. -->
<!-- IMPORTANT: Only record what the user actually said or explicitly agreed with. -->
<!-- Do NOT record Claude's own recommendations or suggestions as user preferences. -->
<!-- "User didn't object" ≠ "user prefers this." -->

## Code Style
<!-- Formatting, naming conventions, patterns they prefer or avoid, etc. -->

## Communication
<!-- Verbosity, explanation depth, tone, whether they want options or decisions, etc. -->
- Short imperative commands like "commit this" or "create a PR" come from Claude Code's CLI suggestions, not personal style — user is conversational and polite
- Open to discussion and choices; doesn't consider clarifying questions a waste of time
- Trusts Claude to execute autonomously on well-scoped plans without asking for confirmation

## Design Philosophy
- Prefers fewer concepts that do more over many specialized concepts — reduce cognitive load for users
- Favors automatic/discoverable behavior over manual invocation patterns (e.g., auto-delegation via description fields rather than requiring users to remember `/command` names)
- Values MECE (Mutually Exclusive, Collectively Exhaustive) categorizations

## Workflow
<!-- How they like to review changes, commit frequency, PR style, etc. -->
- Sometimes merges PRs from the browser before Claude can do it — don't be surprised if a PR is already merged when asked to merge it
- Actively monitors GitHub — reviews PRs and checks in browser
- Cares about new-user experience — reviews docs from a first-timer's perspective, identifies organizational gaps not just content gaps
- Prefers detailed implementation plans before execution — with exact line numbers and specific change descriptions
- Likes structured plan formats: numbered steps with lettered sub-steps (1a, 1b, 1c), file action tables, and verification checklists

## Memory & Automation
- Wants memory updates to happen in real-time during conversation, not just at session end — reduce post-session overhead

## Tools & Environment
<!-- Preferred tools, package managers, test runners, linters, etc. -->
