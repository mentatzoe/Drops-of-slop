#!/usr/bin/env bash

# writing-audit.sh
# Heuristic scanner for AI-style puffery and over-formatting.
# Use this as a fast first-pass before applying nuanced skill-based review.

FILE=$1
if [ -z "$FILE" ]; then
    echo "Usage: sh writing-audit.sh <file>"
    exit 1
fi

if [ ! -f "$FILE" ]; then
    echo "❌ Error: File $FILE not found."
    exit 1
fi

echo "🔍 Auditing: $FILE"
echo "-----------------------------------"

# 1. Puffery Detection (Forbidden LLM Vocabulary)
PUFF_WORDS=("pivotal" "seamless" "leverage" "cutting-edge" "groundbreaking" "delve" "testament" "showcase" "ensuring" "highlighting" "robust" "multifaceted" "realm" "tapestry")
FOUND_PUFF=()

for word in "${PUFF_WORDS[@]}"; do
    if grep -qi "$word" "$FILE"; then
        FOUND_PUFF+=("$word")
    fi
done

if [ ${#FOUND_PUFF[@]} -gt 0 ]; then
    echo "⚠️  Found Puffery / AI-Style Words:"
    for w in "${FOUND_PUFF[@]}"; do
        echo "   - $w (Line: $(grep -ni "$w" "$FILE" | head -n 1 | cut -f1 -d:))"
    done
    echo ""
fi

# 2. Formatting Noise (Bolded headers in short lists)
# Matches patterns like "- **Text**:" or "1. **Text**:"
NOISE=$(grep -nE "^[ ]*([-*]|[0-9]+\.) \*\*.*\*\*[:]" "$FILE" || true)

if [ -n "$NOISE" ]; then
    echo "⚠️  Potential Formatting Noise (Bolded list headers):"
    echo "$NOISE" | sed 's/^/   /'
    echo "   (Note: Review if this aids legibility or just adds clutter.)"
    echo ""
fi

# 3. Conciseness Check (Success/Intentionally/Out of the box)
NeedlessWords=("successfully" "intentionally" "out of the box" "designed to" "aims to")
for word in "${NeedlessWords[@]}"; do
    if grep -qi "$word" "$FILE"; then
        echo "⚠️  Needless Word Detected: '$word'"
    fi
done

echo "-----------------------------------"
echo "✅ Audit Complete. Apply professional judgment and Strunk's rules to refine."
