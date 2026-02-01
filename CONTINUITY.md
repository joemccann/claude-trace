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
- Programmatic SEO: 8 troubleshooting guide pages targeting long-tail keywords

## State
- Done:
  - Created site/ folder with Next.js project
  - Configured Tailwind CSS with custom theme
  - Built all page components (Nav, Hero, Features, CLI, Footer)
  - Added SEO metadata with Open Graph
  - Copied assets to public/
  - Added dynamic OpenGraph images (opengraph-image.tsx, twitter-image.tsx)
  - Updated layout.tsx to use file convention for OG images
  - Added programmatic SEO guides section (/guides/[slug])
  - 8 troubleshooting guides targeting: CPU, memory, orphans, slow response, multi-session, outdated, kill, flamegraph
  - Each guide has: HowTo schema, breadcrumb schema, dynamic OG images
  - Updated sitemap with all guide URLs
  - Build requires NODE_ENV=production (fixed in package.json)
  - Production build successful (87.1KB first load)
- Now: Complete - ready for Vercel deployment
- Next: User deploys to Vercel

## Open questions
- None (NODE_ENV issue resolved by setting it explicitly in build script)

## Working set
- `site/` - Next.js project (ready to deploy)
- `site/src/app/page.tsx` - Main page
- `site/src/app/guides/` - Programmatic SEO guides
  - `data.ts` - Guide content data
  - `page.tsx` - Guides index
  - `[slug]/page.tsx` - Individual guide template
  - `[slug]/opengraph-image.tsx` - Dynamic OG for each guide
- `site/src/app/opengraph-image.tsx` - Root OG image
- `site/src/app/twitter-image.tsx` - Root Twitter image
- `site/src/components/` - Nav, Hero, Features, CLI, Footer
- `site/public/` - Images
