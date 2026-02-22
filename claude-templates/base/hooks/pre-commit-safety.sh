#!/usr/bin/env bash
# Pre-commit hook: scan staged files for secrets and credentials.
# Exit code 2 = unconditional block (cannot be overridden).
# This is a Claude Code hook — runs automatically before commits.

set -euo pipefail

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
  exit 0
fi

# Patterns that indicate hardcoded secrets
SECRET_PATTERNS=(
  'AKIA[0-9A-Z]{16}'                          # AWS Access Key ID
  '(?i)(api[_-]?key|apikey)\s*[:=]\s*["\x27][A-Za-z0-9+/=]{20,}'  # Generic API key assignment
  '(?i)(secret|password|passwd|token)\s*[:=]\s*["\x27][^\s"'\'']{8,}'  # Secret/password/token assignment
  '-----BEGIN (RSA |EC |DSA )?PRIVATE KEY-----' # Private keys
  'ghp_[A-Za-z0-9]{36}'                       # GitHub personal access token
  'sk-[A-Za-z0-9]{32,}'                       # OpenAI/Anthropic style API key
  'xox[baprs]-[A-Za-z0-9-]{10,}'              # Slack tokens
)

FOUND_SECRETS=0

for file in $STAGED_FILES; do
  # Skip binary files and this hook itself
  if ! file "$file" | grep -q "text"; then
    continue
  fi

  for pattern in "${SECRET_PATTERNS[@]}"; do
    if grep -Pq "$pattern" "$file" 2>/dev/null; then
      echo "BLOCKED: Potential secret found in $file (pattern: $pattern)"
      FOUND_SECRETS=1
    fi
  done
done

# Also check for .env files that shouldn't be committed
for file in $STAGED_FILES; do
  if [[ "$file" =~ \.env($|\.) ]] && [[ "$file" != ".env.example" ]]; then
    echo "BLOCKED: Environment file staged for commit: $file"
    FOUND_SECRETS=1
  fi
done

if [ "$FOUND_SECRETS" -eq 1 ]; then
  echo ""
  echo "Commit blocked: potential secrets detected in staged files."
  echo "Remove the secrets and use environment variables instead."
  exit 2
fi

exit 0
