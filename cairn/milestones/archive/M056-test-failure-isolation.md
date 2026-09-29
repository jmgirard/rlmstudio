# M056: Test failures that name each broken function and reply check

**Status:** done (2026-09-29, PR #56 https://github.com/jmgirard/rlmstudio/pull/56).

**Goal:** Each broken function or reply check in three test areas shows as
its own test failure.

**Outcome:** The 16 loops over function names in `test-arg-guards.R` now sit
at top level. Each defines one `test_that()` block per function, 117 blocks
in all. `ttl_domain()` no longer calls `fail()`, and its missing-call check moved
into the ttl domain test. The live id-column test in `test-list-instances.R`
lost its `tryCatch()`, so a refused model list fails it. `helper-chat-bodies.R`
gained "an item that is null" and "a part that is null". These shapes pin the
order of the item/message and part/output_text checks in `R/chat.R`. The file
`test-arg-guards.R` is now Air-formatted.

**Decisions:** none cross-cutting. The plan gate chose one block per function
over a wrapper helper that names the function in an error.

**Review:** One pass of three lenses. All 5 criteria passed with fresh
evidence, including a plant in `lms_download_status()` and four check-order
swaps. No reviewer found a bug. The gate fixed the Air style drift (O1). It
rejected three low findings and noted five as intended. The inner probe loops stay on their candidate row.
