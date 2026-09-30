# M065: An error in one test-loop pass no longer stops the later passes

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — the deliverable is test code, a test dependency floor, and a dev script, which no package user runs
- **Branch/PR:** m065-nested-loop-subtests

## Goal

An error in one pass of 78 test loops no longer stops the later passes of
that loop.

## Scope

**In:** This milestone promotes the candidate row from the M056 plan gate.
`cairn/tools/loop-sweep.R`, committed with this plan, lists each loop with
expectations that sits directly in a `test_that()` block. At the plan
commit it prints 270 rows, all `flat`. This milestone wraps the body of 78
of them in a nested `test_that()`, one subtest per pass. They are the 36
rows for `test-arg-guards.R` and the 42 rows elsewhere whose header starts
`for (name in `, in 15 files. Inner loops that a wrap exposes in
`test-arg-guards.R` get the same treatment. The testthat floor in Suggests
rises to 3.3.0, the release that added nested tests (D-038).

**Out:** The other 192 rows, in 34 files, go to one candidate row. So do the
inner loops that a wrap exposes outside `test-arg-guards.R`. A loop that
defines top-level blocks already gives one block per pass.

## Acceptance criteria

- [x] AC1: On the branch, `Rscript cairn/tools/loop-sweep.R` prints no
      `flat` row for `test-arg-guards.R`. It also prints no `flat` row whose
      loop header starts with `for (name in `. Each (file, block, header)
      triple that the sweep prints at the plan commit prints on the branch
      at least as many times.
- [x] AC2: At the plan commit, the sweep prints 8 rows for
      `tests/testthat/test-cli-output.R` with the header
      `for (name in names(cli_callers))`. On the branch, each of those loops
      defines one subtest per name in `cli_callers`. Each subtest
      description contains its name. In a scratch copy of the branch, the
      first statement in the body of `lms_daemon_stop()` in `R/daemon.R` is
      `stop("planted")`. `testthat::test_file()` on that file then reports
      an errored or failed subtest of those loops whose description contains
      `lms_daemon_stop`. Every subtest of those loops whose description
      contains `lms_server_start`, `lms_server_stop`, or `lms_daemon_start`
      passes.
- [x] AC3: In a scratch copy of the branch, the `match` field of the
      `no values` probe in `id_probes` of `tests/testthat/test-arg-guards.R`
      is `"planted"`. Run `testthat::test_file()` on that file. Take each
      function that `guarded_exports(c("model", "job_id"))` returns, and
      its block "a bad model or job id aborts <name>(), named, before any
      request". A subtest of that block whose own description ends with
      `no values` errors or fails. Each subtest of that block whose own
      description ends with another `label` of `id_probes` passes. The own
      description is the text after the last ` / ` of the reported test name.
- [x] AC4: `DESCRIPTION` lists `testthat (>= 3.3.0)` in Suggests.
- [x] AC5: `devtools::test()` reports no failure and no error.
      `devtools::check()` gives 0 errors, 0 warnings, and no note that main
      at a42a1ab does not give.

## Coverage

- AC1 → T2, T3, T4, T6
- AC2 → T3, T5
- AC3 → T2, T5
- AC4 → T1
- AC5 → T1, T6

## Tasks

- [x] T1: In `DESCRIPTION`, raise the Suggests entry to
      `testthat (>= 3.3.0)`, as D-038 records.
- [x] T2: In `test-arg-guards.R`, wrap the body of each of the 36 loops in
      one `test_that()`. Its description names the pass by the probe
      `label` or by the value. Move setup that can raise into the subtest.
      Wrap the loops that this exposes in the same way. Repeat until the
      sweep prints no `flat` row for the file.
- [x] T3: Wrap the 23 `for (name in ` loops in `test-cli-output.R`,
      `test-list-args.R`, `test-body-parse.R`, and `test-body-write.R` in the
      same way. Each description contains the name. Leave an inner loop
      that a wrap exposes as it is.
- [x] T4: Do the same for the 19 `for (name in ` loops in the other 11
      files.
- [x] T5: Run the AC2 and AC3 plants in scratch copies of the branch. Make
      sure that each run holds subtests for the other names or labels
      before you trust its green. Log the counts of failed, errored, and
      passed subtests.
- [x] T6: Run the sweep, `devtools::test()`, and `devtools::check()`. If
      `check()` gives a note, run it on a42a1ab to compare.
- [x] T7: (review O1, O2) A parent block can hold an expectation that
      runs before or between its nested subtests. Move each such
      expectation into its own nested subtest or after the loops. An
      inner loop in `test-arg-guards.R` whose body cannot raise becomes
      one expectation with no loop. Plant a wrong value at
      `test-store.R:69`, and make sure that
      `test_dir(stop_on_failure = TRUE)` stops.
