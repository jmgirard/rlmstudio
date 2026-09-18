# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene pass: 2026-09-18 (M006 plan: added the M006 row, absorbed three candidate rows into its scope)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- Rows are grouped by status, not sorted by ID. Keep only the 3 most recent
     terminal (done or dropped) rows. Older ones live in milestones/archive/ and git. -->
| M006 | list_models() joins the shared REST abort path | review | none | normal | milestones/M006-list-models-abort-path.md |
| M005 | One abort path for the seven REST failure branches | done | none | normal | milestones/archive/M005-api-error-helper.md |
| M004 | Response and empty-list branch tests for the two unload functions | done | none | normal | milestones/archive/M004-unload-branch-tests.md |
| M003 | Class tests for the ten server-down abort sites | done | none | normal | milestones/archive/M003-no-server-class-tests.md |

## Candidates
<!-- Unnumbered ideas, one line each, ordered high, then normal, then low:
     - [high] idea, added YYYY-MM-DD, links
     - idea, added YYYY-MM-DD, links
     The opening token is [high] or [low] or absent (normal).
     See tracking-rules "Candidate priority token". -->
- The release walk needs a live-run step: full suite against a running LM Studio, then a re-record of stale fixtures, added 2026-09-17, DESIGN Conventions
- A guard that keeps every new `stop_if_no_server()` call site covered by a class test, added 2026-09-18, M003 scope
- A guard that keeps every REST wrapper handling a failed response listed in the failure table. The deleted guard read package sources that R CMD check does not ship, so it skipped there. It did run under `devtools::test()`, so it gated local runs (corrected M006 review), added 2026-09-18, M006 scope, see also the `stop_if_no_server()` guard row
- Help pages do not document the `rlmstudio_api_error` class or its `status` field at any of the eight REST wrappers. The abort contract is user-facing and undocumented, added 2026-09-18, M006 review finding 7
- The `list_models()` path test asserts the path but not the request verb, although the recorder reports it. A wrapper that switched to POST still passes, added 2026-09-18, M006 review finding 8, see also the row on `host` reaching the wire
- No unload test asserts that `host` reaches the wire, and none asserts that `lms_unload_all()` forwards it. Dropping `host = host` leaves the suite green, added 2026-09-18, M004 review finding 2
- A non-JSON failure body becomes the abort message in full, with no length bound. A proxy's HTML page reaches the user whole. A scalar JSON body reaches the user as the bare token, added 2026-09-18, M005 implement audit and M005 review finding 12
- The unload body assertions read `req$body$data`, an httr2 internal field, rather than the serialized request that `req_dry_run()` reports, added 2026-09-18, M004 review finding 3
- Three unload tests do not discriminate their branch. They are the character-vector shape, the non-JSON body, and the two message matchers, added 2026-09-18, M004 review findings 5, 8, and 11
- Fold the inline `req_perform` closures in `test-load.R` and `test-chat.R` into the shared recorder, leaving the two styles D-004 sanctions, added 2026-09-18, M004 review finding 7
- When only R-devel breaks, a red `ubuntu-latest (devel)` job still blocks the merge. Decide its disposition, added 2026-09-17, M002 review finding 6
- [low] Make the headless CI job install LM Studio or rename it to say what it runs, added 2026-09-17, DESIGN Known issues
- [low] Unify the four workflow files on one `actions/checkout` version, a `concurrency` group, and a `workflow_dispatch` trigger, added 2026-09-17, M002 findings 7 and 8
