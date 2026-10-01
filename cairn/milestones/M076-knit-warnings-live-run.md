# M076: The vignette knit fails on an unmarked warning and stale output, and a release has live-run steps

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — dev scripts under `data-raw/`, a local-only test, and a tracking pointer. The re-knitted vignettes change only in live output.
- **Branch/PR:** m076-knit-warnings-live-run

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

- [x] AC1: The scratch source is a `.Rmd.orig` file outside `vignettes/`.
      One of its chunks has default `warning` handling and raises a warning
      without `expect_warning = TRUE`. A `data-raw/knit-vignettes.R` run on
      it exits with status 1 and names the source and the chunk label in its
      message. The target `.Rmd` stays byte-identical to its state before the
      run. If it was absent before the run, it stays absent.
- [x] AC2: The AC1 scratch source gets `expect_warning = TRUE` on that
      chunk. A `data-raw/knit-vignettes.R` run on it exits with status 0.
      The target `.Rmd` holds the warning on a `#> Warning` line.
- [x] AC3: LM Studio is installed, the server is stopped, and no model is
      loaded. `Rscript data-raw/knit-vignettes.R` with no argument then exits
      with status 0. After it, `vignettes/text-analysis.Rmd` holds a
      `#> Warning` line in the output of each chunk that its source marks
      `expect_warning = TRUE`.
- [x] AC4: Each `vignettes/<name>.Rmd` that the knit writes holds the MD5
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
      `git ls-tree -d --name-only HEAD:tests/testthat` lists the top-level
      directories under `tests/testthat/` that git tracks. The README names
      each of them. Next to each, it names the `data-raw/record-*.R` script,
      or the removal of the directory and a live run of its test, or that the
      directory holds no recorded responses.
      `grep -E '^#   Models?:' data-raw/record-*.R` lists the provenance
      header lines of the recorder scripts. The README names each model key
      on those lines. The release-walk slot of `cairn/PROFILE.md` points to
      the README.
- [ ] AC6: `devtools::test()` and `devtools::check()` finish with 0 errors
      and 0 warnings. The Review section of this file lists each NOTE with
      its reason.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2, T4
- AC4 → T3, T4
- AC5 → T5, T7
- AC6 → T6

## Tasks

- [x] T1: In `data-raw/knit-vignettes.R`, `knit_source()` near line 96, set
      a knitr `warning` output hook. If `options$expect_warning` is not TRUE,
      the hook records the warning and the chunk label. After the knit,
      fail that source as a chunk error does, so the `.Rmd` is not copied.
      Update the header comment. The script refuses a running server or a
      loaded model (LESSONS M009 and M070).
- [x] T2: Mark the 4 warning chunks of `vignettes/text-analysis.Rmd.orig`
      with `expect_warning = TRUE`. Their `.Rmd` output holds `#> Warning` at
      lines 130, 208, 263, and 354. Run AC1 and AC2 on a scratch source in a
      temp directory. Log the exit codes and the message.
- [x] T3: Make the knit write the source MD5 sum as an HTML comment line in
      the `.Rmd`. Add the stale-knit test in a new `test-vignette-knit.R` or
      in `test-vignette-claims.R`. The sources do not ship to
      `R CMD check`, so the test skips on an empty source list (LESSONS
      M005). Plant a one-character source edit and see one failure that
      names that source. Then restore the source.
- [x] T4: Run the full live knit. It rewrites every vignette. Read each
      `.Rmd` diff and log any output change other than the stamp.
- [x] T5: Write `data-raw/README.md` from a same-session read of the tests
      and the recorder scripts (the derived-claims rule). It covers the
      models, the directories with their recorder or remove-and-rerun route,
      and the re-knit. Add the pointer line to the release-walk slot of
      `cairn/PROFILE.md`, which has 108 of its 120 lines. Update DESIGN
      Conventions lines 54 and 58. `.Rbuildignore` already ignores
      `data-raw`.
- [x] T6: Run `devtools::document()`, `devtools::test()`, and
      `devtools::check()`. Record each NOTE. Nothing that users run changes,
      so NEWS gets no entry.
- [x] T7: Bring `data-raw/README.md` in line with the amended AC5. Add a
      `fixtures` row that says it holds no recorded responses. Say that a
      filtered test run can leave an empty `_snaps`.

## Work log

