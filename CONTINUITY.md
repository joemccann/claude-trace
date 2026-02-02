# Continuity Ledger

## Goal (incl. success criteria)
Redesign claude-trace.com website with Firecrawl-inspired design system using Claude brand colors.

**Success criteria:** Site uses Firecrawl's minimalist aesthetic (thin borders, no shadows, sharp corners, monospace data) with Claude coral `#d97757` as primary accent.

## Constraints/Assumptions
- Existing Next.js 14 + Tailwind site in `/site` directory
- Maintain feature parity with existing content
- No image mockups - implement directly in code

## Key decisions
- **Color Palette**: Firecrawl dark mode (`#0a0a0a` base, `#171717` surface, `#2a2a2a` borders) + Claude coral `#d97757`
- **Typography**: Geist Sans + Geist Mono (installed via `geist` npm package)
- **Style**: Flat design, 2px max border-radius, thin 1px borders, no shadows/gradients/glows
- **Components**: Surgical minimalist aesthetic matching Firecrawl's developer tool vibe

## State
- Done:
  - Extracted Firecrawl design system from firecrawl.dev
  - Identified Claude brand coral color: `#d97757`
  - Updated `tailwind.config.ts` with new color tokens and design system
  - Updated `globals.css` with CSS variables and utility classes
  - Updated `layout.tsx` to use Geist fonts
  - Rewrote `Nav.tsx` - flat design, sharp corners, accent color
  - Rewrote `Hero.tsx` - minimal badges, clean CTAs, no glows
  - Rewrote `Features.tsx` - numbered grid with hover states
  - Rewrote `CLI.tsx` - code-focused, monospace styling
  - Rewrote `Footer.tsx` - minimal footer
  - Installed `geist` font package
  - Verified build passes
- Now: Complete - all components updated
- Next: User review of changes, run `cd site && npm run dev` to preview

## Open questions
- None

## Working set
- `site/tailwind.config.ts` - Design tokens
- `site/src/app/globals.css` - CSS variables
- `site/src/app/layout.tsx` - Font setup
- `site/src/components/Nav.tsx`
- `site/src/components/Hero.tsx`
- `site/src/components/Features.tsx`
- `site/src/components/CLI.tsx`
- `site/src/components/Footer.tsx`
