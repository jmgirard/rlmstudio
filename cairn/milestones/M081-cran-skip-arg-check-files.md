<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M081: The CRAN check skips the three argument-check test files

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — CRAN's check machines run the test suite   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m081-cran-skip-arg-check-files   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

The Windows R-devel check of the package takes less than 10 minutes, because CRAN skips the three argument-check test files.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** A top-level `testthat::skip_on_cran()` in `tests/testthat/test-name-faults.R`, `test-arg-guards.R`, and `test-flag-args.R`, with a comment that gives the reason. In a CRAN-mode run on 2026-10-01 (macOS, `NOT_CRAN=false`, `ListReporter`), these files took 49.2 s of 105.2 s and held 10,235 of 24,435 expectations. If `NOT_CRAN` is unset, `r-lib/actions/setup-r@v2` sets it to `true`, so every GitHub CI job still runs them. `devtools::check()` sets it too.

**Out:** The resubmission of 0.3.0 to CRAN goes to `/cairn-release`, which you start after the merge. The other slow tests go to a new candidate row: the reply-shape loops of `test-chat*.R` and `test-model-list-shape.R`, and the timed waits of `test-mock-http-helper.R` and `test-api-error.R`. A CRAN run of one probe per loop is the rejected alternative (work log). No NEWS entry, because only the tests change.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets.
     Every item opens with its positional label — `ACn:` — the item's
     position counted top-to-bottom, the number Coverage cites; an
     insertion, removal, or reorder renumbers the labels and the Coverage
     lines together.
     Driving RR set → its Binding criteria appear VERBATIM here (binding-
     criteria check), each ingested as a numbered criterion carrying its tag
     — `- [ ] ACn (BCm): <verbatim>` — with its own Coverage line, since
     coverage-complete counts AC checkboxes positionally (M107); departures:
     a "Deviations from RR<NN>" table ends this section. -->

- [x] AC1: With `NOT_CRAN=false`, `devtools::test(reporter = "check")` lists a skip with the reason "On CRAN" in each of `test-name-faults.R`, `test-arg-guards.R`, and `test-flag-args.R`. A `testthat::ListReporter` run in the same mode records no result from those three files.
- [x] AC2: With `NOT_CRAN=true`, a `ListReporter` run records the same set of test names for each of those three files as a baseline run. The baseline is a run of `main` at the plan commit in that mode.
- [x] AC3: With `NOT_CRAN=false`, take every `tests/testthat/test-*.R` file other than those three, as `list.files()` lists it. Each one appears in a `ListReporter` run with the same set of test names as a baseline run. The baseline is a run of `main` at the plan commit in that mode.
- [x] AC4: With `NOT_CRAN=false`, the summed `real` time of a `ListReporter` run of the branch is at most 65% of the same sum for `main`. The `main` run is made in the same session on the same machine.
- [x] AC5: The user starts a win-builder R-devel check of the branch with `devtools::check_win_devel()`. Its result email reports a check time under 600 s and Status: OK.
- [x] AC6: `devtools::check()` on the branch reports 0 errors, 0 warnings, and 0 notes, both with its default settings and with `env_vars = c(NOT_CRAN = "false")`.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T2, T3
- AC2 → T1, T4
- AC3 → T1, T3, T4
- AC4 → T4
- AC5 → T6
- AC6 → T5

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Before any edit, run `devtools::test()` with `ListReporter` on `main` at the plan commit, once with `NOT_CRAN=false` and once with `NOT_CRAN=true`. Save the per-file sets of test names and the summed `real` time in the scratchpad. Write a small comparison script there that reads two saved runs and names each file whose set of test names differs or that is missing. Log the per-mode sums in one work-log line.
- [x] T2: Add `testthat::skip_on_cran()` at the top level of the three files, above their first code. Its comment says that the call keeps the Windows R-devel check of CRAN under its time limit. It also says that CI and `devtools::check()` set `NOT_CRAN=true`, so they still run the file. Format with Air.
- [x] T3: Show that the checks can fail. In a scratch edit, put `skip_on_cran()` at the top of one other test file. Make sure that the T1 comparison names that file for AC3. Revert the edit. Make sure that the `check` reporter lists the three "On CRAN" skips of AC1.
- [x] T4: Run the branch in both modes, and compare the test names with the T1 baseline (AC2, AC3). For AC4, make a scratch `git worktree` of `main`. Run it and the branch back to back with `NOT_CRAN=false`, and compare the summed `real` times.
- [x] T5: Run `devtools::check()` with its default settings and with `env_vars = c(NOT_CRAN = "false")` (AC6).
- [x] T6: Ask the user to run `devtools::check_win_devel()` from the branch. Win-builder sends the result to the maintainer address in DESCRIPTION. Record the emailed check time and status in the work log (AC5).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates.
     EXEMPT from the 150-line cap (D-046): history under D-045, never edited,
     so the cap must never demand a trim here. Wrapped entries get a WARN.
     The rejected-alternative record (/milestone-plan step 4) takes this form:
     `- YYYY-MM-DD: plan gate chose <approach> over <alternative> because
     <reason>; falsified by <evidence class>.` — one per approach choice the
     gate actually weighed, none where it weighed none, and it is the record
     `/milestone-review`'s thrash trigger (b) reads. It lives here rather than
     below so an instantiated file inherits no placeholder to delete. -->

