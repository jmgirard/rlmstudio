# M069: lms_score_expected() reads the first step of a reply alone

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP6
- **Resolves:** —
- **Surface tier:** user-facing — it changes an exported scoring result and the shape of an exported return value
- **Branch/PR:** m069-score-first-step

## Goal

`lms_score_expected()` scores the first step of a reply alone, so a later
step that repeats the first token no longer adds its candidates.

## Scope

**In:** An integer `step` column, placed last, in the logprobs data frame
that `logprobs_frame()` in `R/chat.R` builds. `lms_score_expected()` in
`R/score.R` reads the rows of the first step by `step`. A frame with no
`step` column falls back to the first run of rows that share the first
token. Candidates that give the same label are summed into one row. The
print method of `lms_chat_result` counts steps by `step`. The help pages,
the text-analysis vignette, the claim tests, and NEWS follow. The pre-1.0
waiver covers the new column, with a NEWS entry.

**Out:** A `step` argument that scores a step other than the first stays
unplanned, because no user asked for it. A reply can start with a token
that is not the rating, such as a newline. It still aborts with "No tokens
in the top candidates", as it does now. Logprobs from `/v1/chat/completions` stay
in the DESIGN known issue.

## Acceptance criteria

- [x] AC1: With `logprobs = TRUE`, the logprobs data frame of
      `lms_chat_openresponses()` has a fifth and last column `step`. This
      also holds for `lms_chat()` on its default route and for each
      OpenResponses cell of `lms_chat_batch()` that holds a logprobs data
      frame. `step` is an integer that numbers the steps from 1 in reply
      order across all `output_text` parts. Each row of a step carries the
      number of that step, the one `NA`-candidate row of a step with no
      candidates included. A test in `test-chat.R` asserts the exact
      `step` vector for one mocked reply. That reply has two `output_text`
      parts with logprobs and a part with no logprobs between them. One of
      its steps has no candidates. The checks at `test-chat-batch.R:688` and
      `test-chat-batch-usage.R:373` also assert `step`.
- [x] AC2: Given a frame with a `step` column whose first value is not
      `NA`, `lms_score_expected()` reads only the rows whose `step` equals
      the `step` of the first row. Tests cover three frames. In the first,
      step 1 and step 3 share the step token "3". In the second, steps 1
      and 2 share it. In the third, a row of step 1 comes after a row of
      step 2. In each, the result equals hand-computed values (arithmetic
      in comments). In each, it is identical to the result for the step-1
      rows alone. A frame whose first `step` is `NA` follows AC3, and a
      test shows it.
- [x] AC3: Given a frame with no `step` column, `lms_score_expected()`
      reads the first run of consecutive rows whose `step_token` is
      identical to that of the first row, `NA` included. A test with the
      step tokens "3", "\n", "3" shows that the last "3" rows do not count.
      A test with a first step token of `NA` shows which rows count. This
      test replaces the score test at `test-vignette-claims.R:125`, which
      holds the old rule. The help page states this: without a `step`
      column, two adjacent steps with the same token count as one step.
- [x] AC4: Candidates of the read step can have tokens that give the same
      label, such as "3", " 3", and "3.0". They give one row of
      `probabilities` that holds the sum of their probabilities, in order
      of first appearance. The `entropy` uses those summed rows. The
      expected value and the weighted standard deviation do not change. A
      test asserts hand-computed values for a frame with those three
      spellings and another label between them.
- [x] AC5: For a frame with a `step` column, the print method of
      `lms_chat_result` reports the number of distinct `step` values. For
      a frame with no `step` column, it reports the number of runs of
      consecutive identical `step_token` values. With
      `rlmstudio.quiet = FALSE`, a test of a three-step reply whose steps 1
      and 3 share a token shows 3 steps in each case.
- [x] AC6: `grep -rl 'step_token\|lms_score_expected' R vignettes tests
      README.Rmd NEWS.md` lists files. In each, prose or test code that
      says which rows `lms_score_expected()` reads states the rules of AC2
      and AC3. The help of `lms_chat_openresponses()` describes the `step`
      column. In `vignettes/text-analysis.Rmd`, the pasted logprobs output
      shows the `step` column, and the pasted score output shows one row
      per label. `test-vignette-claims.R` asserts the five column names and
      the `step` values of its mocked reply. `NEWS.md` has an entry for the
      new column, the step rule, and the summed labels.
- [x] AC7: The `verify` slot of `cairn/PROFILE.md` is clean:
      `devtools::document()` gives no diff, and `devtools::test()` passes.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T2
