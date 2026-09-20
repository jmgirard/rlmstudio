# M010: The package can tell a usable LM Studio server from an open port

**Status:** done (2026-09-20, PR #11 https://github.com/jmgirard/rlmstudio/pull/11)

**Goal:** `devtools::check()` passes on a machine with LM Studio installed, in whatever state.

**Outcome:** A new exported `lms_server_ready(host, timeout, token)` in
`R/serve.R` sends one GET to `api/v1/models` and returns `TRUE` only for a 200
whose body passes the new `is_model_list()` helper: a nameless list whose every
entry is a named list. Every other answer returns `FALSE` without raising,
though four input faults still abort; `timeout` defaults to 2. Both vignettes
assign `lms_ready` in a `check-ready` chunk and gate every later REST chunk on
it. The "Server not running" section of `R/conditions.R`, inherited by twelve
man pages, ties `rlmstudio_no_server` to a connection that cannot be opened and
points at the new function.

**Decisions:** none milestone-local. D-004 and D-006 governed the test styles.

**Review:** three-lens fan-out at the user-facing tier; the blame lens gave F13
and the prior-review lens found nothing to regress. Seven of the diff-bug
lens's twelve findings were fixed: F1 and F2 tightened the body predicate and
the status check, each gaining a test shown to go red on the planted defect;
F4 re-checks readiness inside `with-daemon`; F6 widened the refused-connection
claim; F7 dropped a hardcoded `#> [1] TRUE`; F11 to F13 corrected tracking
text. F3, F5, F8 and F9 became candidate rows, and none hit the return floor.
