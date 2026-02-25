# Changelog

All notable changes to claude-templates will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-25

### Added
- `refresh.sh` — post-update project refresh without data loss
- Version tracking: `VERSION` file, `schema_version` in state files
- `install.sh` now detects existing installations and shows update summary
- `.known-projects` registry for `refresh.sh --all`
- `scripts/migrate-state.py` — idempotent state file schema migrator

### Changed
- `install.sh` uses atomic swap instead of `rm -rf` for safe updates
- State file schema bumped to v2 (backward compatible)
- `activate.sh` and `migrate.sh` now write `schema_version`, `template_version`, `activated_at` to state
- State-reading scripts (`deactivate.sh`, `fetch-external.sh`, `browse-catalog.sh`) auto-migrate state on read

## [1.0.0] - 2026-02-22

Initial release with overlay system, external components, migration support.

### Added
- Base layer with rules, memory files, hooks, and CLAUDE.md template
- 10 overlay configurations (web-dev, android-dev, gamedev, ai-research, uxr, quality-assurance, research, knowledge-management, worldbuilding, wiki-management)
- 5 pre-built compositions (fullstack-web, android-app, creative-worldbuilding, ai-project, obsidian-vault)
- 6 agents (strict-reviewer, pair-programmer, research-analyst, creative-writer, architect, worldbuilder)
- `activate.sh` — symlink base + overlays into projects
- `deactivate.sh` — clean removal preserving user files
- `migrate.sh` — migrate existing projects with auto-detection
- `install.sh` — remote installer via curl | bash
- External component system with `fetch-external.sh` and `browse-catalog.sh`
- Deep-merge for MCP and settings configurations
