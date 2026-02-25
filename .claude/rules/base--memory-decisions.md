---
description: Past decisions with dates for consistency
---

# Decision Log

<!-- Claude: When a decision is made, add an entry with the date. -->
<!-- Format: -->
<!-- ## YYYY-MM-DD: Short title -->
<!-- **Decision:** What was decided -->
<!-- **Rationale:** Why this choice was made -->
<!-- **Alternatives considered:** What else was on the table -->

<!-- Entries below, newest first -->

## 2026-02-25: README as overview, GUIDE as walkthrough — deduplicate docs
**Decision:** Slim README.md to be a quick-reference overview with short summaries and links to GUIDE.md for detailed walkthroughs. Remove duplicated content (env vars table, custom overlays, migration steps) from README.
**Rationale:** First-time users were overwhelmed by README's length and confused by seeing the same content in two places. README should answer "what is this and should I use it?" while GUIDE answers "how do I use it?"
**Alternatives considered:** Could have kept everything in README and removed GUIDE, but the guide's procedural depth (flag examples, detection signals, dry-run) doesn't belong in a project overview.

## 2026-02-24: Assemble test secrets at runtime to avoid tripping pre-commit hook
**Decision:** Test files that exercise secret detection must assemble secret-like strings at runtime via helper functions (e.g. `_make_aws_key`), not embed them as literals.
**Rationale:** The pre-commit-safety hook scans all staged files including test files. Embedding literal patterns like `AKIA...` or `ghp_...` in test source would cause the hook to block its own test file from being committed.
**Alternatives considered:** Could have excluded test files from hook scanning, but that creates a security gap — real secrets in test files should still be caught.

## 2026-02-24: Use file --mime for binary detection in hooks (not file | grep text)
**Decision:** Use `file --mime "$file" | grep -q "charset=binary"` to detect binary files, instead of `file "$file" | grep -q "text"`.
**Rationale:** `file` identifies PEM keys and other structured text files by format name (e.g. "PEM RSA private key") rather than "text". The `--mime` approach correctly identifies these as non-binary so secret patterns get scanned.
**Alternatives considered:** Could have added specific format names to the grep check, but `--mime` is more general and future-proof.

## 2026-02-24: Use grep -E with -- for portable secret scanning
**Decision:** Secret patterns use `grep -Eq -- "$pattern"` (POSIX ERE with option terminator) instead of `grep -Pq`.
**Rationale:** `grep -P` requires PCRE support (unavailable on macOS default grep). POSIX ERE covers the needed patterns. The `--` prevents patterns starting with `-` from being parsed as options.
**Alternatives considered:** Could detect and fall back to `ggrep`/`ripgrep`, but POSIX ERE equivalents cover all current patterns without extra dependencies.

## 2026-02-24: Stop hooks must use "block" (not "approve") to trigger Claude action
**Decision:** Stop hooks that need Claude to act (e.g., update memory files) must return `{"decision": "block", "reason": "..."}`. Using `"approve"` with `"systemMessage"` is display-only — Claude's turn is already over and it never acts on the message.
**Rationale:** The `systemMessage` field in an `"approve"` response is informational only; it does not give Claude another turn. Only `"block"` forces a new turn where Claude can call tools.
**Alternatives considered:** Could have used a PreToolUse hook instead, but Stop is the correct lifecycle event for end-of-session memory capture.

## 2026-02-24: Stop hooks must check stop_hook_active for loop prevention
**Decision:** Stop hooks that return `"block"` must check the `stop_hook_active` field in their JSON stdin. When `true`, the hook must `exit 0` to break the block-retry loop.
**Rationale:** Without this check, a blocking stop hook creates an infinite loop: block → Claude acts → tries to stop → hook blocks again. Claude Code sets `stop_hook_active: true` on the second invocation specifically for this purpose.
**Alternatives considered:** None — this is the designed loop-prevention mechanism.

## 2026-02-24: Fix deny/allow conflict by removing blanket denies from base settings
**Decision:** Remove `WebFetch` and `Bash(curl:*)` from the base `deny` array and merge domain-scoped allows from `settings.local.json` into the generated settings.
**Rationale:** Claude Code deny rules always win over allow rules. A blanket `"WebFetch"` deny overrides domain-scoped allows like `WebFetch(domain:github.com)`, making them useless.
**Alternatives considered:** Could have removed the allows instead, but the intent was to permit specific domains while blocking unscoped fetch.

## 2026-02-24: Use JSON protocol for Claude Code hooks (not exit codes)
**Decision:** Claude Code hooks must output `{"decision": "approve"}` or `{"decision": "block", "reason": "..."}` as JSON on stdout. Diagnostic messages go to stderr.
**Rationale:** Claude Code ignores exit codes for hook decisions — it reads structured JSON from stdout. Plain-text output corrupts the protocol and causes hooks to silently fail.
**Alternatives considered:** None — this is the required protocol.
