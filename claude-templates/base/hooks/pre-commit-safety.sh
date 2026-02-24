#!/usr/bin/env bash
# Pre-commit hook: scan staged files for secrets and credentials.
# This is a Claude Code PreToolUse hook — outputs JSON protocol.
# Outputs {"decision": "approve"} or {"decision": "block", "reason": "..."} on stdout.
# Diagnostic messages go to stderr.

set -euo pipefail

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)

if [ -z "$STAGED_FILES" ]; then
  echo '{"decision": "approve"}'
  exit 0
fi

# Patterns that indicate hardcoded secrets (POSIX ERE — no grep -P dependency)
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                                              # AWS Access Key ID
  '(api[_-]?key|apikey)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9+/=]{20,}'  # Generic API key assignment (case-sensitive — broad enough)
  '(secret|password|passwd|token|SECRET|PASSWORD|PASSWD|TOKEN)[[:space:]]*[:=][[:space:]]*["'"'"'][^[:space:]"'"'"']{8,}'  # Secret/password/token assignment
  '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----'                   # Private keys
  'ghp_[A-Za-z0-9]{36}'                                           # GitHub personal access token
  'sk-[A-Za-z0-9]{32,}'                                           # OpenAI/Anthropic style API key
  'xox[baprs]-[A-Za-z0-9-]{10,}'                                  # Slack tokens
)

FOUND_SECRETS=0
BLOCKED_FILES=""

for file in $STAGED_FILES; do
  # Skip truly binary files (images, executables, archives, etc.)
  # Use --mime to reliably detect binary vs text-like content
  if file --mime "$file" 2>/dev/null | grep -q "charset=binary"; then
    continue
  fi

  for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -Eq -- "$pattern" "$file" 2>/dev/null; then
      echo "BLOCKED: Potential secret found in $file (pattern: $pattern)" >&2
      BLOCKED_FILES="$BLOCKED_FILES $file"
      FOUND_SECRETS=1
    fi
  done
done

# Also check for .env files that shouldn't be committed
for file in $STAGED_FILES; do
  if [[ "$file" =~ \.env($|\.) ]] && [[ "$file" != ".env.example" ]]; then
    echo "BLOCKED: Environment file staged for commit: $file" >&2
    BLOCKED_FILES="$BLOCKED_FILES $file"
    FOUND_SECRETS=1
  fi
done

if [ "$FOUND_SECRETS" -eq 1 ]; then
  echo "{\"decision\": \"block\", \"reason\": \"Potential secrets detected in staged files:${BLOCKED_FILES}. Remove secrets and use environment variables instead.\"}"
  exit 0
fi

echo '{"decision": "approve"}'
exit 0
