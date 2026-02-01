# Continuity Ledger

## Goal (incl. success criteria)
Refactor README.md to be marketing-focused "ad" for Claude Trace, with macOS menu bar app prominently featured. Move detailed docs to separate files. Include screenshot placeholders.

## Constraints/Assumptions
- Keep all features documented (nothing deleted, just reorganized)
- macOS menu bar app should be primary focus, right below banner
- README should feel like marketing material, not a technical manual
- Detailed CLI/diagnostics docs move to docs/ folder
- Screenshot placeholders for user to add images later

## Key decisions
- Created `docs/` folder with 4 documentation files
- README structure: Banner → Tagline → App showcase → Features → Install → CLI quickstart → Docs links
- Docs created: CLI.md, DIAGNOSTICS.md, DEVELOPMENT.md, TROUBLESHOOTING.md
- Screenshots needed: menubar-dropdown.png, settings-panel.png, notification.png, detail-window.png

## State
- Done:
  - Researched README best practices from web sources
  - Created new marketing-focused README.md
  - Created docs/CLI.md with all CLI reference content
  - Created docs/DIAGNOSTICS.md with Rust diagnostic tool docs
  - Created docs/DEVELOPMENT.md with build/test/contribute info
  - Created docs/TROUBLESHOOTING.md with common issues
  - Added screenshot placeholders with captions
- Now: Complete
- Next: User to take screenshots and add to assets/

## Open questions
- None

## Working set
- `README.md` (refactored)
- `docs/CLI.md` (new)
- `docs/DIAGNOSTICS.md` (new)
- `docs/DEVELOPMENT.md` (new)
- `docs/TROUBLESHOOTING.md` (new)
