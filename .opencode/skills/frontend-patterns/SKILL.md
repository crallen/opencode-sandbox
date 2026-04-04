---
name: frontend-patterns
description: Component architecture patterns, state management approaches, accessibility checklist, responsive design, and performance optimization for frontend development
---

## Component Architecture

### Component Types

| Type | Purpose | State | Examples |
|------|---------|-------|---------|
| **Presentational** | Render UI from props | None or local UI state only | Button, Card, Avatar, Badge |
| **Container** | Manage data and logic | Yes, fetches/manages data | UserProfile, Dashboard, OrderList |
| **Layout** | Structure and composition | None | PageLayout, Sidebar, Grid |
| **Page** | Route-level entry point | Manages route-level data | HomePage, SettingsPage |

### Component Design Rules

1. **Single responsibility** - One component, one job. If a component needs an "and" in its description, split it.
2. **Props down, events up** - Data flows down through props. User actions propagate up through callbacks/events.
3. **Prefer composition** - Use children/slots to compose components instead of adding configuration props.
4. **Consistent prop naming**:
   - Boolean props: `isDisabled`, `hasError`, `shouldAutoFocus`
   - Event handlers: `onClick`, `onChange`, `onSubmit`
   - Render props: `renderHeader`, `renderItem`
5. **Sensible defaults** - Optional props should have defaults that produce the most common behavior.

### File Organization

Colocate related files:

```
components/
  Button/
    Button.tsx          # Component
    Button.test.tsx     # Tests
    Button.module.css   # Styles (or .styled.ts)
    index.ts            # Public export
```

## State Management

### Choosing the Right State Location

| State type | Where to put it |
|---|---|
| **UI-only** (dropdown open, hover) | Local component state |
| **Shared between siblings** | Lift to nearest common parent |
| **Used across distant components** | Context, store, or URL |
| **Server data** | Server state library (React Query, SWR, TanStack Query) |
| **URL-dependent** (filters, pagination) | URL search params |
| **Persisted across sessions** | localStorage + state sync |

### Rules of Thumb

- Start with local state. Lift only when needed.
- Keep server state separate from client state. Use dedicated data fetching libraries.
- Derive values instead of syncing state. If state B can be computed from state A, don't store B separately.
- URL is state too. Filters, sort order, pagination, and selected tabs should be in the URL for shareability and back-button support.

## Accessibility Checklist

### Structure
- [ ] Semantic HTML elements used (`button`, `nav`, `main`, `section`, `article`, `aside`, `header`, `footer`)
- [ ] Heading hierarchy is logical (h1 -> h2 -> h3, no skipped levels)
- [ ] Page has exactly one `<main>` element
- [ ] Landmarks are used to define page regions

### Keyboard
- [ ] All interactive elements are focusable (buttons, links, inputs, custom widgets)
- [ ] Focus order follows visual order (no unexpected tab jumps)
- [ ] Focus is visible (never `outline: none` without a replacement)
- [ ] Custom widgets support expected keyboard patterns (Enter/Space for buttons, Arrow keys for menus)
- [ ] Focus is trapped in modals and restored when modals close
- [ ] Keyboard shortcuts don't conflict with screen reader shortcuts

### Content
- [ ] Images have meaningful `alt` text (or `alt=""` for decorative images)
- [ ] Links have descriptive text (not "click here")
- [ ] Form inputs have associated `<label>` elements
- [ ] Required fields are indicated (not just by color)
- [ ] Error messages are associated with their inputs (`aria-describedby`)
- [ ] Status messages use `aria-live` regions for dynamic updates

### Visual
- [ ] Color contrast meets WCAG AA: 4.5:1 normal text, 3:1 large text
- [ ] Information is not conveyed by color alone
- [ ] Text can be resized to 200% without loss of functionality
- [ ] No content requires horizontal scrolling at 320px viewport width
- [ ] Motion/animation respects `prefers-reduced-motion`

## Responsive Design

### Mobile-First Approach

Start with the smallest viewport. Add complexity for larger screens:

```css
/* Base styles: mobile */
.container {
  padding: 1rem;
}

/* Tablet and up */
@media (min-width: 768px) {
  .container {
    padding: 2rem;
    max-width: 720px;
  }
}

/* Desktop and up */
@media (min-width: 1024px) {
  .container {
    max-width: 960px;
  }
}
```

### Common Breakpoints

| Name | Width | Target |
|------|-------|--------|
| sm | 640px | Large phones |
| md | 768px | Tablets |
| lg | 1024px | Small laptops |
| xl | 1280px | Desktops |
| 2xl | 1536px | Large screens |

### Responsive Patterns

- **Stacking**: Multi-column layouts stack to single column on mobile.
- **Off-canvas**: Navigation moves to a slide-out drawer on mobile.
- **Priority+**: Show most important items; overflow into a "more" menu.
- **Responsive images**: Use `srcset` and `sizes` for appropriate resolution.

## Performance

### Rendering
- Avoid re-renders: memoize only when profiling shows a bottleneck (not preemptively).
- Virtualize long lists (1000+ items). Use windowing libraries.
- Debounce expensive input handlers (search, resize, scroll).
- Use CSS for animations instead of JavaScript when possible.

### Loading
- Code-split routes and heavy components with lazy loading.
- Preload critical resources (`<link rel="preload">`).
- Optimize images: correct size, modern format (WebP/AVIF), lazy loading for below-fold.
- Minimize blocking resources in `<head>`.

### Bundle Size
- Import only what you need: `import { debounce } from 'lodash-es'` not `import _ from 'lodash'`.
- Analyze your bundle regularly (`webpack-bundle-analyzer`, `source-map-explorer`).
- Tree-shake unused code (use ESM imports).
- Consider lighter alternatives for heavy dependencies.
