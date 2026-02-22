---
description: React component patterns and conventions
paths:
  - "src/components/**/*"
  - "**/*.tsx"
  - "**/*.jsx"
---

# React Patterns

## Component Structure
- Use functional components with hooks — no class components
- Co-locate component, styles, tests, and types in the same directory
- Export components as named exports; reserve default exports for pages/routes
- Keep components under 150 lines; extract sub-components when they grow

## State Management
- Use local state (`useState`) for UI-only concerns
- Lift state to the nearest common ancestor, not higher
- Use context for truly global concerns (theme, auth, locale) — not for prop drilling avoidance
- Prefer server state libraries (React Query, SWR) over manual fetch-in-useEffect

## Hooks
- Custom hooks start with `use` and encapsulate one behavior
- Always specify dependency arrays completely — no eslint-disable for exhaustive-deps
- Avoid `useEffect` for derived state — use `useMemo` or compute inline

## Performance
- Memoize expensive computations with `useMemo`, not every render
- Use `React.memo` only after profiling confirms a re-render bottleneck
- Prefer CSS for animations over JS-driven re-renders