- [x] T8: (review O7) Make `loop-sweep.R` report each `expect_*()` call
      that a parent block runs before or between its nested `test_that()`
      calls. Show rows at the commit before T7, and no rows after T7.
- [x] T9: (review O3, O4, B2) In `test-arg-guards.R`, give distinct
      subtest names to three sets of loops. The first is the two `cases`
      loops near `:680` and `:698`. The second is the loop pair in the
      `empty_rows()` test near `:2500`. The third is the "a request of"
      subtests near `:1048`.
- [ ] T10: Rerun the sweep, the AC2 and AC3 plants, `devtools::test()`,
      and `devtools::check()`. Then set the status to review.

## Work log

- 2026-09-30: created by /milestone-plan. It promotes the candidate row from the M056 plan gate, which counted about 30 loops. The sweep counts 270.
- 2026-09-30: criteria audit, reduced mode (internal tier), by a fresh Opus reader. It returned six findings, all fixed before the gate. The AC1 base count moved to Scope, and AC1 compares whole triples. AC2 names its loops by sweep row, plants in the first body statement, and limits the failing subtest to its loops. AC3 matches the end of a subtest's own description. T3 and T4 leave exposed inner loops flat.
- 2026-09-30: plan gate chose nested `test_that()` blocks over top-level blocks per pass, as M056 built. Nesting keeps the shared setup and mocks in the parent block, at the cost of a testthat 3.3.0 floor. Falsified by a run where an error in a nested subtest still stops a later pass.
- 2026-09-30: plan gate chose 78 loops over all 270 in two milestones. The other 192 go to a candidate row. Falsified by a run where one of those loops hides passes after an error.
- 2026-09-30: implement started on m065-nested-loop-subtests. The plan left no choice open, so the question gate was skipped. A scan found six probe loops in `test-arg-guards.R` that assign a variable the code after the loop reads. It found no `next`, `break`, or `skip()` in the 78 loop bodies.
- 2026-09-30: T1 done. `DESCRIPTION` Suggests now lists `testthat (>= 3.3.0)`. The suite runs in T6, after the wraps.
- 2026-09-30: T3 and T4 delegated to one Sonnet agent, and T2 to one Opus agent. The Sonnet agent wrapped the 42 name loops in 15 files, and the sweep prints 42 `nested` rows for them. `git diff -w` holds the 42 wraps and one `expect_identical()` split over lines, nothing else. Each file ran 0 failed and 0 errors before and after.
- 2026-09-30: five files counted fewer expectations after the wraps. A scratch run showed why. In the data frame of `test_file()` results, a parent block that holds subtests loses its own results from before the subtests, a failure included. The progress, check, and summary reporters still print that failure as FAIL 1, so `devtools::test()` and `R CMD check` still catch it.
- 2026-09-30: T2 done by the Opus agent. It wrapped the 36 rows and the 9 inner loops that the wraps exposed. The sweep prints 45 `nested` rows and no `flat` row for `test-arg-guards.R`. Three counters that the parent block checks after a loop now add with `<<-`. The scan's other three hazards were false: the code after the loop assigns the variable again before it reads it. A plant of `<-` in one counter turned `expect_identical(n_cases, 105L)` red. A reporter that counts every result gave 3678 passes before and after, with 0 failed and 0 errors.
- 2026-09-30: one agent run of the new `test-arg-guards.R` took over 10 minutes and recorded 1 error, with no test name kept. A rerun took 22 s and was clean. The other agent ran tests at the same time. The candidate row for the error that comes and goes (M059) covers it.
- 2026-09-30: T5 done. AC2 plant, `stop("planted")` first in `lms_daemon_stop()`: the 8 `cli_callers` loops gave 32 subtests. All 8 for `lms_daemon_stop` failed or errored, and 0 of the 24 for the other three functions did. AC3 plant, `match = "planted"` on the `no values` probe: for each of the 10 functions, its one `no values` subtest failed or errored, and 0 of its 12 other-label subtests did.
- 2026-09-30: T6 done. The sweep prints 290 rows on the branch and no `flat` row in scope, and no triple from the plan commit is missing. The first full `devtools::test()` gave 1 error at `test-arg-guards.R:1986`, `rawToChar(out$body)` "argument 'x' must be a raw vector" inside the dry run. That is the failure the `list_instances()` candidate row records at `test-ttl.R` and `test-arg-guards.R:1810` on main. Three reruns of the file and a second full run were clean. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-30: claim audit: not owed, internal tier.
- 2026-09-30: all tasks done, status set to review.
- 2026-09-30: review returned M065 to in-progress, defect return 1. The maintainer judged review finding O1 a defect that blocks the merge. A parent expectation before or between nested subtests no longer fails `R CMD check`. T7 to T10 hold the requested changes.
- 2026-09-30: correction of the 2026-09-30 line on the five files that counted fewer expectations. `R CMD check` does not catch a failure that a parent block records before its nested subtests. The reporter prints FAIL 1, but `test_check()` does not stop (review O1).
- 2026-09-30: review checkpoint (in progress). AC1 to AC4 evidence recorded and ticked. `devtools::test()` gave 0 failed and 0 errors. `devtools::check()` and the Opus reviewer are still running.
- 2026-09-30: implement resumed after defect return 1. Main had not moved. Question gate: if the four O2 wraps are undone, four `for (name in ` loops go back to `flat`, which AC1 forbids. The maintainer chose to keep the wraps and move the parent expectations after the loops. T7's undo clause now applies only to inner loops in `test-arg-guards.R`, as one expectation with no loop.
- 2026-09-30: a scratch file under testthat 3.3.2 showed which parent results the `test_file()` data frame keeps. It drops passes before and after the nested subtests, and failures before or between them. It keeps a failure after the last subtest.
- 2026-09-30: T7 done. The T8 sweep found 21 parent expectations before a subtest at the pre-T7 head. Each moved after its loops or into its own subtest. The `other` loop at `test-arg-guards.R:1708` became one `expect_identical()` of the rules whose detail the message holds. The sweep then printed 0 such rows. A plant of `"planted"` in the export list of `test-store.R` stopped `test_dir(stop_on_failure = TRUE)` with "Test failures". Its diff showed `"planted"`. The same plant on the pre-T7 file did not stop. The five edited files ran 0 failed and 0 errors.
- 2026-09-30: after T7, `devtools::test()` gave 0 failed, 0 errors, 3 skipped, and 19365 passed. The drop from 19707 is the `other` loop, now one check per probe, and parent passes that the results table no longer counts.
- 2026-09-30: T8 done. `loop-sweep.R` adds rows with the status `before-subtest`, one per `expect_*()` call that a block runs before or between its nested `test_that()` calls. It skips calls inside a function literal. At 0b6d583, before T7, it prints 21 such rows, which hold every site that review O1 names. At d32ea11 it prints 0. Its other rows at 0b6d583 match the old script line for line. A scratch fixture of seven blocks gave rows for the three that hold an early call and none for the four that do not.
- 2026-09-30: T9 done. In `test-arg-guards.R` the two `cases` loops now name their subtests "<label> in a data frame" and "<label> in a list and a vector". The request loop names "request <i> of <label>". The `empty_rows()` pair names "at top level" and "one level down". Before T9, `test_file()` gave 15 full test names twice. After it, 0 of 995. `devtools::test()` gave 0 failed, 0 errors, 3 skipped, and 19371 passed.