- AC4 → T3
- AC5 → T4
- AC6 → T5
- AC7 → T1, T2, T3, T4, T5

## Tasks

- [x] T1: In `logprobs_frame()` (`R/chat.R:1269`), number the steps from 1
      and add `step` as the last column. Add the `test-chat.R` test of AC1.
      Add `step` checks at `test-chat-batch.R:688` and
      `test-chat-batch-usage.R:373`. Update every `names()` check of the
      logprobs frame that `devtools::test()` then fails.
- [x] T2: In `lms_score_expected()` (`R/score.R:37`), read the first step
      by `step`, with the run fallback of AC3. Add the tests of AC2 and AC3
      to `test-score.R`. Replace the score test at
      `test-vignette-claims.R:125`. Plant the old rule and see each new
      test go red.
- [x] T3: Sum the probabilities of candidates that give the same label.
      Add the test of AC4, with its arithmetic in comments. Plant the
      unsummed rule and see the test go red.
- [x] T4: In `print.lms_chat_result()` (`R/chat_oop.R:78`), count steps as
      AC5 states. Add the test of AC5.
- [x] T5: Run the AC6 grep and fix each site it lists, including the
      copied rule in the live test at `test-chat.R:47`. Update the roxygen
      of `lms_score_expected()`, with `step` in its example, and of
      `lms_chat_openresponses()`. Knit the logprobs and score chunks of
      `text-analysis.Rmd` against a live LM Studio, and paste the observed
      output and prose. Add the NEWS entry. Add a DESIGN Conventions line
      that names where the score oracles live: comments at the asserting
      tests in `test-score.R`. Run `devtools::document()` and
      `devtools::test()`.

## Work log

- 2026-09-30: created by /milestone-plan. Absorbs the M068 review finding F13 candidate row.
- 2026-09-30: criteria audit (full mode, fresh Opus reader) returned 14 findings on AC1 to AC6 and none against a principle or decision. Each had one clear repair, fixed before the gate. AC1 got batch checks and a part with no logprobs. AC2 and AC3 got an `NA` first value and an out-of-order row. AC4 got three spellings. AC5 got a no-step count and quiet off. AC6 got a wider grep and the vignette score output.
- 2026-09-30: plan chose a new `step` column over a score-only run rule, because a run rule cannot split two adjacent same-token steps; falsified by a reply format whose steps the package cannot number.
- 2026-09-30: plan gate chose `step` as the last column over the first, because code that reads the four current columns by position keeps working; falsified by a user who finds the printed order hard to read.
- 2026-09-30: plan gate chose a run fallback for a frame with no `step` over an abort, because frames saved before this change keep scoring; falsified by a saved frame whose adjacent same-token steps the fallback merges into a wrong score.
- 2026-09-30: plan gate put the sum of duplicate labels in this milestone over a separate candidate row, because it fixes the entropy of the same function; falsified by a user who needs each token spelling as its own row.
- 2026-09-30: implement started on branch m069-score-first-step. Question gate skipped: the criteria fix the column, the step rule, the fallback, and the label sum.
- 2026-09-30: T1 done. `logprobs_frame()` adds an integer `step` column last. The new `test-chat.R` test failed on the old code (no `step` column) and passes now. The batch checks, the four-column frame tests, and the vignette-claims names check carry `step`. `devtools::test()` clean.
- 2026-09-30: T2 done. `first_step_rows()` in `R/score.R` reads step 1 by `step`, or the first run of `step_token`. With the old rule planted, the three new `test-score.R` tests and the replaced vignette-claims score test fail. A run-only plant fails the AC2 frames, and a consecutive-step plant fails the out-of-order frame. `devtools::test()` clean.
- 2026-09-30: T3 done. `lms_score_expected()` sums the candidates of one label in order of first appearance. On the unsummed code, the new test failed in the label, probability, and entropy checks and passed in the expected value and SD checks. `devtools::test()` clean.
- 2026-09-30: T4 done. `print.lms_chat_result()` counts distinct `step` values, or runs of `step_token` with no `step` column. The new `test-chat.R` print test showed 2 steps on the old code in both cases and 3 now. `devtools::test()` clean.
- 2026-09-30: T5 done. The AC6 grep listed 10 files. The live test at `test-chat.R:47` now calls `lms_score_expected()` in place of its copy of the old rule. The help of `lms_score_expected()` and `lms_chat_openresponses()`, the vignette, NEWS, and a DESIGN Conventions line on the score oracles follow. The vignette logprobs and score output was re-run against LM Studio with `google/gemma-3-1b`, which gave an expected value of 3.348005 where the old paste had 3.342552. `devtools::document()` gives no diff, and `devtools::test()` is clean.
- 2026-09-30: claim audit: 85 claims read, 3 corrected — tests/testthat/test-score.R, R/score.R, man/lms_score_expected.Rd
- 2026-09-30: The first `devtools::check()` failed at the `headless-config.Rmd` build. LM Studio could not resolve `qwen/qwen3-4b-2507` and reported "Network connection failed". The branch does not touch that vignette. The failed build left the server running, and it was stopped by hand. The rerun gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-30: implement done, status review.
- 2026-09-30: review return 1 (defect): AC3 failed. The score test that replaced `test-vignette-claims.R:125` holds a `step` column, so it exercises the AC2 rule, not the no-`step` fallback the criterion names. Status in-progress. The other criteria passed, and the 13 reviewer findings in the Review section wait for triage.
- 2026-09-30: T2 repair for the AC3 return. The score test at `test-vignette-claims.R:126` now uses a frame with no `step` column and the step tokens "3", "\n", "3", so it exercises the run fallback. With the old rule planted (every row with the first step token), it failed in the label, probability, expected value, SD, and entropy checks. `devtools::document()` gives no diff, and `devtools::test()` gives 0 failures and 3 skips.
- 2026-09-30: claim audit: 62 claims read, 0 corrected — none
- 2026-09-30: implement done after return 1, status review. The 13 reviewer findings of pass 1 still wait for triage at the review gate.

