# Continuity Ledger

## Goal (incl. success criteria)
Create a one-page Next.js marketing website for Claude Trace, hosted on Vercel. Use README content for viral marketing and SEO.

## Constraints/Assumptions
- One-page site (landing page style)
- Next.js 14 App Router + Tailwind CSS
- Dark minimal design (Option 1 selected)
- Vercel-ready

## Key decisions
- Selected Option 1: Minimal Dark design
- Color palette: #0a0a0a bg, #22d3ee cyan accent
- Fonts: Inter + JetBrains Mono
- Components: Nav, Hero, Features, CLI, Footer
- Dynamic OG images via Next.js file convention (not static files)

## State
- Done:
  - Created site/ folder with Next.js project
  - Configured Tailwind CSS with custom theme
  - Built all page components (Nav, Hero, Features, CLI, Footer)
  - Added SEO metadata with Open Graph
  - Copied assets to public/
  - Production build successful (93.7KB first load)
  - Previewed locally - all sections render correctly
  - Added dynamic OpenGraph images (opengraph-image.tsx, twitter-image.tsx)
  - Updated layout.tsx to use file convention for OG images
- Now: Complete - ready for Vercel deployment
- Next: User deploys to Vercel

## Open questions
- Pre-existing build error (useContext null) needs investigation - not caused by OG changes

## Working set
- `site/` - Next.js project (ready to deploy)
- `site/src/app/page.tsx` - Main page
- `site/src/app/opengraph-image.tsx` - Dynamic OG image generator
- `site/src/app/twitter-image.tsx` - Dynamic Twitter card image
- `site/src/components/` - Nav, Hero, Features, CLI, Footer
- `site/public/` - Images from assets/
