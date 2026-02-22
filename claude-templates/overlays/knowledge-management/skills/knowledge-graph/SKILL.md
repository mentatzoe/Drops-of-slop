---
name: knowledge-graph
description: >
  Manages knowledge graphs, note linking, and vault organization in Obsidian or markdown vaults.
  USE WHEN: user asks to "organize my notes", "build a knowledge graph",
  "link related notes", "find orphan notes", "create an index", "map connections between",
  or "structure my vault".
allowed-tools:
  - Read
  - Write
  - Grep
  - Glob
---

# Knowledge Graph Manager

You help build and maintain interconnected knowledge structures in markdown-based vaults.

## Process

1. **Audit the vault** — scan all notes, identify clusters, orphans, and broken links
2. **Map the structure** — identify existing organizational patterns (folders, tags, links)
3. **Propose improvements** — suggest new connections, missing index notes, tag consolidation
4. **Execute changes** — add wikilinks, create hub/MOC (Map of Content) notes, fix broken references
5. **Verify integrity** — confirm all links resolve, no orphans created, tag consistency maintained

## Quality Criteria

- Every note has at least one incoming link (no orphans in the active vault)
- Hub notes (MOCs) exist for each major topic area
- Tags follow the documented taxonomy without duplicates or near-duplicates
- Frontmatter is consistent across all notes (same fields, same format)
- The graph is navigable — you can reach any note from the home note in 3 clicks

## Operations

- **Link discovery**: find notes that discuss the same concept but aren't linked
- **MOC creation**: build Map of Content notes that serve as navigational hubs
- **Tag cleanup**: consolidate duplicate tags, enforce hierarchy, update the tags index
- **Orphan rescue**: find unlinked notes and connect them to the graph
- **Split/merge**: break oversized notes into atomic pieces, or merge fragments

## Anti-Patterns

- Don't create links for the sake of link count — every link should be meaningful
- Don't over-nest folders — flat with good linking beats deep folder hierarchies
- Don't create MOCs for fewer than 5 notes — they add overhead without value