- 2026-10-01: created by /milestone-plan. It absorbs the candidate row "The release walk needs a live-run step" (added 2026-09-17, extended at M070 review F14 and F6). It extends M070.
- 2026-10-01: criteria audit, reduced mode, fresh Opus reader. Findings on AC1, AC3, AC4, AC5, and AC6: fixture place, `warning = FALSE` chunks, clean-start state, test root and skip, cassette directories that a call-site grep misses, a model list from memory, and the NOTE record. All fixed before the gate.
- 2026-10-01: plan gate chose to fail the knit on an unmarked warning over a list of warnings at the end with exit 0. A listed warning can still ship unnoticed. Falsified by a vignette that needs a warning in a chunk that cannot carry the option.
- 2026-10-01: plan gate chose `data-raw/README.md` with a PROFILE pointer over steps in `cairn/PROFILE.md`, which is near its 120-line cap, and over a `data-raw/live-run.R` script. Falsified by a release whose live run skips a step that a script enforces.
- 2026-10-01: plan gate kept one milestone over a split into knit work and live-run work, because the live run re-knits the vignettes. Falsified by an implement phase that needs more than three sittings for both parts.
- 2026-10-01: implement started on branch m076-knit-warnings-live-run. No question gate: nothing was open. The stamp is an HTML comment line at the end of the `.Rmd`, and the test goes in a new `test-vignette-knit.R`.
- 2026-10-01: T1 done. `knit_source()` calls `knitr::render_markdown()` before it wraps the warning hook, because `knit()` sets the markdown hooks only while all hooks are at their defaults. A scratch run with `warning = FALSE` showed no warning on the console, so the header comment says the option hides it.
- 2026-10-01: T2 done. Marked chunks `summaries`, `schema`, `logprobs`, and `failed`. Scratch source in the session scratch directory with the vignette setup chunk: an unmarked `warning()` chunk exits 1 with "The chunk 'noisy' of <path> gave a warning, and the chunk does not set expect_warning = TRUE.", the target absent stays absent and a present target keeps its MD5. With `expect_warning = TRUE` it exits 0 and the `.Rmd` holds `#> Warning: planted warning`.
- 2026-10-01: T3 done. The stamp line is `<!-- Knitted from <name>.Rmd.orig with MD5 <sum>. -->`. Before the re-knit, the new test gave 4 failures, one per source. After it, the test passes 4. A planted space in `headless-config.Rmd.orig` gave 1 failure that names it. A moved `headless-config.Rmd` gave 1 failure that names it. Both were restored. Full `devtools::test()`: 0 failures, 3 skips, 19942 passes.
- 2026-10-01: T4 done. With the server stopped and no model loaded, the full knit exited 0. `text-analysis.Rmd` keeps `#> Warning` in all 4 marked chunks. Besides the stamps and new response ids and timings, two outputs changed. In `chat-options.Rmd`, the default and OpenAI routes, with no temperature, now answer "Blue" plus a follow-up sentence. In `getting-started.Rmd`, the hello reply and the batch answers changed wording. No prose states the old text.
- 2026-10-01: T5 done. `data-raw/README.md` maps 6 directories to recorder scripts and 3 to remove-and-rerun with an anchored `devtools::test()` filter. It names 3 models: `google/gemma-3-1b`, `qwen/qwen3-4b-2507`, and `text-embedding-nomic-embed-text-v1.5`. A run of `filter = "^list$"` ran `test-list.R` alone, with 6 passes. PROFILE has 109 lines. `cairn_validate` passes.
- 2026-10-01: T6 done. `devtools::document()` gave no diff. `devtools::test()`: 0 failures, 3 skips, 19942 passes. `devtools::check()`: 0 errors, 0 warnings, 0 notes. In a scratch tree with no vignette source, the stale-knit test skips with "No vignette sources to compare."
- 2026-10-01: claim audit: not owed — internal tier
- 2026-10-01: all tasks done, status set to review.
- 2026-10-01: review: AC1 to AC4 verified and ticked. AC5 fails as written on an empty, untracked `tests/testthat/_snaps` that each filtered `devtools::test()` run makes. The exclusion list "`fixtures` and `_problems`" is a hand list. So the repair narrows the promise to a procedure and does not add `_snaps` to the list (widening test). Status back to in-progress for this amendment alone.
- 2026-10-01: amendment return: AC5 — "`git ls-tree -d --name-only HEAD tests/testthat/` lists the top-level directories under `tests/testthat/` that git tracks. The README names each of them, except `fixtures`."
- 2026-10-01: implement resumed for the AC5 amendment alone.
- 2026-10-01: re-audit: AC5 (reduced) — fresh Opus reader. (1) The model rule "a string names it" decides no membership for a decoy such as `"Google/Gemma-3-1B"`, and it names no search for the test blocks. (2) `git ls-tree -d --name-only HEAD tests/testthat/` prints full paths, and `HEAD:tests/testthat` prints bare names. (3) The `fixtures` exception is a carve-out from memory. (4) Low: the README skip list lacks "LM Studio CLI is not installed.". (5) Low: the `list_models` block fakes the server check, so the model rule leaves it out. Instrument question: nothing.
- 2026-10-01: AC5 mini gate: the user chose "Narrow both" (recommended) over narrowing the directory clause alone and over a pause. Directories come from `git ls-tree -d --name-only HEAD:tests/testthat`, models from `grep -E '^#   Models?:' data-raw/record-*.R`, and the `fixtures` exception is gone.
- 2026-10-01: re-audit: AC5 (reduced) — second fresh Opus reader on the gated wording. (1) Low-medium: the step text "the models that the live tests need" names no procedure, if it binds the README to name them. (2) Low: "holds no recorded responses" is loose for `fixtures`, which holds docs examples. (3) Low: "model key" is decided in practice, and continuation lines fall outside the grep. Proportionality and instrument: nothing beyond (1). This is the second AC5 re-audit, so further churn on AC5 goes to the user.
- 2026-10-01: AC5 amended to the gated wording, executing the review's amendment return. The final clause replaces the review's proposed `HEAD tests/testthat/` form with `HEAD:tests/testthat` and drops the `fixtures` exception. T7 added for the README change, and Coverage now reads AC5 → T5, T7.
- 2026-10-01: T7 done. The README has a `fixtures` row and a note on the empty `_snaps`. The two test files that read `fixtures` say its files are copies of LM Studio docs examples. T7 dropped the `skip_if_no_lms()` reason: both calls follow a mock of `has_lms()` to TRUE, so that skip cannot fire. All 10 `ls-tree` directories have one README row, and the README names the 3 model keys of the header lines. `devtools::test()`: 0 failures, 3 skips, 19942 passes.
- 2026-10-01: claim audit: not owed — internal tier
- 2026-10-01: amendment done, status set to review.

