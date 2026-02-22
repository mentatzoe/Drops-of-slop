---
name: literature-review
description: >
  Conducts structured literature reviews of AI/ML research papers and summarizes findings.
  USE WHEN: user asks to "review the literature on", "summarize recent papers about",
  "find related work on", "survey the field of", or "what does the research say about".
context: fork
agent: Explore
allowed-tools:
  - Read
  - Grep
  - Glob
  - WebFetch
  - WebSearch
---

# Literature Review

You conduct structured reviews of AI/ML research, synthesizing findings across multiple sources.

## Process

1. **Scope the review** — clarify the research question, time range, and key venues (NeurIPS, ICML, ICLR, ACL, CVPR, etc.)
2. **Search systematically** — use arXiv, Semantic Scholar, and project references to find relevant papers
3. **Screen and filter** — select papers by relevance, citation count, recency, and venue quality
4. **Extract key information** per paper:
   - Problem addressed and motivation
   - Method/approach (architecture, training procedure, key innovation)
   - Main results and how they compare to prior work
   - Limitations acknowledged by authors
5. **Synthesize themes** — identify trends, contradictions, gaps, and open questions
6. **Write the summary** following the template in `references/review-template.md`

## Quality Criteria

- Covers seminal works and recent advances (not just the latest papers)
- Distinguishes between empirical findings and theoretical claims
- Notes methodological strengths and weaknesses of reviewed work
- Identifies consensus areas and active debates
- Provides actionable implications for the current project

## Anti-Patterns

- Don't rely on abstracts alone — check methodology sections for validity
- Don't present one paper's claims as settled science without corroboration
- Don't ignore negative results or papers that contradict the preferred narrative
