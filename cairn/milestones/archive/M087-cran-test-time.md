# M087: CRAN skips the slow tests and runs the request-body tests

**Status:** done (2026-10-18, PR #90 https://github.com/jmgirard/rlmstudio/pull/90).

**Goal:** A CRAN check runs the request-body tests and skips the test blocks that take a second or more.

**Outcome:** The 13 top-level expressions of `test-arg-guards.R` that call
`sent_messages(`, `request_body_text(`, or `request_target(` moved unchanged to
the new `tests/testthat/test-request-body.R`, which has no CRAN skip. The 13
helpers that both files use moved to `tests/testthat/helper-arg-guards.R`. The
1041 test names match before and after. Nine blocks that took 1 s or more in
one CRAN-mode run (2026-10-18, at c9d428b) start with `testthat::skip_on_cran()`,
in `test-mock-http-helper.R` (2), `test-chat.R` (2), `test-server-ready.R` (2),
`test-chat-batch-usage.R`, `test-chat-batch.R`, and `test-model-list-shape.R`.
Local CRAN-mode time went from 64.0 s to 40.0 s. A repeat run under load put
16 blocks over 1 s, so the bar is a snapshot. Falsifier of the 1 s bar: a CRAN
check time above 600 s. No NEWS entry.

**Decisions:** none.

**Review:** 4 criteria verified. Three lenses gave 14 findings: 1 fixed (the
DESIGN.md sentence now names the one timing run), 1 follow-up (new row
"request-body checks in skipped files"), 12 rejected (8 planned change, 3 style,
1 false). CI green on the first wait. Graduated the "Skip more slow tests on
CRAN" row.