## Decisions

## Review

- AC1 (2026-09-30): I ran the sweep on a `git archive` copy of a03fdc1 and on the branch. At the plan commit it prints 270 rows, all `flat`. Of these, 36 are for `test-arg-guards.R` and 42 have a `for (name in ` header. On the branch it prints 290 rows. No `flat` row is for `test-arg-guards.R`, which has 45 `nested` rows. No `flat` row has a `for (name in ` header, and 42 such rows are `nested`. Of the 268 distinct (file, block, header) triples at the plan commit, 0 print fewer times on the branch.
- AC4 (2026-09-30): `grep testthat DESCRIPTION` shows `testthat (>= 3.3.0),` at line 30, in the Suggests field.
- AC2 (2026-09-30): in a `git archive` copy of HEAD, `stop("planted")` is the first statement of `lms_daemon_stop()`. `test_file()` on `test-cli-output.R`, with a reporter that records each result and its full test name, gives 32 subtests under 8 parent blocks. The 8 parent names match the 8 plan-commit sweep rows with the header `for (name in names(cli_callers))`. Each subtest's own description is its function name. All 8 `lms_daemon_stop` subtests failed or errored. All 24 subtests for `lms_server_start`, `lms_server_stop`, and `lms_daemon_start` passed.
- AC3 (2026-09-30): in a `git archive` copy of HEAD, the `match` of the `no values` probe in `id_probes` is `"planted"`. `test_file()` on `test-arg-guards.R`, with the same recording reporter, ran in 26 s. `guarded_exports(c("model", "job_id"))`, evaluated from the file, returns 10 functions, and `id_probes` holds 13 labels. Each of the 10 blocks has 13 subtests, and each own description is one of the 13 labels. In each block the one `no values` subtest failed or errored, and 0 of the 12 other-label subtests did.
- AC5 (2026-09-30): `devtools::test()` on HEAD gave 0 failed, 0 errors, 3 skipped (live server tests), and 19707 passed. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, with tests OK in 89 s. With 0 notes, no compare run on a42a1ab is owed.
- Consistency gate (2026-09-30): `cairn_validate.py` exits 0 with every check PASS or OK. No principle changed, so `cairn_impact` is skipped. `devtools::document()` gives no diff. The branch changes no README or R source, and the repo has no `_pkgdown.yml`. The change is test code and a Suggests floor, so NEWS owes no entry. `cairn/` is already in `.Rbuildignore`.

