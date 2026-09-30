# M057: One meaning for each flag argument

**Status:** done (2026-09-30, PR #57 https://github.com/jmgirard/rlmstudio/pull/57).

**Goal:** Each TRUE/FALSE argument of an exported function accepts only the
values that its help page names, with one meaning for each value.

**Outcome:** `rlm_check_flag()` now guards every flag of the 11 exported
functions that have one, above the server probe or the `lms` CLI run. That
includes `simplify` and `logprobs` of the chat functions. `quiet` defaults to
`NULL` in `list_models()`, `list_instances()`, and `lms_chat_batch()`. An
explicit `TRUE` or `FALSE` decides over the option. The two `lms_load()` load
settings take `TRUE`, `FALSE`, or `NULL` with no `as.logical()`. A `logprobs`
in the dots of `lms_chat_batch()` and `lms_chat_native()` is checked. The
`?rlmstudio` option entry now reaches its help page. `test-flag-args.R` scans
the exported formals for its domain.

**Decisions:** D-028 (`quiet` default) and D-029 (native `logprobs` check).

**Review:** One pass of three lenses. All 7 criteria passed, and no reviewer
found a code bug. The gate fixed six doc and test findings. They were a
stale `list_instances()` return note and "shows" in place of "starts" for
the bar. The others were a fuller NEWS old rule, an internal doc note, four
test gaps, and a stale test comment. Two faults
already on main (O6, O7) went to one candidate row. One note was rejected.
