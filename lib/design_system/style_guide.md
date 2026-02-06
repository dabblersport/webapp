
# Dabbler Design System — Style Guide

Status: Active  
Scope: Design system foundations (tokens first, behavior later)  
Audience: Humans + VS Code coding agents

This document defines the authoritative rules for how UI is constructed in Dabbler.
Any screen, component, or layout that violates this guide is considered invalid.

## 1. Purpose & Authority

This style guide exists to ensure:

- Consistent Material 3 usage
- Predictable visual behavior across features
- Zero ambiguity for AI-generated UI code
- Clear separation between data (tokens) and usage (guidelines)

### Authority Rule

If there is a conflict between:

- Agent defaults
- Framework conventions
- Personal preference

This document wins.

## 2. Design Foundations

### 2.1 Base System

- The app is built on Material Design 3 (M3)
- Material roles are treated as semantic contracts, not colors
- No Material 2 patterns are allowed

### 2.2 Token-First Principle

Nothing in the UI may reference raw values.
Everything must flow through design tokens.

This applies to:

- Colors
- Typography (later)
- Spacing (later)
- Elevation/surfaces (later)

## 3. Color Tokens (FOUNDATION — LOCKED)

### 3.1 Source of Truth

All runtime colors come from Dart token files generated from Material 3–mapped JSON.

These files are the only allowed source for colors.

### 3.2 Dart Token Files (Generated)

This folder contains Material 3 color role tokens exported as Dart constants.

These Dart files are the source of truth for app colors at runtime.

#### Files

One file per context × mode:

- main_light.dart, main_dark.dart
- social_light.dart, social_dark.dart
- sports_light.dart, sports_dark.dart
- activity_light.dart, activity_dark.dart
- profile_light.dart, profile_dark.dart

#### Token Shape (Mandatory)

Each file exports exactly one immutable token object:

```
const theme = (...);
```

Tokens are accessed via:

```
theme.<context>.<role>
```

Where:

- context ∈ { main, social, sports, activity, profile }
- role is the Material 3 role name unchanged

Examples:
primary, onPrimary, surfaceContainerHigh, inverseSurface

### 3.3 Mapping Rules (Non-Negotiable)

- No role renames  
	Dart keys match JSON keys 1:1

- No value changes  
	JSON hex values are preserved exactly

- No collapsing / inference  
	Even identical colors remain duplicated across contexts

- No shared light/dark files  
	Each file represents one mode only

### 3.4 Color Encoding

JSON colors are encoded as:

```
#RRGGBB
```

Converted to Dart as:

```
Color(0xFFRRGGBB)
```

Alpha is always FF (fully opaque)

No transparency is encoded at the token level

### 3.5 Context Usage Rules

Each screen must use exactly one color context:

| Context | Usage |
|---|---|
| main | Auth, onboarding, home, general app screens |
| social | Feed, posts, friends, public profiles |
| sports | Games, venues, sports discovery |
| activity | Notifications, activity log |
| profile | My profile, settings |

Hard rule:

A screen may not mix tokens from multiple contexts.

Shared components inherit the active screen context.

### 3.6 What Is Explicitly Forbidden

- ❌ Hardcoded colors
- ❌ Direct use of ColorScheme in UI
- ❌ Accessing Flutter theme colors directly
- ❌ Inferring or aliasing tokens
- ❌ Using tokens across contexts

## 4. What This Document Does Not Yet Define

The following sections are intentionally deferred and will be added incrementally:

- Layout archetypes (e.g. AuthLayout)
- Typography bindings
- Spacing & sizing tokens
- CTA hierarchy and button specs
- Component contracts
- Navigation patterns

This prevents premature constraints and keeps the foundation stable.

## 5. Agent Compliance Rules

When generating code:

- Read this file first
- Assume tokens are correct and final
- Never invent visual values
- Stop and explain if a requirement cannot be met

Non-compliant output must be rejected.

## 6. Versioning

This document will evolve

Sections are appended, not rewritten

Token rules are locked once released

End of v0.1

