# M088: A missing load config or missing OpenAI logprobs warns past quiet

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP5, GP6
- **Resolves:** —
- **Surface tier:** user-facing — two exported functions gain warnings that users see and catch by class
- **Branch/PR:** m088-missing-result-warnings

## Goal

With `options(rlmstudio.quiet = TRUE)`, a call that asks for a load config or for logprobs and gets none still says so by a classed warning, and the offline tests pass under that option.

## Scope

**In:** the three quiet-option follow-ups that the M086 review left, from the candidate rows "load echo alert", "openai logprobs stub", and "tests under ambient quiet".
`lms_load()` replaces its direct `cli::cli_alert_warning()` at `R/load.R:149` with a warning of class `rlmstudio_no_load_config`.
`openai_reply_value()` (`R/chat.R:827-833`) warns with class `rlmstudio_no_logprobs` when it returns a value for `logprobs = TRUE`, so `lms_chat_openai()`, `lms_chat(api_type = "openai")`, and the OpenAI batch all reach one site.
`lms_chat_batch()` muffles that warning for each input and gives one warning of the same class for the batch, as it does for `rlmstudio_reply_cut_off`, on its abort path too.
Neither warning follows `quiet` or `rlmstudio.quiet` (D-043).
Tests that fail under an ambient `rlmstudio.quiet = TRUE` pin the option to `FALSE`. Help pages, class aliases, and one NEWS bullet.

**Out:**
- The native-route logprobs warnings of `lms_chat()`, `lms_chat_native()`, and the native batch stay unclassed. Not asked for, no candidate row.
- Reading real logprobs from `/v1/chat/completions`. D-033 names that as the change that reopens the OpenAI column; no candidate row holds it, because no probe shows that the endpoint sends them.
- The "request-body checks in skipped files" row stays a candidate.
- The live tests, which skip without an LM Studio server, are not run under the option.

## Acceptance criteria

