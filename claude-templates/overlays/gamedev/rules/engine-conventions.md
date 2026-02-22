---
description: Game engine coding conventions and patterns
paths:
  - "**/*.gd"
  - "**/*.cs"
  - "**/*.tscn"
  - "**/*.tres"
  - "**/Scripts/**/*"
---

# Game Engine Conventions

## Scene & Node Architecture
- One script per scene root — child nodes use signals, not direct references
- Prefer composition over inheritance for game entities
- Use scene instancing for reusable prefabs; avoid duplicating node trees
- Name nodes descriptively: `PlayerHealthBar`, not `ProgressBar2`

## Performance
- Avoid per-frame allocations — pool objects for bullets, particles, enemies
- Use spatial partitioning (quadtrees, octrees, built-in physics layers) for collision
- Profile before optimizing — measure frame time, draw calls, physics step cost
- Batch similar draw calls; minimize material and shader switches

## State Management
- Use a finite state machine (FSM) or state chart for entity behavior
- Separate game state (serializable) from presentation state (visual-only)
- Implement save/load through serializable state objects, not scene tree snapshots

## Asset Pipeline
- Source assets (PSD, BLEND, FBX) live in `assets/source/`, not in the engine project
- Exported/optimized assets go in the engine's import directory
- Use consistent naming: `snake_case` for files, `PascalCase` for types
- Document asset specifications: target poly count, texture resolution, animation framerate