- 2026-10-01: created by /milestone-plan.
- 2026-10-01: criteria audit (full mode, fresh Opus reader) returned 5 findings, all fixed before the gate. AC1 reads the skip from the `check` reporter, because `ListReporter` records nothing for a top-level skip. AC2 lost an "On CRAN" clause that cannot fail. AC3 takes its files from `list.files()`. AC5 reads the time in the win-builder email, because the overall-checktime NOTE comes only from CRAN incoming checks. AC6 adds a `NOT_CRAN=false` check.
- 2026-10-01: plan gate chose a whole-file `skip_on_cran()` in three files over one probe per loop on CRAN. The skip is three lines, and the other choice needs about 100 loop edits and a helper. Falsified by an argument-guard fault that only a CRAN check platform shows.
- 2026-10-01: question gate skipped, because the plan left no choice open. T1 baseline at 5b4a145: `NOT_CRAN=false` 50 files, 2983 tests, 0 failed, summed real 140.8 s. `NOT_CRAN=true` 50 files, 2983 tests, 0 failed, 151.4 s. Both modes hold the same per-file test names, and all 50 `list.files()` test files appear.
- 2026-10-01: T2 adds the skip and its comment to the three files. Deviation: `air format` on the whole files also rewrote about 170 lines outside the change, and `air format --check` lists most test files as not formatted. So the commit keeps only the five added lines, and Air passes them alone. `devtools::check()` sets `NOT_CRAN=true` (its `env_vars` default, devtools 2.5.2), and `r-lib/actions/setup-r@v2` sets it when unset (`installer.ts` line 829 at tag v2).
- 2026-10-01: T3 planted `skip_on_cran()` at the top of `test-ttl.R`. In a `NOT_CRAN=false` run, the comparison over 47 files named `test-ttl.R` alone (baseline 10 names, run missing), and the edit is reverted. The `check` reporter in that mode lists "On CRAN" skips at line 4:1 of each of the three files, with 0 failures.
- 2026-10-02: T4 runs at ab11d3c. With `NOT_CRAN=true`, the three files hold the same test names as the baseline. With `NOT_CRAN=false`, the other 47 files hold the same names as the baseline, and the `ListReporter` run records no result from the three files. Back to back with `NOT_CRAN=false`, a worktree of 5b4a145 summed 107.8 s of real time and the branch 59.6 s, a ratio of 0.553. All runs had 0 failures and 0 errors.
- 2026-10-02: T5 `devtools::check()` at 409b221 gave 0 errors, 0 warnings, and 0 notes with its default settings, and the same with `env_vars = c(NOT_CRAN = "false")`.
- claim audit: 5 claims read, 0 corrected — tests/testthat/test-arg-guards.R, test-flag-args.R, test-name-faults.R
- 2026-10-02: blocked on T6. The user starts `devtools::check_win_devel()` from the branch and reads the emailed check time and status. Resume with `/milestone-implement M081`.
- 2026-10-02: T6 win-builder R-devel check (R Under development 2026-09-30 r90605 ucrt) of the branch: check time 463 s, install 8 s, Status: OK, tests 348 s (https://win-builder.r-project.org/o5ArKbmBJwc4). The CRAN incoming check of `main` (9c2a2df) on the same day took 13 min overall and 11 min for tests. No code changed after the T5 check at 409b221, so that check stands as the verify result. Status set to review.
- step-7 approval: m081-cran-skip-arg-check-files approved for merge, with the fixes for findings F3 and F4 and candidate rows for F1 and F2.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md.
     EXEMPT from the 150-line cap (D-074) because D-045 makes it history like the work log — dated dispositions, never edited — so the cap must never demand a trim here either.
     Entries carry their rationale; the counterweight `decisions format`
     advisory watches for pasted output, not for entry length (D-075). -->

## Review
<!-- owner: review · exclusive -->

Fresh runs on 2026-10-02 at acbd9be, with a scratch worktree of `main` at the plan commit 5b4a145 as the baseline. All `ListReporter` runs had 0 failures and 0 errors.

- AC1: `NOT_CRAN=false devtools::test(reporter = "check")` lists 7 "On CRAN" skips and 0 failures. Three of the skips are `test-arg-guards.R:4:1`, `test-flag-args.R:4:1`, and `test-name-faults.R:4:1`. The `NOT_CRAN=false` `ListReporter` run of the branch records 47 files and none of the three.
- AC2: With `NOT_CRAN=true`, the baseline and the branch each ran 50 files and 2983 tests. The comparison script finds no difference in test names for the three files.
- AC3: With `NOT_CRAN=false`, the comparison over the 47 other `list.files()` test files finds no difference in test names between the baseline and the branch.
- AC4: Back to back with `NOT_CRAN=false`, the summed `real` time was 97.5 s for `main` and 51.7 s for the branch. The ratio is 0.530, and the limit is 0.65.
- AC5: The win-builder email the user received on 2026-10-02 for the branch reports "Check time in seconds: 463" and "Status: OK" (R-devel 2026-09-30 r90605 ucrt). Its `00check.log` shows tests at 348 s, against 11 min in the CRAN check of `main` (9c2a2df).
- AC6: `devtools::check()` gave 0 errors, 0 warnings, and 0 notes with its default settings. It gave the same with `env_vars = c(NOT_CRAN = "false")`, and its header listed `NOT_CRAN : false`.

Consistency gate: `cairn_validate` passes. `devtools::document()` leaves no diff. `pkgdown::check_pkgdown()` finds no problems. The branch touches no README, NEWS, R, or top-level file.

Reviewers: Opus diff-bug, Sonnet blame-history, and Sonnet prior-review, each fresh. Merged and ranked findings, with the disposition proposed at the gate:

- F1: CRAN and its reverse-dependency checks no longer run about 10,000 expectations. The skip also drops request-body tests. One is "messages reach the request as jsonlite writes them" (`test-arg-guards.R:3602`), which guards against an httr2 1.3.0 change. Proposed: follow-up candidate row to move such request-body tests to a file that CRAN runs.
- F2: The encoding probes of `test-name-faults.R` now run on no Windows R-devel machine. CI runs Windows on R release only, and the weekly R-devel job runs on Ubuntu. Proposed: follow-up candidate row to add Windows to the weekly R-devel job.
- F3: `cairn/DESIGN.md` line 54 does not say that three test files skip on CRAN. Proposed: fix now with one sentence there.
- F4: The comment says that CI and `devtools::check()` set `NOT_CRAN=true`. In the source-tree CI job, `devtools::test()` sets it. Any run without `NOT_CRAN=true` skips, not only CRAN. Proposed: fix now in the three comments.
- F5: If a CI job loses `NOT_CRAN=true`, the three files skip with no failure. A direct read showed this: if `NOT_CRAN` is unset, `r-lib/actions/setup-r@v2` and devtools 2.5.2 `r_env_vars()` set it to `true`. So every current job runs the files. Proposed: reject, because no current job is affected and the check reporter lists each skip.
- F6: `tests/testthat/test-load.R:23` says that `test-flag-args.R` covers the other flag values, which is not true on CRAN. Proposed: reject, because the comment names where the coverage lives, which is still true.
- F7: The same comment and skip appear three times, and a helper in `helper-skips.R` can hold them. Proposed: reject, because three lines inline keep the reason in the file the reader opens.
- F8: `CRAN-SUBMISSION` is untracked in the working tree. Proposed: reject, because the diff does not touch it and `/cairn-release` handles it.
- F9: The call-site guard in `test-name-faults.R` already skips under R CMD check, so the coverage loss is smaller than the count suggests. `skip_on_cran()` already appears in three other test files. No test in the three files guards a CRAN-only bug. Proposed: noted, no action.

At the gate on 2026-10-02, the user accepted every proposed disposition. F3 and F4 are fixed on the branch. F1 and F2 are candidate rows in `cairn/ROADMAP.md`. After the fix, the three files pass with `NOT_CRAN=true`. With `NOT_CRAN=false`, the check reporter lists their three "On CRAN" skips at line 4.
