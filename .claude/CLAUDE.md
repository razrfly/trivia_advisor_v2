# Trivia Advisor V2 - Project Instructions

## Project Overview

**Trivia Advisor V2** is a fresh Phoenix 1.7+ rebuild focused on providing a read-only view of trivia events from the Eventasaurus database. This is a clean-slate implementation migrating only the valuable 15-20% of working components from the legacy codebase.

## Core Principles

- **Read-Only Architecture**: No data writes, consume Eventasaurus DB as single source of truth
- **Component Reuse**: Migrate 18 working LiveView components with minimal changes
- **Zero Technical Debt**: Fresh start, modern Phoenix patterns only
- **Tailwind-First UI**: Maintain existing component styling and design patterns

## Key Technologies

- **Phoenix 1.7.21+** with LiveView
- **Ecto** (read-only queries only, no migrations)
- **Tailwind CSS** with @tailwindcss/forms plugin
- **Heroicons** for UI icons
- **External PostgreSQL** (Eventasaurus database)

## Development Guidelines

### Database Operations
- ✅ Read operations via Ecto queries
- ❌ No migrations, schemas, or write operations
- ⚠️ All data validation happens in Eventasaurus, trust the source

### Component Migration Strategy
1. Copy LiveView component files from legacy project
2. Update module names: `TriviaAdvisor` → `TriviaAdvisorV2`
3. Verify Tailwind classes and styling preserved
4. Test component functionality in isolation
5. Validate routing and navigation patterns

### Files to Migrate
- **Priority 1**: Home, City Show, Venue Display LiveViews
- **Priority 2**: Helper functions and utilities
- **Priority 3**: Router patterns and navigation
- **Priority 4**: Asset files (images, icons, static content)

## Architecture Decisions

### Why No Ecto Migrations?
Eventasaurus owns the schema. We consume it read-only, so we define schemas in code but never migrate.

### Why Fresh Start?
- 70% faster timeline (2-3 weeks vs 7-10 weeks)
- 75% lower risk than surgical code removal
- Zero legacy technical debt
- Early validation checkpoint (Day 4)

## MCP Integration

Auto-activate for this project:
- **Context7**: Phoenix, Ecto, LiveView patterns
- **Sequential**: Migration planning, component analysis
- **Magic**: UI component assistance (Tailwind + LiveView)

## Quality Standards

- All LiveView components must maintain existing UX
- Tailwind styling must match legacy design
- No database write operations (enforced at connection level)
- Component reuse: 100% for working LiveViews
- Code quality: Clean, modern Phoenix patterns only
