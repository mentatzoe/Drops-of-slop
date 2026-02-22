---
description: Testing standards and quality assurance requirements
paths:
  - "**/*.test.*"
  - "**/*.spec.*"
  - "**/tests/**/*"
  - "**/__tests__/**/*"
  - "**/test/**/*"
---

# Testing Standards

## Test Pyramid
- Unit tests form the base: fast, isolated, testing one behavior per test
- Integration tests verify component interactions and API contracts
- End-to-end tests cover critical user journeys only — keep the suite small and stable
- Prefer contract tests over E2E for service-to-service boundaries

## Test Quality
- Each test has one clear assertion about one behavior
- Test names describe the scenario and expected outcome: `renders error message when API returns 500`
- Tests are independent — no ordering dependencies or shared mutable state
- Use factories or builders for test data, not hardcoded fixtures

## Coverage Expectations
- New code: aim for meaningful coverage of branches and error paths
- Bug fixes: include a regression test that fails without the fix
- Refactors: existing tests should pass unchanged (behavior preservation)
- Coverage numbers are a signal, not a target — 80% meaningful > 95% superficial

## Test Maintenance
- Delete tests that test implementation details — they break on refactors and add no value
- Keep test setup DRY with shared helpers, but keep assertions inline and readable
- Flaky tests are bugs — fix or quarantine immediately, never ignore
