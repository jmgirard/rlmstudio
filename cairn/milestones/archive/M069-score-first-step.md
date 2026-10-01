# M069: lms_score_expected() reads the first step of a reply alone

**Status:** done (2026-09-30, PR #69 https://github.com/jmgirard/rlmstudio/pull/69).

**Goal:** `lms_score_expected()` scores the first step of a reply alone, so a
later step that repeats the first token no longer adds its candidates.

**Outcome:** `logprobs_frame()` adds an integer `step` column, last. It
numbers the steps from 1 across all `output_text` parts. `first_step_rows()`
in `R/score.R` reads the rows of the first row's `step`. With no `step`, or a
first `step` of `NA`, it reads the first run of the first `step_token`.
Candidates of one label are summed, and one label gives an entropy of 0.
`print.lms_chat_result()` counts steps by `step`, or by token runs. The help,
the vignette (re-run live), NEWS, and a DESIGN line on score oracles follow.

**Decisions:** none cross-cutting. The plan gate chose a `step` column over a
score-only run rule. It put the column last and kept a run fallback for
frames with no `step`. It also summed duplicate labels in this milestone.

**Review:** Three lenses, two passes. Pass 1 returned at AC3, because the
replaced vignette-claims score test held a `step` column. Pass 2 verified
all 7 criteria. The gate fixed five findings, among them the one-label
entropy and the abort for a frame with no `step_token`. Ten were rejected.
