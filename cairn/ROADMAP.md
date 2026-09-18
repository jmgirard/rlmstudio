# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-17 (M001 review; validate clean, budgets under cap)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- Rows are grouped by status, not sorted by ID. Keep only the 3 most recent
     terminal (done or dropped) rows. Older ones live in milestones/archive/ and git. -->
| M002 | R CMD check on macOS, Windows, and Ubuntu in CI | in-progress | — | high | milestones/M002-platform-ci.md |
| M001 | Honor the host argument and fail fast on a stopped server | done | — | high | milestones/archive/M001-host-aware-probe.md |

## Candidates
<!-- Unnumbered ideas, one line each, ordered high, then normal, then low:
     - [high] idea, added YYYY-MM-DD, links
     - idea, added YYYY-MM-DD, links
     The opening token is [high] or [low] or absent (normal).
     See tracking-rules "Candidate priority token". -->
- Write the pre-release live-run procedure (full suite against a running LM Studio, re-record stale fixtures) into the release walk, added 2026-09-17, DESIGN Conventions
- Add `rlmstudio_no_server` class tests for the seven chat, load, and unload sites that only a code read covers, added 2026-09-17, M001 review finding 11
- [low] Make the headless CI job install LM Studio or rename it to say what it runs, added 2026-09-17, DESIGN Known issues
