# Trivia Advisor - Domain Knowledge

## What is Trivia Advisor?

A web application for discovering trivia events (pub quiz nights, trivia competitions) across various cities and venues. Users can browse events by location, venue, and date.

## Business Context

### Legacy System
- **Current State**: 1,910 files with significant technical debt
- **Pain Points**: Data management overhead, inconsistent patterns, bloated codebase
- **Success Stories**: 18 working LiveView components with good UX

### New Direction
- **Data Strategy**: Read-only consumer of Eventasaurus database
- **Focus**: Display and discovery, not data management
- **Goal**: Clean, maintainable codebase with modern Phoenix patterns

## Data Model (Eventasaurus Read-Only)

### Core Entities
- **Events**: Trivia events with dates, times, descriptions
- **Venues**: Physical locations hosting events
- **Cities**: Geographic grouping for events
- **Performers**: Trivia hosts/organizers (relationship mapping needed)

### Key Relationships
- Events → Venues (many-to-one)
- Venues → Cities (many-to-one)
- Events → Performers (complex, needs pattern transformation)

## User Journeys

1. **Browse by City**: View all trivia events in a specific city
2. **Venue Details**: See venue information and upcoming events
3. **Event Discovery**: Find trivia events by date/location
4. **Home Page**: Featured events and city navigation

## Working Components to Migrate

### Priority LiveViews (18 total)
1. **Home**: Landing page with featured events
2. **City Show**: City-specific event listings
3. **Venue Display**: Venue details and event schedule

### Supporting Features
- Hero images (requires special handling)
- Tailwind styling system
- Navigation patterns
- Helper functions for date/time formatting
- SEO optimization (JSON-LD, sitemaps)

## Technical Patterns

### Current Stack (to preserve)
- **Styling**: Tailwind CSS with custom brand color (#FD4F00)
- **Icons**: Heroicons integration
- **Forms**: @tailwindcss/forms plugin
- **LiveView**: Real-time updates, client-side navigation

### Dependencies (legacy, review for V2)
- D3.js for data visualization
- topojson-client for geographic data
- Various utility libraries (slugify, timex, etc.)

## Migration Blockers (from Issue #267)

### Critical Challenges
1. **Hero Image Handling**: 1-2 weeks effort in migration approach
2. **Performer Relationships**: Complex mapping from old to new schema
3. **Event Pattern Transformation**: Schema differences require careful handling

### Why These Don't Apply to Fresh Start
Fresh rebuild allows us to adapt to Eventasaurus patterns directly rather than transforming legacy patterns.

## Success Metrics

- Component reuse: 100% of working LiveViews
- Timeline: 2-3 weeks to functional MVP
- Code reduction: From 1,910 files to ~200-300 files
- Technical debt: Zero (fresh start)
- User experience: Maintained or improved from legacy
