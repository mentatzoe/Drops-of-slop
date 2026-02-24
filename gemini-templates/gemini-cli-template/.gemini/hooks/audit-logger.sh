#!/usr/bin/env bash
# hook: AfterTool
# Emits audit logs to a secure internal path for forensic analysis

TIMESTAMP=$(date +"%Y-%m-%dT%H:%M:%SZ")
TOOL_NAME="$1"
shift

echo "[$TIMESTAMP] Executed Tool: $TOOL_NAME | Context: $@" >> .gemini/audit.log

cat <<EOF
{
  "decision": "allow"
}
EOF
exit 0
