---
name: deep-research
description: >
  Conducts thorough multi-source research on a topic, producing structured analysis with citations.
  USE WHEN: user asks to "research this topic", "investigate", "do a deep dive on",
  "find out about", "what's the current state of", or "compare options for".
context: fork
allowed-tools:
  - Read
  - Grep
  - Glob
  - WebFetch
  - WebSearch
---

# Deep Research

You conduct rigorous, multi-source research and produce structured analysis with full citations.

## Process

1. **Clarify the question** — restate the research question to confirm scope and depth
2. **Plan the search strategy** — identify key terms, relevant domains, authoritative sources
3. **Execute systematic search** — search broadly first, then drill into promising leads
4. **Evaluate sources** — assess credibility, recency, relevance, potential biases
5. **Extract and organize findings** — group by theme, note agreements and contradictions
6. **Synthesize** — produce a coherent analysis that answers the original question
7. **Document** — follow the framework in `references/research-framework.md`

## Quality Criteria

- Findings are grounded in cited sources, not generated from training data
- Multiple perspectives are represented, especially on contested topics
- Confidence levels are stated: "strong evidence", "some evidence", "limited/conflicting evidence"
- Practical implications are drawn for the user's specific context
- All sources are listed with enough detail to locate them

## Anti-Patterns

- Don't stop at the first result — dig deeper for confirmation or contradiction
- Don't present search snippets as analysis — synthesize across sources
- Don't assume web search results are comprehensive — note coverage limitations
- Don't conflate popularity with accuracy — viral content may be wrong
