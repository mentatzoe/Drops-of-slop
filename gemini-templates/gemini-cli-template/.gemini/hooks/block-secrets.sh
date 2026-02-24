#!/usr/bin/env bash
# hook: BeforeTool
# ZERO-TRUST POLICY: Fails secure, guarantees idiomatic JSON response.

# Pipe arbitrary output to stderr to preserve stdout for the JSON contract
echo "DEBUG: Entering Zero-Trust BeforeTool Hook..." >&2

for arg in "$@"; do
  # Regex targeting OpenAI, AWS, GitHub, and generic .env calls (excluding .env.example)
  if [[ "$arg" =~ (sk-[a-zA-Z0-9]{48}|AKIA[0-9A-Z]{16}|ghp_[a-zA-Z0-9]{36}) ]] || ( [[ "$arg" =~ \.env ]] && [[ ! "$arg" =~ \.env\.example ]] ); then
    echo "CRITICAL: Secret string intercepted." >&2
    cat <<EOF
{
  "decision": "deny",
  "reason": "SECURITY GUARDRAIL TRIGGERED: Tool blocked by 'block-secrets.sh'. Ensure you are not hardcoding API keys or manipulating .env directly."
}
EOF
    exit 0 # We exit 0 so Gemini gracefully receives the JSON payload, rather than a generic OS crash.
  fi
done

cat <<EOF
{ "decision": "allow" }
EOF
exit 0
