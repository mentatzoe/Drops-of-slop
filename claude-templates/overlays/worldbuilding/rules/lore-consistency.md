---
description: Lore consistency and worldbuilding integrity rules
paths:
  - "**/lore/**/*"
  - "**/world/**/*"
  - "**/wiki/**/*"
  - "**/*.md"
---

# Lore Consistency

## Canon Hierarchy
- Establish a canon tier system: Primary (definitive) > Secondary (supplementary) > Tertiary (flavor)
- When sources conflict, higher-tier canon wins — document the resolution
- Mark speculative or draft lore with a clear `[DRAFT]` or `[NON-CANON]` tag
- Maintain a canonical timeline as the single source of truth for event ordering

## Cross-Reference Discipline
- Every named entity (character, place, faction, artifact) gets a dedicated note
- When introducing a new element, search existing lore for conflicts before adding
- Link mentions of entities to their canonical entries using wikilinks
- Track entity relationships: alliances, conflicts, lineage, geography

## Change Management
- Never silently retcon — document what changed and why in a changelog
- When updating established lore, check all referencing documents for ripple effects
- Use version notes in frontmatter: `lore-version: 2.1`, `last-reviewed: 2024-03-15`

## Consistency Checks
- Geographic distances and travel times should be internally consistent
- Power systems should have defined costs, limits, and rules that are followed
- Cultural details (language, customs, technology) should match the society's context
- Timeline events should not create paradoxes or impossible sequences
