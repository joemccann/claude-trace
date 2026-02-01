# Continuity Ledger

## Goal (incl. success criteria)
Fix bug: macOS app not sending notifications for orphaned/outdated processes.

## Constraints/Assumptions
- NotificationService only had CPU/memory alert types - missing orphaned/outdated types
- ProcessMonitor.checkThresholds() wasn't checking for orphaned/outdated processes

## Key decisions
- Added `.orphanedProcess(pid:)` and `.outdatedProcess(pid:)` notification types
- Added ORPHAN_ALERT and OUTDATED_ALERT notification categories
- Added orphaned/outdated checks in checkThresholds()

## State
- Done:
  - Added notification types for orphaned/outdated in NotificationService.swift
  - Added notification categories (ORPHAN_ALERT, OUTDATED_ALERT)
  - Added notification trigger logic in ProcessMonitor.checkThresholds()
  - Build verified
- Now: Complete
- Next: None

## Open questions
- None

## Working set
- `apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar/Services/NotificationService.swift`
- `apps/ClaudeTraceMenuBar/ClaudeTraceMenuBar/Models/ProcessMonitor.swift`
