# M069: lms_score_expected() reads the first step of a reply alone

- **Status:** in-progress
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

- [ ] AC1: With `logprobs = TRUE`, the logprobs data frame of
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
- [ ] AC2: Given a frame with a `step` column whose first value is not
      `NA`, `lms_score_expected()` reads only the rows whose `step` equals
      the `step` of the first row. Tests cover three frames. In the first,
      step 1 and step 3 share the step token "3". In the second, steps 1
      and 2 share it. In the third, a row of step 1 comes after a row of
      step 2. In each, the result equals hand-computed values (arithmetic
      in comments). In each, it is identical to the result for the step-1
      rows alone. A frame whose first `step` is `NA` follows AC3, and a
      test shows it.
- [ ] AC3: Given a frame with no `step` column, `lms_score_expected()`
      reads the first run of consecutive rows whose `step_token` is
      identical to that of the first row, `NA` included. A test with the
      step tokens "3", "\n", "3" shows that the last "3" rows do not count.
      A test with a first step token of `NA` shows which rows count. This
      test replaces the score test at `test-vignette-claims.R:125`, which
      holds the old rule. The help page states this: without a `step`
      column, two adjacent steps with the same token count as one step.
- [ ] AC4: Candidates of the read step can have tokens that give the same
      label, such as "3", " 3", and "3.0". They give one row of
      `probabilities` that holds the sum of their probabilities, in order
      of first appearance. The `entropy` uses those summed rows. The
      expected value and the weighted standard deviation do not change. A
      test asserts hand-computed values for a frame with those three
      spellings and another label between them.
- [ ] AC5: For a frame with a `step` column, the print method of
      `lms_chat_result` reports the number of distinct `step` values. For
      a frame with no `step` column, it reports the number of runs of
      consecutive identical `step_token` values. With
      `rlmstudio.quiet = FALSE`, a test of a three-step reply whose steps 1
      and 3 share a token shows 3 steps in each case.
- [ ] AC6: `grep -rl 'step_token\|lms_score_expected' R vignettes tests
      README.Rmd NEWS.md` lists files. In each, prose or test code that
      says which rows `lms_score_expected()` reads states the rules of AC2
      and AC3. The help of `lms_chat_openresponses()` describes the `step`
      column. In `vignettes/text-analysis.Rmd`, the pasted logprobs output
      shows the `step` column, and the pasted score output shows one row
      per label. `test-vignette-claims.R` asserts the five column names and
      the `step` values of its mocked reply. `NEWS.md` has an entry for the
      new column, the step rule, and the summed labels.
- [ ] AC7: The `verify` slot of `cairn/PROFILE.md` is clean:
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
- [ ] T3: Sum the probabilities of candidates that give the same label.
      Add the test of AC4, with its arithmetic in comments. Plant the
      unsummed rule and see the test go red.
- [ ] T4: In `print.lms_chat_result()` (`R/chat_oop.R:78`), count steps as
      AC5 states. Add the test of AC5.
- [ ] T5: Run the AC6 grep and fix each site it lists, including the
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

## Decisions

## Review
