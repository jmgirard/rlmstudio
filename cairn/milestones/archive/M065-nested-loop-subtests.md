# M065: An error in one test-loop pass no longer stops the later passes

**Status:** done (2026-09-30, PR #65 https://github.com/jmgirard/rlmstudio/pull/65).

**Goal:** An error in one pass of 78 test loops no longer stops the later
passes of that loop.

**Outcome:** The body of 78 loops is wrapped in a nested `test_that()`, one
subtest per pass: 36 in `test-arg-guards.R` plus 9 inner loops the wraps
exposed, and 42 `for (name in ` loops in 15 other files. Suggests lists
`testthat (>= 3.3.0)` (D-038). testthat 3.3.2 drops a parent result recorded
before a nested subtest, so parent checks sit after the last subtest or in
their own subtest. Three blocks
read `arg_placeholders` directly, not `baseline_args()`. `cairn/tools/loop-sweep.R`
lists `flat` and `nested` loops and `before-subtest` parent checks.

**Decisions:** D-038 (the floor). The plan gate chose nested blocks over
top-level blocks per pass, and 78 loops over all 270. The other 192 stay in
a candidate row.

**Review:** Two passes, three lenses each. Pass 1 returned M065 once (O1: a
parent failure before a subtest no longer failed `R CMD check`), fixed by T7
to T10. Pass 2 found three leftover `fail()` sites (Q1) and sweep blind spots
(Q2, Q5), fixed at the gate. The LESSONS M019 line gained the nested-test
rule. The `req_dry_run()` test error became its own high candidate row.