Findings come from three fresh reviewers: Opus diff (O), Sonnet history (B), and Sonnet prior reviews (P). Each reviewer ranked its own findings. Dispositions are set at the approval gate.

- O1: a parent block can record a failure before or between its nested subtests. That failure no longer fails `R CMD check`. If `all_passed()` is FALSE, `test_check()` stops. `all_passed()` reads the results table, which drops those results. The reviewer planted a wrong value at `test-store.R:69`: main stopped with "Test failures", the branch printed FAIL 1 and exited 0. Sites in four files: `test-store.R:69`, `test-thread.R:67`, `test-flag-args.R:353`, `test-chat-schema.R:941`. Sites in `test-arg-guards.R`: `:692-693`, `:1036-1046`, `:1651-1702`, `:1857`, `:2158-2161`, `:2196`, `:3042`. The work-log line that says `R CMD check` still catches it is wrong. Review reproduced it in a 3-line file under testthat 3.3.2. A failure before a nested subtest did not stop `test_dir(stop_on_failure = TRUE)`. The same failure after the subtests stopped it.
- O2: the wraps at `test-chat-schema.R:950`, `test-store.R:74`, `test-thread.R:72`, and `test-flag-args.R:355` wrap bodies that cannot raise, and they bring in O1 there.
- O3: the two `cases` loops at `test-arg-guards.R:680` and `:698` both name subtests by `case$label`, so 9 full test names appear twice.
- O4: "a request of <label>" at `test-arg-guards.R:1048` does not say which of the 2 `lms_chat_batch` requests, so 6 full names appear twice.
- O5: a `require_httpuv()` skip now ends one subtest, not the parent. No check after a loop breaks.
- O6: a nested `test_that()` resets width, crayon, cli, and locale options. No parent in the diff sets them.
- O7: `loop-sweep.R` does not flag a parent expectation before a nested loop (O1), and misses checks in helpers not named `expect_*`.
- O8: `test-arg-guards.R` ran in 28 s against 22 s on main, with 1899 reported tests against 117.
- B1: same fact as O1, seen against a LESSONS line (M019). That line says a plant check sums the `failed` and `error` columns of `as.data.frame()`.
- B2: same as O3 and O4, plus the pair of loops in the `empty_rows()` test near `test-arg-guards.R:2500`.
- B3: the `n_cases <<-` counters at `test-arg-guards.R:1886`, `:2152`, `:2172` are correct but fragile to a later edit.
- B4: mocks and recorders made inside a loop body now clean up per pass. No test depended on the old stacking.
- P1: T6 logged a third recurrence of the `rawToChar(out$body)` error (`test-arg-guards.R:1986`), which the `list_instances()` candidate row says to promote on. The row is not updated.
- P2: same as B1, for LESSONS line 44.
- P3: the hand-wrapped lines in `test-arg-guards.R` were not run through Air (M056 O1). Not verified.
- P4: 8 added lines over 80 columns in other files. They are also long on main.

Gate (2026-09-30): the maintainer declined the merge and sent M065 back to implement.

- O1: fix now, as T7. It returns M065 to in-progress.
- O2: fix now, in T7.
- O3, O4, B2: fix now, as T9.
- O7: fix now, as T8.
- B1, P2: fix at the hygiene pass. The LESSONS line (M019) then says that a parent's results before its nested subtests are missing from `as.data.frame()`.
- P1: fix at the hygiene pass. The `list_instances()` candidate row then records the 2026-09-30 recurrence at `test-arg-guards.R:1986`.
- O5, O6, O8, B3, B4: noted. Each reviewer found no broken check.
- P3: noted. No rule was shown broken.
- P4: rejected. The lines are also long on main.
