# M088: A missing load config or missing OpenAI logprobs warns past quiet

**Status:** done (2026-10-18, PR #91 https://github.com/jmgirard/rlmstudio/pull/91).

**Goal:** With `options(rlmstudio.quiet = TRUE)`, a call that asks for a load config or for logprobs and gets none still says so by a classed warning, and the offline tests pass under that option.

**Outcome:** `lms_load(echo_load_config = TRUE)` on a loaded model, with
`force = FALSE`, warns with class `rlmstudio_no_load_config` in place of
the direct alert at `R/load.R:149`, so no `cli_alert` call is left outside
`R/utils-msg.R`. `warn_no_openai_logprobs()` in `openai_reply_value()` warns
with class `rlmstudio_no_logprobs` after `warn_if_cut_off()`.
`lms_chat_batch()` muffles it per input and gives one warning that counts
the replies, after the failed-inputs and cut-off warnings and in
`abort_with_results()`. Neither follows quiet. The help no longer says that
LM Studio stubs the OpenAI logprobs. Seven message tests pin quiet FALSE.
New test file `test-missing-result-warnings.R`. One NEWS bullet.

**Decisions:** D-043 (warnings past quiet, GP5 and GP6 trades).

**Review:** 7 criteria verified. A criteria audit fixed 14 findings at the
plan, and a claim audit corrected 5 of 60 claims. Three lenses gave 23
findings: 11 fixed, 1 follow-up (new row "openai batch fallback text"),
8 rejected, 3 noted. CI green on the first wait. Graduated the rows
"load echo alert", "openai logprobs stub", and "tests under ambient quiet".
