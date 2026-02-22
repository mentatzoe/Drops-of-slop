---
description: Jetpack Compose UI patterns and conventions
paths:
  - "**/ui/**/*"
  - "**/*Screen.kt"
---

# Compose Patterns

## Composable Structure
- Stateless composables for UI rendering; stateful wrappers for state hosting
- Name pattern: `{Feature}Screen` (stateful) delegates to `{Feature}Content` (stateless)
- Keep composables small — extract sub-composables at visual boundary lines
- Preview every composable with `@Preview` using representative data

## State Management
- Hoist state to the nearest common ancestor composable
- Use `remember` for UI state; `rememberSaveable` for state surviving config changes
- Collect flows with `collectAsStateWithLifecycle()` — not `collectAsState()`
- Pass events up as lambdas, state down as parameters (unidirectional data flow)

## Material Design 3
- Use `MaterialTheme.colorScheme`, `.typography`, `.shapes` — never hardcode values
- Support dynamic color on Android 12+ via `dynamicDarkColorScheme`/`dynamicLightColorScheme`
- Use semantic color roles (primary, secondary, surface) not raw colors

## Performance
- Use `key()` in `LazyColumn`/`LazyRow` items for stable identity
- Avoid allocations in composable bodies — pre-compute outside or use `remember`
- Mark stable classes with `@Stable` or `@Immutable` to help the Compose compiler
