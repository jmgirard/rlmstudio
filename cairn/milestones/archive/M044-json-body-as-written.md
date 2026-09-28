# M044: The functions that send a JSON body send the text that jsonlite writes

**Status:** done (2026-09-28, PR #44 https://github.com/jmgirard/rlmstudio/pull/44)

**Goal:** Each function that sends a JSON request body sends the text that
`jsonlite::toJSON()` writes from the body, with the options of the
`messages` trial write. It does not send a copy that httr2 rebuilds first.

**Outcome:** `rlm_json_text()` and `rlm_req_body()` in `R/chat.R` write
the body once and attach it with `httr2::req_body_raw()`. All seven
`req_body_json()` sites and `messages_write_fault()` use them. Zero-width
matrix and array columns of `messages` are now sent. `POSIXlt` values no
longer recurse. `obfuscated()`, `packageVersion()`, and `person()` values
in `...` abort with the jsonlite error. NEWS has one entry.

**Decisions:** none. A first cut on a bare-jsonlite probe stopped at T2
and was re-cut. Its empty-row rule moved to M046.

**Review:** Three-lens fan-out, all four criteria passed on the first
pass. The blame and prior-review lenses found nothing. The gate fixed
four of seven diff findings: three NEWS gaps with two new test cases, and
one test comment. It rejected three. The `POSIXlt` candidate row closed
here. One LESSONS line was extended.
