---
description: Code quality standards and conventions
---

# Code Quality Standards

## Error Handling
- Handle errors at system boundaries; trust internal function contracts
- Use typed errors with context — include what failed and why
- Never use empty catch blocks; at minimum, log with context
- Prefer early returns for error conditions to reduce nesting

## Testing
- Write tests for new behavior before marking work complete
- Update existing tests when changing behavior they cover
- Test edge cases: empty inputs, boundary values, error paths
- Keep tests independent — no shared mutable state between test cases

## Naming Conventions
- Use descriptive names that reveal intent — avoid abbreviations
- Functions: verb phrases (`calculateTotal`, `fetchUserById`)
- Booleans: question phrases (`isValid`, `hasPermission`, `shouldRetry`)
- Constants: UPPER_SNAKE_CASE for true constants, camelCase for derived values

## Code Structure
- Functions should do one thing and be readable without scrolling
- Extract a helper only when it is used in two or more places
- Prefer flat over nested — use early returns, guard clauses, and pipeline patterns
- Group related code by feature, not by type (co-locate tests with source)

## Avoid Over-Engineering
- Solve the current problem, not hypothetical future ones
- Three similar lines are better than a premature abstraction
- Add configuration only when a value genuinely varies across environments
