# Branding & Design Context
# =============================================================================
# Fill this in with your actual brand guidelines.
# This file is loaded by the Playwright visual QA agent when analyzing screenshots.
# Be specific — the more detail here, the better the visual analysis.
# =============================================================================

## Brand Identity

**Brand name**: {{BRAND_NAME}}
**Tagline**: {{TAGLINE}}
**Voice**: {{e.g. "Professional but approachable. Clear and direct. Never jargony."}}

---

## Color Palette

| Token | Hex | Usage |
|---|---|---|
| Primary | `#000000` | CTAs, active states, key actions |
| Secondary | `#000000` | Supporting elements |
| Background | `#000000` | Page background |
| Surface | `#000000` | Card/panel backgrounds |
| Border | `#000000` | Dividers, input borders |
| Text Primary | `#000000` | Body copy, headings |
| Text Muted | `#000000` | Labels, captions, metadata |
| Success | `#000000` | Confirmations, success states |
| Error | `#000000` | Errors, destructive actions |
| Warning | `#000000` | Warnings, caution states |

---

## Typography

- **Heading font**: {{e.g. "Inter, sans-serif"}}
- **Body font**: {{e.g. "Inter, sans-serif"}}
- **Mono font**: {{e.g. "JetBrains Mono, monospace"}} (code, IDs, etc.)
- **Base size**: {{e.g. "16px"}}
- **Scale**: {{e.g. "Tailwind default type scale"}}

---

## Spacing & Layout

- **Grid**: {{e.g. "12-column, 24px gutters"}}
- **Container max-width**: {{e.g. "1280px"}}
- **Border radius**: {{e.g. "8px default, 4px small, 16px large cards"}}
- **Shadow style**: {{e.g. "Subtle, single-layer — no heavy drop shadows"}}

---

## Component Patterns

### Buttons
- Primary: {{e.g. "Solid fill, primary color, 40px height, 16px horizontal padding"}}
- Secondary: {{e.g. "Outlined, 1px border, same sizing"}}
- Destructive: {{e.g. "Error color, same sizing"}}
- Ghost: {{e.g. "No border, text only, hover fills"}}

### Forms
- {{e.g. "Labels above inputs, not inside"}}
- {{e.g. "Error messages below input in error color"}}
- {{e.g. "Required fields marked with asterisk"}}

### Cards / Panels
- {{e.g. "White background, 1px border, 8px radius, 24px padding"}}
- {{e.g. "Hover state: subtle shadow lift"}}

### Navigation
- {{e.g. "Sidebar: 240px fixed, collapsible on mobile"}}
- {{e.g. "Top nav: 64px height, logo left, actions right"}}

---

## Visual QA Checklist

When analyzing screenshots, the agent checks for:

1. **Color compliance** — are only brand colors used?
2. **Typography** — correct fonts, weights, sizes per hierarchy?
3. **Spacing** — consistent use of spacing scale, no cramped or blown-out layouts?
4. **Alignment** — elements aligned to grid, nothing floating unexpectedly?
5. **Component consistency** — buttons, inputs, cards match the patterns above?
6. **Empty states** — do empty states have proper illustration/copy?
7. **Loading states** — are skeletons/spinners used appropriately?
8. **Error states** — errors styled correctly in error color with helpful copy?
9. **Responsive** — does the layout work at the tested viewport?
10. **Accessibility** — sufficient color contrast, focus states visible?

---

## What to Flag as Failures

- Wrong colors (any hex not in the palette above)
- Inline styles overriding design tokens
- Inconsistent border radius
- Text too small (below 12px) or too large for context
- Misaligned elements (off-grid)
- Missing hover/focus states on interactive elements
- Hardcoded pixel values that should use spacing scale
- Generic browser default styles (unstyled inputs, links, etc.)

---

## Reference Screenshots

<!-- 
Add links or paths to reference screenshots of existing pages that represent
the correct visual style. Agents use these as ground truth.

Example:
- Dashboard: docs/design/dashboard-reference.png
- Settings: docs/design/settings-reference.png  
- Login: docs/design/login-reference.png
-->
