# Usage Guide

This guide covers the procedures for working with claude-templates. For architecture details and reference tables, see `README.md`.


## Installation

### Remote install (recommended)

```bash
curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/claude-templates/install.sh | bash
```

This downloads the latest `claude-templates/` directory into `~/.claude-templates` and makes all scripts executable.

### Custom install location

Set `CLAUDE_TEMPLATES_HOME` before running the installer:

```bash
CLAUDE_TEMPLATES_HOME=~/my-tools/claude-templates \
  curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/claude-templates/install.sh | bash
```

### Version pinning

Install a specific branch or tag with `CLAUDE_TEMPLATES_REF`:

```bash
CLAUDE_TEMPLATES_REF=v1.0.0 \
  curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/claude-templates/install.sh | bash
```

### Update

Re-run the installer. It replaces the existing installation in place:

```bash
curl -fsSL https://raw.githubusercontent.com/mentatzoe/Drops-of-slop/main/claude-templates/install.sh | bash
```

### Manual install (git clone)

If you prefer to clone the full repository:

```bash
git clone https://github.com/mentatzoe/Drops-of-slop.git
cd Drops-of-slop/claude-templates
./activate.sh ~/my-project web-dev
```

### Uninstall

```bash
rm -rf ~/.claude-templates
```

> **Note:** All examples in this guide use relative paths (e.g., `./activate.sh`). If you used the remote installer, replace `./` with `~/.claude-templates/` (or your custom install path).


## Set Up a New Project

Activate one or more overlays on a project that has no existing Claude configuration.

Single overlay:

```bash
./activate.sh ~/my-project web-dev
```

Multiple overlays:

```bash
./activate.sh ~/my-project web-dev quality-assurance
```

The script checks for conflicts before activating. For example, `web-dev` and `android-dev` conflict — the script exits with an error if you request both. Dependencies resolve automatically: if an overlay declares a `depends` field, those overlays are included without you listing them.

