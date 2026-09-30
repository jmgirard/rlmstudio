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

- [ ] AC1: On the branch, `Rscript cairn/tools/loop-sweep.R` prints no
      `flat` row for `test-arg-guards.R`. It also prints no `flat` row whose
      loop header starts with `for (name in `. Each (file, block, header)
      triple that the sweep prints at the plan commit prints on the branch
      at least as many times.
- [ ] AC2: At the plan commit, the sweep prints 8 rows for
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
- [ ] AC3: In a scratch copy of the branch, the `match` field of the
      `no values` probe in `id_probes` of `tests/testthat/test-arg-guards.R`
      is `"planted"`. Run `testthat::test_file()` on that file. Take each
      function that `guarded_exports(c("model", "job_id"))` returns, and
      its block "a bad model or job id aborts <name>(), named, before any
      request". A subtest of that block whose own description ends with
      `no values` errors or fails. Each subtest of that block whose own
      description ends with another `label` of `id_probes` passes. The own
      description is the text after the last ` / ` of the reported test name.
- [ ] AC4: `DESCRIPTION` lists `testthat (>= 3.3.0)` in Suggests.
- [ ] AC5: `devtools::test()` reports no failure and no error.
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
- [ ] T6: Run the sweep, `devtools::test()`, and `devtools::check()`. If
      `check()` gives a note, run it on a42a1ab to compare.

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

## Decisions

## Review
