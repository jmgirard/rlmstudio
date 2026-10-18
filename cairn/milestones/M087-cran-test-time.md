<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M087: CRAN skips the slow tests and runs the request-body tests

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — CRAN and the reverse-dependency checks of httr2 and jsonlite run the test suite   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m087-cran-test-time   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A CRAN check runs the request-body tests and skips the test blocks that take a second or more.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** Absorbs the candidate row "Skip more slow tests on CRAN" in full, both parts. Move each request-body test out of `tests/testthat/test-arg-guards.R`, which M081 skips on CRAN, into a new `tests/testthat/test-request-body.R` with no CRAN skip. A helper that only the moved tests use moves with them, and one that both files use goes to a `helper-*.R` file. Time each test block in CRAN mode (`NOT_CRAN=false`) and add `skip_on_cran()` at the top of each block outside `test-request-body.R` that takes 1 s or more. No NEWS entry, because users see no change.

**Out:**
- The three file-level skips of M081 (`test-arg-guards.R:4`, `test-flag-args.R:4`, `test-name-faults.R:4`): they stay.
- A Windows R-devel job: the "Add Windows to the weekly R-devel job" candidate row.
- Faster test code, such as fewer cases in a loop: the blocks keep their cases and run off CRAN.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: Each `test_that()` block of `tests/testthat/test-arg-guards.R` whose body, at the branch cut, calls `sent_messages(`, `request_body_text(`, or `request_target(` directly is in `tests/testthat/test-request-body.R` and not in `test-arg-guards.R`. `test-request-body.R` calls no `skip_on_cran()`. The sorted test names that a `NOT_CRAN=true` run with `testthat::ListReporter` records for `test-arg-guards.R` at the branch cut equal the sorted names it records for the two files after the move, as a `diff` of the two lists shows.
- [x] AC2: A CRAN-mode run of `tests/testthat/test-request-body.R` (`NOT_CRAN=false`) passes, skips no block, and reports the same number of expectations as a run with `NOT_CRAN=true`.
- [x] AC3: Each top-level `test_that()` block outside `test-request-body.R`, `test-arg-guards.R`, `test-flag-args.R`, and `test-name-faults.R` that the T3 timing run times at 1 s or more, its subtest rows summed, calls `skip_on_cran()` as its first statement. The T3 run is a CRAN-mode `devtools::test()` (`NOT_CRAN=false`) with no LM Studio server running.
- [x] AC4: `devtools::test()` and `devtools::check()` report no failures, errors, or warnings, and so does a CRAN-mode `devtools::test()` with `NOT_CRAN=false`.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1, T2
- AC2 → T2
- AC3 → T3
- AC4 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive change is amend-via-gate. -->

