# M003: Class tests for the ten server-down abort sites

**Status:** done (2026-09-18, PR #4 https://github.com/jmgirard/rlmstudio/pull/4)

**Goal:** Assert the `rlmstudio_no_server` condition class at every `R/` call
site that aborts on a stopped server.

**Outcome:** `grep -rn "stop_if_no_server(" R/` reports ten call sites in ten
distinct functions. `list_models()`, `lms_download()`, and
`lms_download_status()` already had class tests from M001. This milestone
added the other seven, covering `lms_load()`, `lms_unload()`,
`lms_unload_all()`, and the four chat functions. It also added three tests
that `lms_chat()` passes the class through, one per `api_type` value. Every
test mocks `is_server_running` to `FALSE` and asserts the class alone. No
file under `R/` changed, the suite reports 68 passes, and `check()` is clean.

**Decisions:** none

**Review:** Three fresh-context reviewers. The blame-history and prior-review
lenses reported nothing against the change. The diff-bug lens reported six
findings. Finding 1 was fixed on the branch. The tests for `lms_load()`,
`lms_unload_all()`, and `lms_chat_batch()` passed with their own call site
deleted, because each delegates to a function that checks too. Each of those
tests now mocks the delegate out. Finding 3 became a candidate row. The other four
were rejected. Nothing was retired or graduated.
