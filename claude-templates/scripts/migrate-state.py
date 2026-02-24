#!/usr/bin/env python3
"""Migrate .activated-overlays.json to current schema. Idempotent.

Usage:
    python3 migrate-state.py <state-file> [--template-version X.Y.Z]

Reads the state file, applies any needed migrations, and writes it back
only if changes were made. Safe to call on every read — no-ops on current schema.
"""

import json
import sys
import os

CURRENT_SCHEMA = 2


def migrate(state, template_version=None):
    """Migrate state dict to current schema. Returns (state, changed)."""
    changed = False
    sv = state.get("schema_version", 1)

    if sv < 2:
        state["schema_version"] = 2
        state.setdefault("template_version", template_version or "1.0.0")
        state.setdefault("activated_at", "unknown")
        state.setdefault("external_components", {})
        changed = True

    # Update template_version if explicitly provided and different
    if template_version and state.get("template_version") != template_version:
        state["template_version"] = template_version
        changed = True

    return state, changed


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <state-file> [--template-version X.Y.Z]", file=sys.stderr)
        sys.exit(1)

    state_file = sys.argv[1]
    template_version = None

    # Parse --template-version flag
    for i, arg in enumerate(sys.argv[2:], start=2):
        if arg == "--template-version" and i + 1 < len(sys.argv):
            template_version = sys.argv[i + 1]
            break

    if not os.path.isfile(state_file):
        sys.exit(0)  # Nothing to migrate

    try:
        with open(state_file) as f:
            state = json.load(f)
    except (json.JSONDecodeError, OSError):
        sys.exit(0)  # Corrupt or unreadable — don't touch it

    state, changed = migrate(state, template_version)

    if changed:
        with open(state_file, "w") as f:
            json.dump(state, f, indent=2)
            f.write("\n")

    sys.exit(0)


if __name__ == "__main__":
    main()