- [x] T1: At the branch cut, save the sorted test names that a `NOT_CRAN=true` `ListReporter` run records for `test-arg-guards.R`, because loops build some names at run time (`:141`, `:155`, `:1034`). List its blocks that call `sent_messages(`, `request_body_text(`, or `request_target(`. On 2026-10-18 a read found 13 sites, one a loop of 5 names (`:1034`, `:1081`, `:2215` to `:3602`). Rerun the search at the task. Read each block for the helpers it calls (`sent_messages` `:2206`, the `stream_*` helpers `:929-1022`, `no_cell_frame` `:2886`, `classed_sent` `:3166`, and others).
- [x] T2: Create `tests/testthat/test-request-body.R` with the T1 blocks and the helpers that only they use. Put a helper that both files use in a `helper-*.R` file. Run the AC1 `diff`. Run the new file with `NOT_CRAN=false` and with `NOT_CRAN=true`, and compare the expectation counts.
- [x] T3: With no LM Studio server running, time every block in CRAN mode: `NOT_CRAN=false` and `as.data.frame(devtools::test(reporter = testthat::ListReporter$new()))`, reading the `real` column and summing the subtest rows of each top-level block (LESSONS M019). Add `skip_on_cran()` as the first statement of each block at 1 s or more outside the four files that AC3 names. Write one work-log line with the run date, the blocks, their times, and the total time before and after.
- [x] T4: `devtools::test()`, `devtools::check()`, and the CRAN-mode `devtools::test()` clean.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which work — the "Skip more slow tests on CRAN" row, planned as M087 beside M085 and M086.
- 2026-10-18: plan chose a 1 s per-block bar from a timing run over the four file groups that the row names, because the row's 22 s and 12 s have no per-block split and an Explore read found no timed wait in `test-chat*.R` or `test-api-error.R`; falsified by a CRAN check time above 600 s after M087.
- 2026-10-18: plan chose a new test file over removing the file-level skip of `test-arg-guards.R` because M081 cut the CRAN-mode test time from 97.5 s to 51.7 s with that skip; falsified by a timing run where the whole file takes under 5 s.
- 2026-10-18: Explore (Haiku) read M081's skip (`skip_on_cran()` at line 4 of three files), 13 request-body sites in `test-arg-guards.R`, and the loop blocks of the named files; the only timed waits are in `test-mock-http-helper.R:140` and `:200`.
- 2026-10-18: collision check: absorbs the "Skip more slow tests on CRAN" row in full; M081 (archived) made the three file skips; D-038 (nested tests) holds for any new loop; inbox has 0 open issues and 0 open PRs.
- 2026-10-18: criteria audit (full mode, fresh Opus reader), 3 findings, all taken: AC1 compares the test names a `ListReporter` run records, because loops build some names at run time, and its domain is direct calls; AC3 lost its work-log sentence (an instrument promise), now counts top-level blocks with subtest rows summed, and names a run with no LM Studio server.
- 2026-10-18: no changelog entry: users see no change.
- 2026-10-18: lessons surfaced: M005 (a test that reads `R/` skips under `R CMD check`), M019 (the `as.data.frame()` table of a test run drops results recorded around nested tests; read timing per top-level block).
- 2026-10-18: implement started; branch m087-cran-test-time cut from main at c55b31d.
- 2026-10-18: T1: a `NOT_CRAN=true` `ListReporter` run of `test-arg-guards.R` at c55b31d records 1041 test names, none repeated, 0 failures (sorted list sha256 c1d264cb4b08). A parse of the file finds 13 top-level expressions that call the three helpers (the loop at `:1034` and 12 blocks, `:1081` to `:3602`). They need 19 top-level helpers of the file: 6 only they use (`stream_reply`, `sent_messages`, `first_msg`, `later_msg`, `classed_sent`, `class_forms`) and 13 that kept blocks also use; no other test file defines any of the 19 names.
- 2026-10-18: implement choice: the 13 shared helpers go to one new file, `tests/testthat/helper-arg-guards.R`, in their order in the file, with their comments.
- 2026-10-18: T2: a parse-based R script split the file by top-level expression, each with the comments above it, and `cp` placed the three pieces (a byte copy, not the Write tool, for 3678 lines); headers and two comments that named "the test above" across the cut were then edited by hand. AC1 `diff` of the sorted names, 1041 before and after, is empty; `test-request-body.R` runs 172 rows and 269 expectations, 0 skipped, with `NOT_CRAN=false` and with `NOT_CRAN=true`. DESIGN.md test line names the new file. `devtools::test()`: 0 failed, 3 skipped (no live server).
- 2026-10-18: T3 timing run (2026-10-18, at c9d428b, `NOT_CRAN=false`, no server on port 1234, `lms server status` "not running"; the per-row `real` sums to the 64.0 s wall time, so subtest rows are not counted twice): 9 blocks at 1 s or more outside the four files, each now starts with `testthat::skip_on_cran()`: `test-mock-http-helper.R` "request_target() reads a request when the program on the first dry-run port never replies" 5.01 s and "request_body_text() spreads its time limit over the dry-run tries" 2.51 s; `test-chat-batch-usage.R` "an unreadable reply fails its input as the single call fails" 4.02 s; `test-model-list-shape.R` "each rule of the model list aborts list_models() with rlmstudio_bad_response" 3.88 s; `test-chat-batch.R` "a reply with no readable text fails only its own input on every route" 3.22 s; `test-chat.R` "lms_chat_openresponses names the first logprobs rule a reply breaks" 2.90 s and "lms_chat_openresponses aborts as a bad response when a reply has no readable text" 1.08 s; `test-server-ready.R` "a port held by something else passes the TCP probe and fails here" 1.02 s and "an open port whose listener never answers is not ready" 1.01 s. Total CRAN-mode time 64.0 s before, 40.0 s after (skips 4 to 13, 0 failed); the slowest block left is 0.86 s. DESIGN.md test line names the per-block skips. `devtools::test()`: 0 failed, 3 skipped.
- 2026-10-18: T4: `devtools::test()` 0 failed, 0 warnings, 3 skipped; CRAN-mode `devtools::test()` (`NOT_CRAN=false`) 0 failed, 0 warnings, 13 skipped; `devtools::check()` 0 errors, 0 warnings, 0 notes.
- 2026-10-18: claim audit: 67 claims read, 1 corrected — tests/testthat/test-request-body.R (its header said every shared helper is in helper-arg-guards.R, but it also uses helper-mock-http.R and helper-chat-bodies.R; now it names the helpers that test-arg-guards.R defined, and the re-read found it true).
- 2026-10-18: implement done; status review.

