# Continuity Ledger

## Goal (incl. success criteria)
Associate Chrome MCP processes with their parent Claude instances using PPID relationship.

## Constraints/Assumptions
- Chrome MCP process (`--claude-in-chrome-mcp`) is spawned as a child of the main Claude process
- PPID of Chrome MCP process == PID of parent Claude process (most robust method)

## Key decisions
- Use PPID relationship (not elapsed time or CWD matching) - most robust
- Name format: "project #1" for main, "project #1-chrome" for associated MCP
- Single project with chrome child: no number on main, just "chrome" suffix on child
- Chrome MCP processes excluded from main numbering sequence

## State
- Done:
  - Updated disambiguator logic in MenuBarView.swift
  - Chrome MCP children now get "-chrome" suffix matching parent's number
  - Single main process with Chrome child: child shows "chrome" only
  - Build verified successful
- Now: Complete - ready for testing
- Next: User should restart menu bar app to test

## Open questions
- None

## Working set
- `apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar/Views/MenuBarView.swift`
