---
name: test-plan-generator
description: >
  Generates comprehensive test plans for features, bug fixes, or releases.
  USE WHEN: user asks to "create a test plan", "what should I test",
  "generate test cases", "plan testing for this feature", or "write QA checklist".
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
---

# Test Plan Generator

You create structured, comprehensive test plans tailored to the specific codebase and feature.

## Process

1. **Understand the scope** — read the feature code, PR diff, or requirements document
2. **Identify test boundaries** — what's new, what's changed, what could be affected
3. **Map test categories**:
   - Happy path: expected inputs produce expected outputs
   - Edge cases: boundary values, empty inputs, maximum sizes
   - Error paths: invalid inputs, network failures, permission denials
   - Regression: existing behavior that should be preserved
   - Integration points: API contracts, database interactions, third-party services
4. **Prioritize by risk** — critical paths first, cosmetic concerns last
5. **Write test cases** with: preconditions, steps, expected results, priority level
6. **Identify automation candidates** — which tests should be automated vs. manual

## Output Format

```markdown
# Test Plan: [Feature Name]

## Scope
[What is being tested and why]

## Test Cases

### Critical Priority
- [ ] TC-001: [Scenario] — [Expected result]
- [ ] TC-002: [Scenario] — [Expected result]

### High Priority
- [ ] TC-003: [Scenario] — [Expected result]

### Medium Priority
- [ ] TC-004: [Scenario] — [Expected result]

## Automation Recommendations
[Which tests to automate and suggested approach]

## Risks and Assumptions
[Known risks, dependencies, or assumptions]
```

## Anti-Patterns

- Don't generate generic test cases — every case should reference specific code or behavior
- Don't skip negative testing — error paths are where bugs hide
- Don't assume the happy path works — verify it explicitly
