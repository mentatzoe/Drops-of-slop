#!/usr/bin/env bash
# hook: BeforeTool
# Strict JSON Compliance: Outputs purely valid JSON to stdout. Logs go to stderr.
# Idiomatic Blocking: Exit Code 0 with "decision": "deny" on failure so the LLM can see the reason.

echo "DEBUG: Scanning arguments in BeforeTool hook..." >&2

for arg in "$@"; do
  if [[ "$arg" =~ (AIza[0-9a-zA-Z_\\-]{35}|sk-[a-zA-Z0-9]{48}|ghp_[a-zA-Z0-9]{36}|dapi-[a-zA-Z0-9]{32}) || "$arg" =~ \.env ]]; then
    echo "DEBUG: Secret regex matched." >&2
    # Output idiomatic blocking JSON format to stdout:
    cat <<EOF
{
  "decision": "deny",
  "reason": "Security violation: Blocked by 'block-secrets.sh' hook. Secret or .env reference detected."
}
EOF
    exit 0
  fi
done

echo "DEBUG: No secrets detected." >&2
# Output allow signal
cat <<EOF
{
  "decision": "allow"
}
EOF
exit 0
