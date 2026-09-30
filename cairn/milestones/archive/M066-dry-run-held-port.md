# M066: A test that reads a request survives a dry-run port that another program holds

**Status:** done (2026-09-30, PR #66 https://github.com/jmgirard/rlmstudio/pull/66).

**Goal:** If another program holds the dry-run port on 127.0.0.1, a test that
reads what a request sends still passes.

**Outcome:** Every dry-run read in the tests goes through `request_dry_run()`
in `helper-mock-http.R`. With curl 8.0.0, `curl_echo()` binds 0.0.0.0 and
sends to 127.0.0.1, which a program on 127.0.0.1 alone can take. The helper
times out each try and tries again on an empty result, any `curl_error`, or
httpuv's "Failed to create server". After 5 tries, it stops, names the likely
cause, and keeps the last error. `request_body_text()` gives each try one
sixth of its limit. `test-mock-http-helper.R` holds the port with listeners.

**Decisions:** Retry in one shared helper, not a mock of curl's port picker
around every dry run. A curl error can come from the request itself, so the
stop message keeps the last error.

**Review:** Two passes, three lenses each. Pass 1 returned M066 once for a
reset, banner, or silent listener (fixed by T5 to T7). Pass 2 fixed two gate
findings: a request error blamed on another program, and 5 s tries past a
10 s limit. The time-limit test skips on Linux, which refuses the echo bind.
A Linux run of the retry tests is a candidate row. LESSONS M004 gained the
socket rule.
