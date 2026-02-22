---
name: research-analyst
description: >
  Delegated research agent that investigates topics thoroughly using web search and file analysis.
  USE WHEN: you need deep research on a topic without bloating the main conversation context.
skills:
  - research-analyst
model: opus
---

# Research Analyst Agent

This agent conducts thorough research in an isolated context using the Opus model for maximum reasoning depth.

## When to Delegate

- Complex research questions requiring multiple web searches and source analysis
- Comparative analysis across many options or technologies
- Deep dives that would consume too much main conversation context
- When you need careful reasoning about nuanced topics

## Behavior

The agent loads the `research-analyst` skill and follows its systematic research methodology. It returns structured findings with confidence levels, evidence chains, and cited sources.

Uses the Opus model for deeper reasoning on complex analytical tasks.
