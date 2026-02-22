---
description: Note-taking and knowledge organization conventions
paths:
  - "**/*.md"
  - "**/vault/**/*"
  - "**/notes/**/*"
---

# Note Conventions

## Note Structure
- Every note starts with a YAML frontmatter block: title, date, tags, status
- Use atomic notes — one concept per note, linked to related concepts
- Prefer wikilinks `[[Note Name]]` for internal references
- Include a "Related" section at the bottom linking to connected notes

## Naming
- Use descriptive titles that stand alone: "Spaced Repetition for Long-Term Retention", not "SRS Notes"
- Date-prefixed for chronological notes: `2024-03-15 Meeting with Design Team`
- No dates for evergreen/reference notes — they should be timeless

## Tagging
- Use hierarchical tags: `#type/concept`, `#project/atlas`, `#status/draft`
- Keep the tag vocabulary small and documented in a tags index note
- Tags classify; links connect — use both but for different purposes

## Knowledge Maintenance
- Review and update notes when you encounter new information on the topic
- Mark stale notes with `#status/needs-review` and a note about what changed
- Periodically review orphan notes (no incoming links) — connect or archive them
- Prefer linking to existing notes over creating duplicates
