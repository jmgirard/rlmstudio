# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene pass: 2026-09-18 (M003 review: archived M003, one new candidate row, one new lesson, `cairn_validate` clean, budgets under cap)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- Rows are grouped by status, not sorted by ID. Keep only the 3 most recent
     terminal (done or dropped) rows. Older ones live in milestones/archive/ and git. -->
| M004 | Response and empty-list branch tests for the two unload functions | planned | none | normal | milestones/M004-unload-branch-tests.md |
| M003 | Class tests for the ten server-down abort sites | done | none | normal | milestones/archive/M003-no-server-class-tests.md |
| M002 | R CMD check on macOS, Windows, and Ubuntu in CI | done | none | high | milestones/archive/M002-platform-ci.md |
| M001 | Honor the host argument and fail fast on a stopped server | done | none | high | milestones/archive/M001-host-aware-probe.md |

## Candidates
<!-- Unnumbered ideas, one line each, ordered high, then normal, then low:
     - [high] idea, added YYYY-MM-DD, links
     - idea, added YYYY-MM-DD, links
     The opening token is [high] or [low] or absent (normal).
     See tracking-rules "Candidate priority token". -->
- The release walk needs a live-run step: full suite against a running LM Studio, then a re-record of stale fixtures, added 2026-09-17, DESIGN Conventions
- A guard that keeps every new `stop_if_no_server()` call site covered by a class test, added 2026-09-18, M003 scope
- `lms_load()`, `lms_download()`, `lms_download_status()`, and the three chat functions have no test for their non-2xx response branches, added 2026-09-18, M004 scope
- The six API-failure aborts carry no condition class, so a caller has to match message text to catch one, added 2026-09-18, M004 plan gate
- When only R-devel breaks, a red `ubuntu-latest (devel)` job still blocks the merge. Decide its disposition, added 2026-09-17, M002 review finding 6
- [low] Make the headless CI job install LM Studio or rename it to say what it runs, added 2026-09-17, DESIGN Known issues
- [low] Unify the four workflow files on one `actions/checkout` version, a `concurrency` group, and a `workflow_dispatch` trigger, added 2026-09-17, M002 findings 7 and 8