- [ ] AC1: With `echo_load_config = TRUE`, `force = FALSE`, and a model whose model-list `state` is `"loaded"`, `lms_load()` returns the model key invisibly, sends no load request, and gives exactly one warning of class `rlmstudio_no_load_config`, with `rlmstudio.quiet` set to `TRUE` and to `FALSE`. With `echo_load_config = FALSE` and the same model, or with `echo_load_config = TRUE` and a model that is not loaded, the call gives no warning of that class, and the second returns the load config.
- [ ] AC2: `lms_chat_openai(logprobs = TRUE, simplify = TRUE)` that returns a value gives exactly one warning of class `rlmstudio_no_logprobs`, with `rlmstudio.quiet` set to `TRUE` and to `FALSE`, and with a `schema` as well as without one. `lms_chat(api_type = "openai", logprobs = TRUE)` with `rlmstudio.quiet = TRUE` gives exactly one as well. A reply with the finish reason `"length"` gives the `rlmstudio_reply_cut_off` warning first and then the `rlmstudio_no_logprobs` warning. A call with `logprobs = FALSE`, a call with `simplify = FALSE`, a reply with `null` content (`rlmstudio_bad_response`), and a status-500 reply (`rlmstudio_api_error`) give none.
- [ ] AC3: `lms_chat_batch(api_type = "openai", logprobs = TRUE, simplify = TRUE)` gives exactly one warning of class `rlmstudio_no_logprobs` in each of the `"list"`, `"vector"`, and `"data.frame"` formats when at least one input returns a value, with `rlmstudio.quiet = TRUE` and with `quiet = TRUE`. It comes after the failed-inputs warning and the cut-off warning. A batch that aborts on a lost server after one input returned a value gives it before the abort. A batch whose inputs all fail, and a `simplify = FALSE` batch in the list and vector formats, give none.
- [ ] AC4: `grep -rn 'cli_alert' R/` prints no line outside `R/utils-msg.R`.
- [ ] AC5: With `options(rlmstudio.quiet = TRUE)` set before the run, the tests of `devtools::test()` that run without a live LM Studio server report 0 failures and 0 errors.
- [ ] AC6: `?lms_load`, `?lms_chat_openai`, `?lms_chat`, and `?lms_chat_batch` name the new warning class that each can give and say that the `rlmstudio.quiet` option does not hide it; `?lms_chat_batch` says that the batch gives one such warning. `utils::help("rlmstudio_no_load_config", package = "rlmstudio")` and `utils::help("rlmstudio_no_logprobs", package = "rlmstudio")` each find one topic. NEWS.md has one bullet for both warnings.
- [ ] AC7: `devtools::test()` is clean, `devtools::document()` gives no diff, and `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T1
- AC5 → T4
- AC6 → T5
- AC7 → T6

## Tasks

- [x] T1: In `lms_load()` (`R/load.R:146-154`), replace the echo alert with `cli::cli_warn(class = "rlmstudio_no_load_config")`, after the quiet-aware "already loaded" info line. Word the message from the already-loaded case and `force = TRUE`. Tests first for each AC1 case with a mocked transport, through the shared request recorder (the pre-check sends a `list_models()` request, LESSONS M008); count warnings with `withCallingHandlers()` (LESSONS M019); confirm the test goes red with the alert put back.
- [x] T2: In `openai_reply_value()` (`R/chat.R:827-833`), after every reply check passes and after `warn_if_cut_off()`, warn with class `rlmstudio_no_logprobs` that the package returns no log probabilities on this route, with a pointer to the OpenResponses route. Tests first for each AC2 case with a mocked transport, including the delegate path of `lms_chat()` (LESSONS M003).
- [x] T3: In `lms_chat_batch()` (`R/chat.R` near `note_cut_off`), add a calling handler for `rlmstudio_no_logprobs` that muffles each input's warning and counts the inputs, and a helper that gives one warning of that class when the count is above 0. Call it after `warn_cut_off_inputs()` at the end and in `abort_with_results()`. Tests first for each AC3 case with a mocked transport.
- [x] T4: Pin `withr::local_options(rlmstudio.quiet = FALSE)` in each test that fails under the option (LESSONS M086). A run on main at 5305240 failed 8 expectations in 7 tests: `test-daemon.R` "lms_daemon_stop exits gracefully when managed by GUI", `test-model-list-shape.R` "an empty model list returns an empty data frame and informs" and "an empty model list reaches the callers as nothing loaded", `test-unload.R` "lms_unload_all returns early when list_models reports nothing loaded", and three tests of `test-vignette-claims.R` (headless `install_lmstudio()`, `lms_daemon_stop()`, `lms_server_stop()`). Re-run under the option until the run is clean.
- [x] T5: Help: `@return` or the warning text of `lms_load()`, `lms_chat_openai()` (`R/chat.R:612-614`, `639-646`), `lms_chat()`, and `lms_chat_batch()` (`R/chat.R:1855-1858`), and `@aliases` for both classes. One NEWS.md bullet.
- [x] T6: `devtools::document()`, `devtools::test()`, `devtools::check()`.

## Work log

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: what to work on — the quiet follow-ups (rows "load echo alert", "openai logprobs stub", "tests under ambient quiet").
- 2026-10-18: question set: load echo signal — a classed warning past quiet. Rejected a quiet-aware alert, because a quiet script then gets the model key with no sign that the config is missing; falsified by a user who reports the warning as noise in quiet scripts.
- 2026-10-18: question set: OpenAI logprobs — warn past quiet at the call, one warning per batch. Rejected no warning, because the help and the quiet-hidden print line are then the only signs; falsified by a quiet-batch user who reports the warning as noise.
- 2026-10-18: plan chose one warning site in `openai_reply_value()` over a warning before the request in `lms_chat_openai()`, because the single call and every batch format reach that helper and a failed reply then gives no warning (as `warn_if_cut_off()` does); falsified by a caller who needs the warning on a call whose reply fails.
- 2026-10-18: plan chose a batch warning after the loop over one before the loop (D-032's native form), because the OpenAI route still sends the flag and returns a result per input, so the warning follows the replies; falsified by a user who needs the warning for a batch whose inputs all fail.
- 2026-10-18: collision sweep: candidate rows "load echo alert", "openai logprobs stub", "tests under ambient quiet" absorbed in full. D-010, D-021, D-028, D-032, D-033, D-037 read: this widens the GP6 exception of D-010 and D-021 and keeps D-033's OpenAI `logprobs` column. No planned or in-progress milestone. GitHub inbox: 0 open issues, 0 open PRs.
- 2026-10-18: ambient-quiet probe: `devtools::test()` with the option TRUE on main at 5305240 failed 8 expectations in 7 tests across 4 files, 0 errors, 3 skipped; T4 lists them (the candidate row named 4 in one file).
- 2026-10-18: criteria audit (full mode, fresh Opus reader) returned 14 findings, all fixed: AC2 and AC3 gained `simplify`, `schema`, local `quiet`, failure-kind, cut-off order, and abort-path cases; AC1 gained the not-loaded case; AC1-AC3 lost their test-harness clauses (moved to T1-T3); AC5 narrowed to the tests that run without LM Studio; AC6 added `?lms_chat` and `?lms_chat_batch`; GP5 added; D-043 written at the plan commit; a no-op T5 step dropped.
- 2026-10-18: implement started on branch m088-missing-result-warnings, cut from main at 34d97fa.
- 2026-10-18: T1 done: `lms_load()` warns with class `rlmstudio_no_load_config` (alias on `?lms_load`, `@return` text); new `test-missing-result-warnings.R` failed 2 expectations on the old alert, then passed; `grep -rn 'cli_alert' R/` finds nothing outside `R/utils-msg.R`; full suite 0 failed, 0 errors, 3 skipped.
- 2026-10-18: T2 and T3 done in one commit, because T2 alone gave one warning per batch input and left 14 batch tests red: `warn_no_openai_logprobs()` in `openai_reply_value()` after `warn_if_cut_off()`; the batch muffles it, counts the replies, and warns once after `warn_cut_off_inputs()` at the end and in `abort_with_results()`. New tests failed before the code (no warning) and with the batch handler or the abort-path call removed (8 and 1 tests red).
- 2026-10-18: T2/T3 choice: the batch message counts the replies ("2 replies") and does not list positions, because every reply that returns lacks logprobs; the single-call hint names `lms_chat_openresponses()`.
- 2026-10-18: T2/T3 existing tests that count warnings on the OpenAI logprobs route now expect the new one: `test-batch-native-logprobs.R`, `test-chat-batch-cut-off.R`, `test-chat-batch.R` (3 tests), `test-chat-schema.R` (4 tests), `test-vignette-claims.R` (1); `test-chat-batch-usage.R` helpers set it apart. Full suite 0 failed, 0 errors, 0 warnings, 3 skipped.
- 2026-10-18: T4 done: the run under `rlmstudio.quiet = TRUE` after T3 failed the same 8 expectations in 7 tests; each of the 7 now pins `rlmstudio.quiet = FALSE` as its first line. Re-run under the option: 0 failed, 0 errors, 3 skipped; plain run: 0 failed, 0 errors, 0 warnings, 3 skipped.
- 2026-10-18: T5 done: `?lms_chat` (`@return`), `?lms_chat_openai` (`@param logprobs`, `@return`, alias `rlmstudio_no_logprobs`), `?lms_chat_batch` (`...` logprobs paragraph); `?lms_load` was done in T1. The `lms_chat_openai()` help no longer says that LM Studio stubs the logprobs, a claim no probe backs; it says the package reads none. Installed to a scratch library, `utils::help()` finds one topic for each class (`lms_load`, `lms_chat_openai`). One NEWS bullet.
- 2026-10-18: T6 done: `devtools::document()` no diff; `devtools::test()` 0 failed, 0 errors, 0 warnings, 3 skipped; `devtools::check()` 0 errors, 0 warnings, 0 notes.
- 2026-10-18: claim audit: 60 claims read, 5 corrected — R/chat.R (`lms_chat_batch` abort paths and "no reply is read", `lms_chat_openai` `logprobs` param under `simplify = TRUE`, `lms_chat` `@return` route wording), NEWS.md ("two cases", `force = FALSE`, `simplify = TRUE` and at least one reply read). Tests re-run after the fixes: 0 failed, 0 errors, 0 warnings, 3 skipped.
