# M052: The two list functions check their arguments before any request

**Status:** done (2026-09-29, PR #52 https://github.com/jmgirard/rlmstudio/pull/52).

**Goal:** `list_models()` and `list_instances()` abort with a clear message,
before the server probe, on a bad `type`, `quiet`, `loaded`, or `detailed`.

**Outcome:** `rlm_check_type()` with `type_fault()`, and `rlm_check_flag()`
with `flag_fault()`, in `R/utils-args.R`. Both list functions call them above
`stop_if_no_server()`. The aborts are unclassed and name the argument and the
broken rule. `type` takes any non-blank strings, so an unknown type still
returns an empty result. `quiet = NULL` is new and reads the option through
`is_quiet()`. Help pages, the conditions page, and NEWS are updated. Tests are
in `tests/testthat/test-list-args.R`.

**Decisions:** none cross-cutting. The plan gate chose non-blank strings over
a fixed type list, accepted `quiet = NULL`, and took `loaded` and `detailed`
into scope.

**Review:** One pass of three lenses, 6 of 6 criteria verified. Four gate
fixes: a NEWS sentence on `quiet = 1`, a `quiet = TRUE` test, code style in
the flag messages, and a split conditions sentence. The `quiet = FALSE`
option finding joined the flags candidate row. The encoding finding became a
new row. Six findings were rejected with reasons.
