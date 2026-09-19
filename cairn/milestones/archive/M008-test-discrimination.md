# M008: Tests that fail on the branch they name

**Status:** done (2026-09-19, PR #9 https://github.com/jmgirard/rlmstudio/pull/9)

**Goal:** Close the seven recorded gaps where a test passes although the code path it names is broken.

**Outcome:** `request_target()` in `tests/testthat/helper-mock-http.R` now reports the host
header and the parsed body from `httr2::req_dry_run()`, beside the method and path. Each
`api_error_callers` entry's `call` takes a host, so one expression serves the failure-table
loop and a new loop. That loop asserts the host on every request the eight wrappers record,
and a second test covers `lms_unload_all()`. The two `test-unload.R` body assertions moved off
`req$body$data` onto the serialized body. The raw-body fallback gained a `text/plain` test
beside the unparseable `application/json` one. The plain-vector shape test feeds numbers, so
`as.character()` carries the result. Both nothing-loaded assertions match the full message
with `fixed = TRUE`, and `test-list.R` asserts `GET`. The inline `req_perform` closures in
`test-load.R` and `test-chat.R` fold onto `local_request_recorder()`, exposing that
`lms_load()` without `force = TRUE` sends two requests.

**Decisions:** none milestone-local. The plan gate chose the eight-wrapper list as the domain
and `req_dry_run()` as the request reader. D-004 and D-005 govern the recorder.

**Review:** One pass, all eight criteria verified against six plants, gate clean with the
8-criteria advisory already justified. The three-lens fan-out returned seven findings, all
from the diff-bug lens. One was actioned: the host loop now reads every recorded request,
not the first alone. One was refuted by plant, one recorded, two to candidate rows, two rejected.