## Decisions

## Review

Sync 2026-09-30: `origin/main` (cc0d45d) is an ancestor of the branch head, so no merge was needed. Fresh runs on 97a1c9d: `devtools::document()` gave no diff. `devtools::test()` gave 0 failures and 3 skips. The skips are live tests that need a running server (`test-embed.R:1117`, `test-embed.R:1139`, `test-list-instances.R:409`). `devtools::check()` with the API token gave 0 errors, 0 warnings, and 0 notes, vignettes rebuilt.

- AC1: `test-chat.R:331` passes. Its mocked reply has a part with two steps (the second with no candidates), a part with no logprobs, and a part with one step. It asserts the five names, with `step` last, and `step` = `c(1L, 1L, 2L, 3L, 3L, 3L)`. `test-vignette-claims.R:114` asserts `step` for `lms_chat()` on its default route. `test-chat-batch.R:689` and `test-chat-batch-usage.R:374` assert `step` = `1L` for batch OpenResponses cells. `logprobs_frame()` sets `step = i` from `seq_along(steps)`, an integer.
- AC2: `test-score.R:137` passes over three frames: steps 1 and 3 share "3", steps 1 and 2 share "3", and a step-1 row follows a step-2 row. Each gives the hand values in the comments at `test-score.R:121` (3.25, 0.4330127, 0.8112781) and is identical to the result for the step-1 rows alone. `test-score.R:196` gives a frame whose first `step` is `NA` and shows that it scores like the same frame with no `step` column.
- AC3: FAIL. `test-score.R:176` passes. Its frame has no `step` column and the step tokens "3", "\n", "3", and the last "3" rows do not count. Its second frame has a first step token of `NA`. The help page states the adjacent-steps rule. But the criterion says this test replaces the score test at `test-vignette-claims.R:125`. The replacement at `test-vignette-claims.R:126` holds a `step` column, so it exercises the AC2 rule and not the fallback of AC3. The diff reviewer and the blame-history reviewer both found this gap.
- AC4: `test-score.R:75` passes. Its frame holds "3", "4", " 3", "\n", and "3.0". It asserts labels `c(3, 4)`, probabilities 9/13 and 4/13, expected value 43/13, SD 6/13, and entropy 0.8904916, with the arithmetic in comments.
- AC5: `test-chat.R:702` passes with `rlmstudio.quiet = FALSE`. Its reply has the steps "3", "\n", "3". The message says 3 token steps for the frame with a `step` column. It says the same for the frame without one.
- AC6: The grep lists 10 files. The rule prose in `R/score.R`, `vignettes/text-analysis.Rmd`, `NEWS.md`, and the comment at `test-chat.R:47` states the AC2 and AC3 rules. No text of the old rule is left. `R/chat.R` and `R/chat_oop.R` hold the five-column help and the step count. The help of `lms_chat_openresponses()` describes `step`. The vignette's pasted logprobs output shows `step`, and its score output has one row per label (3, 4, 5, 2, 1). `test-vignette-claims.R:110` asserts the five names and `test-vignette-claims.R:114` the `step` values. `NEWS.md` has entries for the column, the step rule, and the summed labels. `pkgdown::check_pkgdown()` found no problems.
- AC7: `devtools::document()` gave no diff, and `devtools::test()` gave 0 failures (see the sync line above).