## Decisions

## Review

- AC1 evidence (2026-10-01): a fresh scratch source `probe.Rmd.orig` sat in the session scratch directory, outside `vignettes/`. Its chunk `loud-chunk` calls `warning()` with default handling. With no target, the run exited 1 and printed "The chunk 'loud-chunk' of <path>/probe.Rmd.orig gave a warning, and the chunk does not set expect_warning = TRUE." No `probe.Rmd` appeared. With a present target, the run exited 1 again, and the target MD5 stayed `97ed8315d42223266f7e00741409a6ad`.
- AC2 evidence (2026-10-01): the same source with `expect_warning = TRUE` on `loud-chunk` exited 0. Line 10 of `probe.Rmd` reads `#> Warning: review probe warning`.
- AC3 evidence (2026-10-01): `lms server status --json` gave `"running":false`, and `lms ps --json` gave `[]`. Then `Rscript data-raw/knit-vignettes.R` with no argument knitted all 4 sources and exited 0. `text-analysis.Rmd` holds `#> Warning` at lines 130, 208, 263, and 354. In order, these are the outputs of the chunks `summaries`, `schema`, `logprobs`, and `failed`. The source marks these 4 chunks, and no other, `expect_warning = TRUE`. The run changed only live replies, response ids, and timings. The review restored the committed output.
- AC4 evidence (2026-10-01): the last line of each of the 4 committed `.Rmd` files holds the `md5` of its `.Rmd.orig`. All 4 pairs match. `tests/testthat/test-vignette-knit.R` lists the sources with `testthat::test_path("../../vignettes")`. On the branch, `devtools::test(filter = "vignette-knit")` gave 4 passes and 0 failures. Three plants each gave 1 failure and 3 passes, and each was restored. A byte added to `chat-options.Rmd.orig` gave "chat-options.Rmd.orig changed after its knit." The stamp line cut from `getting-started.Rmd` gave "The .Rmd of getting-started.Rmd.orig holds no source MD5 sum." A moved `text-analysis.Rmd` gave "text-analysis.Rmd.orig has no knitted .Rmd." In a scratch tree with an empty `vignettes/`, the test skipped with "No vignette sources to compare."
- AC5 evidence (2026-10-01), not met as written: `list.dirs("tests/testthat", recursive = FALSE)` listed 12 directories, one of them an empty `_snaps`. The README table names the other 9, except `fixtures` and `_problems`, each with its recorder script or its remove-and-rerun command. It does not name `_snaps`. Git does not track `_snaps`, and `git ls-tree -d HEAD tests/testthat/` lists 10 directories without it. After `rmdir`, a filtered run such as `devtools::test(filter = "^list$")` made the empty `_snaps` again. The README uses such filtered runs in step 3. The other AC5 parts held. The model strings of the recorder scripts are `google/gemma-3-1b`, `text-embedding-nomic-embed-text-v1.5`, `qwen/qwen3-4b-2507`, and the case variant `Google/Gemma-3-1B`. The `skip_if_no_server()` blocks name `google/gemma-3-1b` and `text-embedding-nomic-embed-text-v1.5`, and the README names all 3 models. Its 4 step headings follow the AC5 order, and PROFILE line 73 points to it. AC6 was not run, and no reviewer was spawned. Review stopped at the return.
