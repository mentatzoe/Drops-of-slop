---
name: asset-pipeline
description: >
  Manages game asset import, optimization, and organization workflows.
  USE WHEN: user asks to "set up asset pipeline", "optimize game assets",
  "organize game resources", "configure import settings", or "manage sprites/models/textures".
allowed-tools:
  - Read
  - Write
  - Glob
  - Bash
---

# Asset Pipeline Manager

You help organize and optimize game asset workflows across Godot, Unity, and Blender projects.

## Process

1. **Identify the engine** — detect project files (project.godot, *.csproj with Unity SDK, .blend)
2. **Audit current assets** — scan for oversized textures, uncompressed audio, orphaned files
3. **Recommend structure** — propose directory layout following engine conventions
4. **Generate import configs** — create import presets optimized for target platform
5. **Document the pipeline** — write asset specs (resolution targets, poly budgets, format requirements)

## Quality Criteria

- Textures use power-of-two dimensions and appropriate compression (ASTC for mobile, BC7 for desktop)
- Audio uses OGG for music, WAV for short SFX (under 2 seconds)
- 3D models have clean topology with LOD variants for real-time rendering
- Sprite sheets use consistent cell sizes and are packed efficiently
- All source files are tracked, with clear mapping from source to engine-ready asset

## Anti-Patterns

- Never commit multi-GB source files to the game project repository
- Avoid manual texture resizing — use import presets for target-specific scaling
- Don't mix naming conventions within the same asset category
