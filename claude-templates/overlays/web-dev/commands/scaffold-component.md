---
name: scaffold-component
description: >
  Scaffolds a new React component with tests and types.
  USE WHEN: user says "scaffold component", "create new component",
  "generate component", or "new React component".
allowed-tools:
  - Read
  - Write
  - Glob
---

# Scaffold Component

Create a new React component following the project's conventions.

## Process

1. Ask for the component name and directory (default: `src/components/`)
2. Check existing components for style conventions (CSS approach, export patterns, test patterns)
3. Generate these files:
   - `{ComponentName}.tsx` — functional component with typed props
   - `{ComponentName}.test.tsx` — test file with render and basic interaction tests
   - `{ComponentName}.module.css` (or styled equivalent based on project conventions)
   - `index.ts` — named re-export
4. Follow existing project patterns exactly — match imports, naming, and file structure

## Component Template Principles

- Props interface named `{ComponentName}Props`, exported
- Destructure props in function signature
- Use `forwardRef` if the component wraps a native element
- Include a display name for dev tools
- Default export from index, named export from component file
