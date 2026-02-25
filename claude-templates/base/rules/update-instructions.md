# Template Update Instructions

## Automatic Local Check

A `prompt-version-check.sh` hook runs once per session at the first user prompt. If the project's `template_version` (stored in `.claude/.activated-overlays.json`) is behind the installed `VERSION`, it injects a reminder. No action needed — this is automatic.

## Check for Remote Updates

To check if a newer version is available upstream:

```bash
# Read the remote VERSION file from GitHub
REMOTE_VERSION=$(curl -fsSL https://raw.githubusercontent.com/mentatzoe/claude-templates/main/VERSION)
LOCAL_VERSION=$(cat <template_dir>/VERSION)
echo "Local: $LOCAL_VERSION  Remote: $REMOTE_VERSION"
```

Replace `<template_dir>` with the value of `template_dir` from `.claude/.activated-overlays.json`.

## Update the Installation

Run the installer to pull the latest templates:

```bash
curl -fsSL https://raw.githubusercontent.com/mentatzoe/claude-templates/main/install.sh | bash
```

This performs an atomic swap — the old installation is replaced safely.

## Refresh the Project

After updating the installation, refresh the project to pick up new rules, hooks, and configs:

```bash
# Single project
<template_dir>/refresh.sh <project-path>

# All known projects
<template_dir>/refresh.sh --all

# Preview changes first
<template_dir>/refresh.sh --dry-run <project-path>
```

## What Refresh Preserves

Refresh never touches user-owned files:

- **Memory files** (`base--memory-*.md`) — your profile, preferences, decisions, session log
- **Custom rules** (`custom--*.md`) — any rules you added manually
- **External components** (`ext--*.md`) — fetched agents, skills, commands
- **CLAUDE.md** — your project-level instructions
- **settings.local.json** — your local settings overrides
