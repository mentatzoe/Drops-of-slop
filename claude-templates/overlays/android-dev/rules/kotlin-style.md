---
description: Kotlin coding style and idioms for Android
paths:
  - "**/*.kt"
---

# Kotlin Style

## Language Idioms
- Use `data class` for value types and DTOs
- Prefer `sealed class`/`sealed interface` for restricted hierarchies
- Use `when` expressions exhaustively — always handle all branches
- Prefer extension functions over utility classes

## Null Safety
- Avoid `!!` (non-null assertion) — use `?.let`, `?:`, or early returns instead
- Use `requireNotNull()` at function entry points where null indicates a programming error
- Model optional data with nullable types, not sentinel values

## Coroutines
- Use `viewModelScope` for ViewModel coroutines, `lifecycleScope` for UI coroutines
- Always use `Dispatchers.IO` for disk/network operations
- Prefer `Flow` over `LiveData` for reactive data streams
- Handle cancellation gracefully — use `ensureActive()` in long loops

## Conventions
- One class per file; file name matches class name
- Use `const val` for compile-time constants, `val` for runtime constants
- Prefer `buildList`, `buildMap`, `buildString` for constructing collections
