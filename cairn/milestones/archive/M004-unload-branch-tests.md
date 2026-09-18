# M004: Response and empty-list branch tests for the two unload functions

**Status:** done (2026-09-18, PR #5 https://github.com/jmgirard/rlmstudio/pull/5)

**Goal:** Cover the untested response and empty-list branches of the two unload
functions with tests that go red on a broken branch.

**Outcome:** 15 tests in `tests/testthat/test-unload.R`, plus a new
`tests/testthat/helper-mock-http.R`. Its `local_request_recorder()` mocks
`httr2::req_perform` and records each request. It applies the request's own
error policy, so a caller that drops `req_error()` turns the failure tests red.
`request_target()` reads the verb via `httr2::req_dry_run()`, which is why
`httpuv` joins Suggests. `lms_unload()` gains tests for the success path, the
dots merge, and its three failure-message sources. `lms_unload_all()` gains
tests for the nothing-loaded path, the unload loop with forwarded dots, and the
four `loaded_instances` shapes. No change under `R/`.

**Decisions:** D-004 (two sanctioned HTTP-testing styles, chosen by whether a
live server can produce the response), D-005 (`httpuv` in Suggests).

**Review:** Three-lens fan-out. The prior-review and blame-history lenses found
nothing blocking. The diff-bug lens reported 12 findings, each plant-naming
claim re-run before triage, none meeting the return floor. Two fixed now, five
became four candidate rows, three rejected, two noted. CI then failed two tests
the local suite had passed, fixed by D-005.