Consistency gate: `cairn_validate.py` passed. No IP or GP changed, so `cairn_impact` did not run. The profile checks passed: `document()` gave no diff, `check_pkgdown()` found no problems, NEWS has the entries, the branch adds no top-level file, and `check()` gave 0 notes. README is not touched.

Reviewer findings, pass 1. The review returned at AC3 before the gate, so none is triaged yet. The next pass triages them at the gate.
- Diff reviewer: (1) `R/score.R:85` gives an entropy of -1.44e-09 for one label, and the label sum makes one label common, as with "3" and " 3". (2) `R/score.R:114` drops a step-1 row whose `step` is `NA`. (3) A first `step` of `NA` uses the token run and ignores later step-1 rows, as AC2 and AC3 state. (4) `R/chat_oop.R:88` counts an `NA` step as a step. (5) The AC3 gap above. (6) `test-chat.R:47` turns any error into `NA`, which hides the message. (7) The batch `step` checks see one step only, and the AC5 test asserts printed text. (8) `NEWS.md:10` puts the print change under the score entry. (9) A "0x3" token is summed into label 3.
- Blame-history reviewer: (1) The AC3 gap above. (2) The live test at `test-chat.R:47` now calls the function it checks, which T5 asked for. (3) Same as diff finding 4. (4) The new rules have no D-entry, and only the work log and NEWS record them.
- Prior-review reviewer: no prior-review evidence on these files, and no PR review comments.

### Pass 2 (after return 1)

Sync 2026-09-30: `origin/main` (cc0d45d) is an ancestor of the branch head 411c632, so no merge was needed, and no PR exists. Fresh runs on 411c632: `devtools::document()` gave no diff. `devtools::test()` gave 0 failures, 3 skips, and 19,668 passes. The skips are the same three live tests as in pass 1.

- AC1: `test-chat.R:331` passes (test-chat.R: 2,543 passes, 0 failures). Its reply has two `output_text` parts with logprobs, a part with none between them, and a step with no candidates. It asserts the five names with `step` last and `step` = `c(1L, 1L, 2L, 3L, 3L, 3L)`. `test-vignette-claims.R:114` asserts `step` for `lms_chat()` on its default route. `test-chat-batch.R:689` and `test-chat-batch-usage.R:374` assert `step` for batch OpenResponses cells. Both files pass with 0 failures.
- AC2: `test-score.R:137` passes over the three frames of the criterion, each against the hand values in its comments and identical to the step-1 rows alone. `test-score.R:196` passes and shows that a first `step` of `NA` follows the AC3 rule. test-score.R: 48 passes, 0 failures.
- AC3: `test-score.R:176` passes. Its frame has no `step` column and the step tokens "3", "\n", "3", and the last "3" rows do not count. Its second frame has a first step token of `NA` and shows which rows count. The replacement of the old score test at `test-vignette-claims.R:126` now builds a frame with no `step` column (tokens "3", "\n", "3"). It passes, and it failed in 5 checks with the old rule planted (work log, T2 repair). The help at `R/score.R:13` states that without a `step` column two adjacent steps with the same token count as one step.
- AC4: `test-score.R:75` passes. It asserts labels `c(3, 4)`, probabilities 9/13 and 4/13, expected value 43/13, SD 6/13, and entropy 0.8904916 for the spellings "3", " 3", "3.0" with "4" and "\n" between them.
- AC5: `test-chat.R:702` passes with `rlmstudio.quiet = FALSE`. A reply with the steps "3", "\n", "3" prints 3 token steps with and without a `step` column.
- AC6: the grep lists 10 files. They are `R/score.R`, `R/chat.R`, `R/chat_oop.R`, the vignette, five test files, and `NEWS.md`. The rule prose in `R/score.R:7`, `NEWS.md:5`, the vignette, and `test-chat.R:47` states the AC2 and AC3 rules. The help of `lms_chat_openresponses()` describes `step`. The vignette's pasted logprobs output shows `step`, and its score output has one row per label. `test-vignette-claims.R:110` asserts the five names and `:114` the `step` values. `NEWS.md:3`, `:5`, and `:8` hold the column, the step rule, and the summed labels.
- AC7: `devtools::document()` gave no diff, and `devtools::test()` gave 0 failures (sync line above).
