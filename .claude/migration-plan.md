# Migration Plan - Issue #267 Summary

**Source**: https://github.com/razrfly/trivia_advisor/issues/267

## Executive Decision

**Chosen Approach**: Fresh Phoenix rebuild (trivia_advisor_v2) instead of surgical migration

## The Problem

Legacy codebase has **1,910 files** with significant technical debt. Transitioning from self-managed data to read-only Eventasaurus database consumption.

## Two Approaches Compared

### Option A: Surgical Migration (REJECTED)
- **Timeline**: 7-10 weeks
- **Approach**: Remove 60-70% of code while maintaining system
- **Risks**: High complexity, ongoing technical debt
- **Blockers**:
  - Hero image handling (1-2 weeks alone)
  - Performer relationship mapping
  - Event pattern transformation complexity

### Option B: Fresh Rebuild (SELECTED) ✅
- **Timeline**: 2-3 weeks
- **Approach**: Copy valuable 15-20% into clean Phoenix foundation
- **Advantages**:
  - 70% faster timeline
  - 75% lower risk
  - Zero technical debt
  - Early validation checkpoint (Day 4)
  - 100% component reuse for working LiveViews

## What to Migrate

### Keep (~50 files total)
1. **18 Working LiveView Components**
   - Home page
   - City show page
   - Venue display
   - Component logic and styling

2. **Supporting Code**
   - Helper functions
   - Router patterns
   - Tailwind configuration
   - Asset files

3. **Configuration**
   - Heroicons setup
   - Tailwind plugins
   - Brand colors and theming

### Leave Behind (~1,860 files)
- Database migrations (Eventasaurus owns schema)
- Data management code (read-only now)
- Failed experiments and unused code
- Outdated patterns and technical debt
- Complex data transformation layers

## Why Phoenix Specifically

- **Ecto**: Native read-only database schema support
- **LiveView**: 100% component reuse vs 0% with Rails/Next.js
- **Migrations**: Not needed, perfect for read-only consumer
- **Ecosystem**: Existing team knowledge and tooling

## Implementation Strategy

### Phase 1: Foundation (Week 1)
1. Generate new Phoenix app: `mix phx.new trivia_advisor_v2 --no-ecto`
2. Add Ecto/Postgrex manually (read-only config)
3. Configure Tailwind with brand colors
4. Set up Eventasaurus database connection
5. **Validation Checkpoint (Day 4)**: Can we read Eventasaurus data?

### Phase 2: Component Migration (Week 2)
1. Migrate home page LiveView
2. Migrate city show LiveView
3. Migrate venue display LiveView
4. Copy helper functions and utilities
5. Test component functionality

### Phase 3: Polish (Week 3)
1. Router configuration
2. Asset migration
3. Testing and validation
4. Performance optimization
5. Documentation

## Risk Mitigation

### Early Validation (Day 4)
Test Eventasaurus database connection and basic queries. If this fails, we know early and can pivot.

### Incremental Delivery
Each component migration is independently testable. Can deploy partial functionality while completing migration.

### Rollback Strategy
Legacy system remains operational during rebuild. Can maintain both systems during transition period.

## Success Criteria

- ✅ Read-only Eventasaurus database access working
- ✅ All 18 LiveView components migrated and functional
- ✅ Tailwind styling preserved
- ✅ User experience maintained or improved
- ✅ Zero technical debt in new codebase
- ✅ 2-3 week timeline met

## Confidence Level

**95% confidence** in fresh rebuild approach based on:
- Clear scope definition (18 components)
- Proven Phoenix/LiveView patterns
- Read-only architecture simplicity
- Early validation checkpoint
- Minimal complexity in migration targets

## Next Steps

1. Create new Phoenix project structure
2. Configure read-only Ecto connection to Eventasaurus
3. Define read-only schemas based on Eventasaurus tables
4. Validate database connectivity (Day 4 checkpoint)
5. Begin component migration in priority order