Activation creates symlinks for rules, skills, commands, and agents; merges MCP and settings configs; copies memory files (only if they don't already exist); and generates `CLAUDE.md`.


## Use a Pre-Built Composition

A composition is a named set of overlays. Use one instead of listing overlays individually:

```bash
./activate.sh ~/my-project --composition fullstack-web
```

Five compositions are available:

| Composition | Overlays | Purpose |
|---|---|---|
| `fullstack-web` | web-dev, quality-assurance | Full-stack web development with QA |
| `android-app` | android-dev, quality-assurance | Android development with testing |
| `creative-worldbuilding` | worldbuilding, knowledge-management | Worldbuilding with knowledge management |
| `ai-project` | ai-research, research | ML projects with literature review |
| `obsidian-vault` | knowledge-management, wiki-management | Obsidian vault with wiki management |


## Create a Custom Composition

A composition is a JSON file in `compositions/` that bundles overlays under a name. Create one when you have a recurring overlay combination.

### 1. Write the JSON file

Create `compositions/my-combo.json` with three fields:

```json
{
  "name": "my-combo",
  "description": "Short description of what this combination is for",
  "overlays": ["web-dev", "quality-assurance"]
}
```

- `name` — must match the filename (without `.json`)
- `description` — displayed in `--help` output
- `overlays` — array of overlay names to activate together

### 2. Test it

```bash
./activate.sh ~/my-project --composition my-combo
```

The script resolves dependencies and checks for conflicts the same way it does with individual overlays. If two overlays in your composition conflict, activation fails with an error.

### 3. Validate overlays don't conflict

Check the `conflicts` field in each overlay's `overlay.json`. For example, `web-dev` and `android-dev` conflict — a composition including both would always fail.

> **Note:** Compositions don't need to be registered in `manifest.json`. `activate.sh` reads directly from the `compositions/` directory.


## Add External Components

External components come from the [aitmpl.com catalog](https://github.com/davila7/claude-code-templates). Three ways to install them:

### During activation

Install all recommended externals for the selected overlays:

```bash
./activate.sh ~/my-project web-dev --with-externals
```

Install a specific component by type and path:

```bash
./activate.sh ~/my-project web-dev --external agent development-team/frontend-developer
```

Component types: `agent`, `command`, `skill`, `mcp`, `hook`, `setting`.

### After activation

Use `fetch-external.sh install` with the same type flags:

```bash
./scripts/fetch-external.sh install ~/my-project --agent development-team/frontend-developer
./scripts/fetch-external.sh install ~/my-project --command testing/generate-tests
./scripts/fetch-external.sh install ~/my-project --skill development/frontend-dev-guidelines
```

Install all overlay-recommended externals at once:

```bash
./scripts/fetch-external.sh install ~/my-project --recommended
```

Installed components get an `ext--` prefix to distinguish them from local files.

### Browse the catalog

List all available components:

```bash
./scripts/fetch-external.sh catalog
```

Filter by type:

```bash
./scripts/fetch-external.sh catalog --type agent
```

Search by name or category:

```bash
./scripts/fetch-external.sh catalog --search frontend
```


## Remove External Components

Remove a component by type and name (not the full category/name path):

```bash
./scripts/fetch-external.sh remove ~/my-project --agent frontend-developer
./scripts/fetch-external.sh remove ~/my-project --command generate-tests
```


## Migrate an Existing Project

For projects that already have `CLAUDE.md`, `.claude/`, or `.mcp.json`.

### Interactive mode (default)

```bash
./migrate.sh ~/my-project
```

The script analyzes your project, suggests overlays based on detected frameworks and tools, and asks you to confirm before applying changes.

### Auto-detect mode

Accept the detected overlays without confirmation:

```bash
./migrate.sh ~/my-project --auto
```

Detection signals include `package.json` with React/Next.js (suggests `web-dev`), `build.gradle` with Android plugin (suggests `android-dev`), `.obsidian/` directory (suggests `knowledge-management`), test configs like jest or pytest (suggests `quality-assurance`), and others.

### Manual overlay selection

Override auto-detection with specific overlays:

```bash
./migrate.sh ~/my-project --overlays web-dev quality-assurance
```

Or use a composition:

```bash
./migrate.sh ~/my-project --composition fullstack-web
```

### Dry run

Preview what the migration would change without modifying anything:

```bash
./migrate.sh ~/my-project --dry-run
```

### What gets preserved

Your existing work is not discarded:

- Custom rules are renamed with a `custom--` prefix (e.g., `my-rules.md` becomes `custom--my-rules.md`) and continue to load.
- Custom MCP servers are merged with overlay servers in `.mcp.json`.
- Custom `CLAUDE.md` content is preserved under a `## Project-Specific` section.
- Custom hooks are renamed with a `custom-` prefix if they conflict with template hooks.
- Custom skills and commands are left in place.

### What gets backed up

Before migration, the script backs up your existing configuration to `.claude/.migration-backup/<timestamp>/`. This includes `CLAUDE.md`, `.mcp.json`, and `.claude/` contents.

Change the backup location with `--backup-dir`:

```bash
./migrate.sh ~/my-project --backup-dir ~/backups/my-project
```

Skip the backup with `--no-backup` (useful when re-running after fixes):

```bash
./migrate.sh ~/my-project --no-backup
```

Other flags: `--force` re-migrates an already-migrated project, `--verbose` shows detailed output including detection signals.


## Deactivate

Remove all template files from a project:

```bash
./deactivate.sh ~/my-project
```

**Removed**: symlinked rules, skills, commands, and agents; generated `.mcp.json`, `.claude/settings.json`, and `CLAUDE.md`; activation state file; installed external components.

**Preserved**: user-created custom rules, skills, commands, and hooks; memory files; all project source code.

For migrated projects, deactivation also restores custom-prefixed rules to their original names and shows the migration backup location for full restoration.


## Refresh After Updates

After pulling template updates (re-running the installer) or modifying overlay definitions, run `refresh.sh` to synchronize your project:

```bash
./refresh.sh ~/my-project
```

### What it does

1. Re-creates all symlinks (rules, skills, commands, agents) from the recorded overlay set
2. Re-merges MCP and settings configs
3. Cleans stale or broken symlinks from removed/renamed overlays
4. Updates the activation state file with the new template version

### What it preserves

Refresh never touches user-editable content:

- Memory files (`base--memory-*.md`)
- Custom rules (`custom--*` prefix)
- External components (`ext--*` prefix)
- `CLAUDE.md`
- Hook modifications (warns if a hook differs from the template)

### Refresh all projects

If you have multiple activated projects, refresh them all at once:

```bash
./refresh.sh --all
```

This reads from the `.known-projects` registry (populated automatically during activation).

### Dry run

Preview what refresh would change without modifying anything:

```bash
./refresh.sh --dry-run ~/my-project
./refresh.sh --dry-run --all
```

### Refresh vs. re-activate

`refresh.sh` is lighter than re-running `activate.sh` — it skips conflict checks and dependency resolution, and re-links from the previously recorded overlay set. Use it after template updates. Use `activate.sh` when you want to change which overlays are active.


## Create a Custom Overlay

### 1. Create the directory structure

```
overlays/my-overlay/
├── overlay.json
├── rules/
│   └── my-rule.md
├── skills/
│   └── my-skill/
│       └── SKILL.md
├── commands/
│   └── my-command.md
└── mcp.json
```

Only `overlay.json` and at least one rule file are required. The other directories are optional.

### 2. Write overlay.json

```json
{
  "name": "my-overlay",
  "description": "Short description of what this overlay provides.",
  "conflicts": [],
  "depends": [],
  "mcp_servers": [],
  "recommended_external": {}
}
```

Required fields: `name` (must match the directory name), `description`, `conflicts`, `depends`.

Set `conflicts` to overlays that are incompatible with yours. Set `depends` to overlays that should auto-activate alongside yours.

### 3. Write rule files with YAML frontmatter

```markdown
---
description: What this rule covers
paths:
  - "src/**/*.ts"
  - "**/*.config.js"
---

# Rule Title

Rule content here. Keep rules between 15 and 30 lines.
```

The `paths` field scopes the rule to matching files. Claude loads path-scoped rules only when working on files that match the globs.

### 4. Write skill files (optional)

Create a subdirectory under `skills/` with a `SKILL.md`:

```markdown
---
name: my-skill
description: What this skill does
mode: true
allowed-tools:
  - Read
  - Grep
  - Glob
---

# My Skill

Skill instructions here.
```

### 5. Register in manifest.json

Add your overlay to the top-level `manifest.json`:

```json
{
  "overlays": {
    "my-overlay": {
      "description": "Short description.",
      "conflicts": [],
      "depends": [],
      "mcp_servers": []
    }
  }
}
```

### 6. Validate

```bash
./scripts/validate-overlay.sh overlays/my-overlay manifest.json
```

The validator checks that `overlay.json` is valid, required fields are present, the name matches the directory, rules have proper frontmatter, skills have `SKILL.md`, MCP configs use `${ENV_VAR}` syntax instead of hardcoded secrets, the overlay is registered in the manifest, and recommended externals exist in the catalog.


## Sync the External Catalog

Refresh the cached catalog from GitHub:

```bash
./scripts/fetch-external.sh sync-catalog
```

This downloads the latest component list into `external-catalog.json`. Components themselves are cached in `cache/` after first download.

Set `GITHUB_TOKEN` for higher API rate limits:

```bash
export GITHUB_TOKEN=ghp_...
./scripts/fetch-external.sh sync-catalog
```


## Environment Variables

Set these before running `activate.sh` or `migrate.sh`. The scripts substitute `${VAR}` references in MCP configs with your environment values.

| Variable | Overlay | Purpose |
|---|---|---|
| `BRAVE_API_KEY` | research | Brave Search MCP server |
| `EXA_API_KEY` | research | Exa search MCP server |
| `HUGGINGFACE_TOKEN` | ai-research | HuggingFace API access |
| `OBSIDIAN_REST_API_KEY` | knowledge-management, worldbuilding | Obsidian vault REST API |
| `MEDIAWIKI_URL` | worldbuilding, wiki-management | MediaWiki instance URL |
| `MEDIAWIKI_BOT_USERNAME` | worldbuilding, wiki-management | Wiki bot credentials |
| `MEDIAWIKI_BOT_PASSWORD` | worldbuilding, wiki-management | Wiki bot credentials |
| `ANDROID_HOME` | android-dev | Android SDK path |
| `GITHUB_TOKEN` | fetch-external.sh | GitHub API rate limits (optional) |


## Troubleshooting

### Overlay conflict error

**Cause:** Two requested overlays declare each other in their `conflicts` field.

**Fix:** Choose one or the other. Check each overlay's `overlay.json` to see what it conflicts with:

```bash
cat overlays/<overlay-name>/overlay.json | python3 -c "import json,sys; print(json.load(sys.stdin).get('conflicts', []))"
```

### Missing environment variable warning during activation

**Cause:** An MCP config references `${VAR}` but the variable isn't set in your shell.

**Fix:** Export the variable before running `activate.sh`:

```bash
export BRAVE_API_KEY=your-key-here
./activate.sh ~/my-project research
```

See the [Environment Variables](#environment-variables) table for the full list.

### Broken symlinks after template update

**Cause:** Template files were moved or renamed in a newer version.

**Fix:** Run `refresh.sh` to re-create symlinks from the updated templates:

```bash
./refresh.sh ~/my-project
```

### Activation state file missing

**Cause:** `.claude/.activated-overlays.json` was deleted manually.

**Fix:** Re-run `activate.sh` with the same overlays you originally used. The script regenerates the state file.

### Permission denied on hooks

**Cause:** Hook scripts lost their executable bit.

**Fix:**

```bash
chmod +x ~/my-project/.claude/hooks/*.sh
```

### MCP server not loading

**Cause:** The MCP config wasn't generated, or required environment variables are missing.

**Fix:**

1. Verify `.mcp.json` exists in your project root — if not, re-run `activate.sh`
2. Check that required environment variables are set (e.g., `echo $BRAVE_API_KEY`)
3. Run `claude mcp list` to confirm Claude Code sees the configured servers

### Memory files not updating between sessions

**Cause:** The stop hook isn't registered or `jq` isn't installed.

**Fix:**

1. Check that `stop-learning-capture.sh` is listed under `hooks` in `.claude/settings.json`
2. Verify `jq` is installed: `jq --version` (install with `apt install jq` or `brew install jq`)
3. Re-run `activate.sh` or manually copy the hook from the template:
   ```bash
   cp ~/.claude-templates/base/hooks/stop-learning-capture.sh ~/my-project/.claude/hooks/
   chmod +x ~/my-project/.claude/hooks/stop-learning-capture.sh
   ```