## Review
<!-- owner: review · exclusive -->

- Sync: `origin/main` is c55b31d, the branch cut; the branch holds it, so no merge was needed. No PR yet; the Copilot round is off.
- AC1 evidence (2026-10-18): a parse of the cut file (`git archive c55b31d`) finds 13 top-level expressions that call `sent_messages(`, `request_body_text(`, or `request_target(` (lines 1034, 1081, 2215, 2256, 2534, 2649, 2892, 3176, 3437, 3504, 3546, 3579, 3602); the source text of each is a top-level expression of `test-request-body.R` and of none in the new `test-arg-guards.R`, which has 0 calls; a control run with the two files swapped reports FAIL. `grep -c skip_on_cran tests/testthat/test-request-body.R` is 0. A `NOT_CRAN=true` `ListReporter` run records 1041 names for `test-arg-guards.R` at the cut and 1041 for the two files at HEAD 8526de6; the `diff` of the sorted lists is empty.
- AC2 evidence (2026-10-18): `devtools::test(filter = "^request-body$")` with `NOT_CRAN=false` gives 172 rows, 269 expectations, 0 failed, 0 skipped, 0 errors; with `NOT_CRAN=true` it gives the same 172 rows and 269 expectations. Control: the same `NOT_CRAN=false` run of `test-arg-guards.R` records 0 rows, so the mode setting does reach `skip_on_cran()`.
- AC3 evidence (2026-10-18): the T3 run's saved per-block table (CRAN mode at c9d428b, no server, 64.0 s wall) lists 9 top-level blocks at 1 s or more outside the four files, the same 9 the T3 work-log line names. A parse of each file at HEAD finds each of the 9 blocks once, and the first statement of each body is `testthat::skip_on_cran()`; the same parse of the cut tree finds all 9 with a different first statement (control). Cross-check, not the AC3 instrument: a repeat of the timing on the c9d428b tree, run right after a `devtools::check()`, took 97.3 s wall and put 16 blocks at 1 s or more; all 9 of the T3 set are among them, and the 7 others (5 "every wrapper reports the same text: …" blocks of `test-api-error.R` at 1.01 to 1.48 s, `test-bare-body.R` "a bare-value body fails only its own input in every batch format" 3.93 s, `test-chat-batch.R` "a failed input in any format does not end the batch" 1.21 s) took 0.89 s or less in the T3 run. The 1 s bar therefore moves with machine load; the plan's recorded falsifier for it is a CRAN check time above 600 s.
- AC4 evidence (2026-10-18, HEAD 8526de6): `devtools::test()` (`NOT_CRAN=true`) 0 failed, 0 warnings, 0 errors, 3 skipped (no live server); CRAN-mode `devtools::test()` (`NOT_CRAN=false`) 0 failed, 0 warnings, 0 errors, 13 skipped; `devtools::check()` 0 errors, 0 warnings, 0 notes, its test step OK.
- Consistency gate (2026-10-18): `cairn_validate.py` all checks passed (exit 0); `devtools::document()` leaves no diff; `README.Rmd`, `README.md`, and `NEWS.md` untouched by the branch (no NEWS entry, as the plan states: users see no change); `pkgdown::check_pkgdown()` no problems; no new top-level files; `devtools::check()` 0/0/0 (AC4); no DESIGN principle changed, so `cairn_impact` is skipped.
