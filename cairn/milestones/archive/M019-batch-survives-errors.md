# M019: A failed input no longer ends a chat batch

**Status:** done (2026-09-22, PR #19 https://github.com/jmgirard/rlmstudio/pull/19,
every check green after one rerun of an r2u mirror timeout, squash 9c91ca6)

**Goal:** `lms_chat_batch()` stores an API failure or an unreadable reply in the
failed input's slot and goes on, and a lost server still aborts but hands back
the replies received so far.

**Outcome:** The batch loop is a `for` loop over a preset list. A `tryCatch()`
stores `rlmstudio_api_error` and `rlmstudio_bad_response` without the trace,
and signals `rlmstudio_no_server` again with a `results` field. Text results
hold `NA` for a failed or `NULL` reply. A logprobs data frame always has its
column. One `cli::cli_warn()` names every failed position and folds in the
vector format's reason. `tests/testthat/test-chat-batch.R` and
`helper-chat-bodies.R` are new.

**Decisions:** D-011, which extends D-010.

**Review:** Two passes, three-lens fan-out, user-facing tier. Pass 1 returned
the milestone once: every failed input dropped the logprobs column (AC2). Five
findings became T8 to T10, and a claim audit added T11. Pass 2 passed all six
criteria. Three wording fixes landed at the gate, and five findings went to
three candidate rows. Pruned the M002 push-trigger lesson: M011 covers
`R-CMD-check`, and the headless workflow does run on a branch push.
