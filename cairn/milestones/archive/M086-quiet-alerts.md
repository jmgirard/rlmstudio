# M086: Every alert of the package follows the quiet option

**Status:** done (2026-10-18, PR #89 https://github.com/jmgirard/rlmstudio/pull/89).

**Goal:** With `options(rlmstudio.quiet = TRUE)`, no alert of the package prints, except the `lms_load()` echo alert that the "load echo alert" candidate row holds.

**Outcome:** `R/utils-msg.R` gains `rlm_alert_warning()` and
`rlm_alert_danger()`, built as `rlm_alert_info()` is. Five direct
`cli::cli_alert_*` calls now go through them: the missing-CLI, unparsed-version,
and too-old alerts of `check_lms_version()`, the restart request of the browser
branch of `install_lmstudio()`, and the empty-logprobs line of
`print.lms_chat_result()`. The only direct alert left outside `utils-msg.R` is
`R/load.R:149`. New table test `test-quiet-alerts.R` runs each call with the
option TRUE and FALSE. One NEWS bullet.

**Decisions:** none.

**Review:** 4 criteria verified. Three lenses gave 7 findings: 1 fixed (two
alert-text tests in `test-setup.R` and `test-vignette-claims.R` now pin the
option to FALSE), 2 follow-ups (new row "openai logprobs stub"; the echo alert
stays in "load echo alert"), 3 rejected as planned changes, 1 lens empty. Four
older tests that fail on main under an ambient quiet option went to the new row
"tests under ambient quiet". CI green on the first wait. Graduated the
"install message quiet" row.
