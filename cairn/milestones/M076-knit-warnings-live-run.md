# M076: The vignette knit fails on an unmarked warning and stale output, and a release has live-run steps

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — dev scripts under `data-raw/`, a local-only test, and a tracking pointer. The re-knitted vignettes change only in live output.
- **Branch/PR:** —

## Goal

Before a release, a written live run checks the tests, cassettes, and vignettes
against LM Studio. The vignette knit refuses a warning that no chunk expects
and output older than its source.

## Scope

**In:** `data-raw/knit-vignettes.R` fails the knit of a source on a chunk
warning. A chunk that sets the new option `expect_warning = TRUE` is exempt.
The knit writes the MD5 sum of each source into its knitted `.Rmd`. The 4
warning chunks of `vignettes/text-analysis.Rmd.orig` get the option. A test
fails for each source whose sum differs from its `.Rmd`. A full live re-knit
stamps every vignette. A new `data-raw/README.md` gives the release live-run
steps. The release-walk slot of `cairn/PROFILE.md` points to it. DESIGN
Conventions lines 54 and 58 follow the change.

**Out:** A script that runs the live steps by itself is not in scope. No
candidate row holds it. If the written steps prove error-prone, plan it then.
The cassette directories that the tests record themselves get no recorder
script. The README names the remove-and-rerun route for them. The
headless-host probe of the knit script stays in DESIGN Known issues. The
other candidate rows stay as they are.

## Acceptance criteria

- [ ] AC1: The scratch source is a `.Rmd.orig` file outside `vignettes/`.
      One of its chunks has default `warning` handling and raises a warning
      without `expect_warning = TRUE`. A `data-raw/knit-vignettes.R` run on
      it exits with status 1 and names the source and the chunk label in its
      message. The target `.Rmd` stays byte-identical to its state before the
      run. If it was absent before the run, it stays absent.
- [ ] AC2: The AC1 scratch source gets `expect_warning = TRUE` on that
      chunk. A `data-raw/knit-vignettes.R` run on it exits with status 0.
      The target `.Rmd` holds the warning on a `#> Warning` line.
- [ ] AC3: LM Studio is installed, the server is stopped, and no model is
      loaded. `Rscript data-raw/knit-vignettes.R` with no argument then exits
      with status 0. After it, `vignettes/text-analysis.Rmd` holds a
      `#> Warning` line in the output of each chunk that its source marks
      `expect_warning = TRUE`.
- [ ] AC4: Each `vignettes/<name>.Rmd` that the knit writes holds the MD5
      sum of its `vignettes/<name>.Rmd.orig` source. A test that
      `devtools::test()` runs lists the sources from the package root, with
      `testthat::test_path("../../vignettes")`. It reports one failure for
      each source whose sum differs from the sum in its `.Rmd`. It also
      reports one failure for each source whose `.Rmd` is missing or holds
      no sum. Each failure names its source. If the test finds no source, it
      skips.
- [ ] AC5: `data-raw/README.md` gives the live-run steps of a release in
      this order. Start the server with the models that the live tests need.
      Run `devtools::test()` and make sure that no test skipped for want of
      the server or a model. Re-record the cassettes. Re-knit the vignettes.
      `list.dirs(recursive = FALSE)` lists the top-level directories under
      `tests/testthat/`. The README names each of them, except `fixtures`
      and `_problems`. Next to each, it names the `data-raw/record-*.R`
      script, or the removal of the directory and a live run of its test. A
      model counts as needed when a string names it in a recorder script, or
      in a `test_that()` block that calls `skip_if_no_server()`. The README
      names each such model. The release-walk slot of `cairn/PROFILE.md`
      points to the README.
- [ ] AC6: `devtools::test()` and `devtools::check()` finish with 0 errors
      and 0 warnings. The Review section of this file lists each NOTE with
      its reason.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2, T4
- AC4 → T3, T4
- AC5 → T5
- AC6 → T6

## Tasks

- [ ] T1: In `data-raw/knit-vignettes.R`, `knit_source()` near line 96, set
      a knitr `warning` output hook. If `options$expect_warning` is not TRUE,
      the hook records the warning and the chunk label. After the knit,
      fail that source as a chunk error does, so the `.Rmd` is not copied.
      Update the header comment. The script refuses a running server or a
      loaded model (LESSONS M009 and M070).
- [ ] T2: Mark the 4 warning chunks of `vignettes/text-analysis.Rmd.orig`
      with `expect_warning = TRUE`. Their `.Rmd` output holds `#> Warning` at
      lines 130, 208, 263, and 354. Run AC1 and AC2 on a scratch source in a
      temp directory. Log the exit codes and the message.
- [ ] T3: Make the knit write the source MD5 sum as an HTML comment line in
      the `.Rmd`. Add the stale-knit test in a new `test-vignette-knit.R` or
      in `test-vignette-claims.R`. The sources do not ship to
      `R CMD check`, so the test skips on an empty source list (LESSONS
      M005). Plant a one-character source edit and see one failure that
      names that source. Then restore the source.
- [ ] T4: Run the full live knit. It rewrites every vignette. Read each
      `.Rmd` diff and log any output change other than the stamp.
- [ ] T5: Write `data-raw/README.md` from a same-session read of the tests
      and the recorder scripts (the derived-claims rule). It covers the
      models, the directories with their recorder or remove-and-rerun route,
      and the re-knit. Add the pointer line to the release-walk slot of
      `cairn/PROFILE.md`, which has 108 of its 120 lines. Update DESIGN
      Conventions lines 54 and 58. `.Rbuildignore` already ignores
      `data-raw`.
- [ ] T6: Run `devtools::document()`, `devtools::test()`, and
      `devtools::check()`. Record each NOTE. Nothing that users run changes,
      so NEWS gets no entry.

## Work log

- 2026-10-01: created by /milestone-plan. It absorbs the candidate row "The release walk needs a live-run step" (added 2026-09-17, extended at M070 review F14 and F6). It extends M070.
- 2026-10-01: criteria audit, reduced mode, fresh Opus reader. Findings on AC1, AC3, AC4, AC5, and AC6: fixture place, `warning = FALSE` chunks, clean-start state, test root and skip, cassette directories that a call-site grep misses, a model list from memory, and the NOTE record. All fixed before the gate.
- 2026-10-01: plan gate chose to fail the knit on an unmarked warning over a list of warnings at the end with exit 0. A listed warning can still ship unnoticed. Falsified by a vignette that needs a warning in a chunk that cannot carry the option.
- 2026-10-01: plan gate chose `data-raw/README.md` with a PROFILE pointer over steps in `cairn/PROFILE.md`, which is near its 120-line cap, and over a `data-raw/live-run.R` script. Falsified by a release whose live run skips a step that a script enforces.
- 2026-10-01: plan gate kept one milestone over a split into knit work and live-run work, because the live run re-knits the vignettes. Falsified by an implement phase that needs more than three sittings for both parts.

## Decisions

## Review
