# M035: A chat completions reply that the token limit cut off no longer passes as complete

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP6
- **Resolves:** —
- **Surface tier:** user-facing — a new abort, a new warning class, and a new help section on three exported chat functions
- **Branch/PR:** m035-openai-cut-off-reply

## Goal

A `/v1/chat/completions` reply can carry the `finish_reason` `"length"`. Such a reply aborts as a schema reply and warns as text, also when the package can read it.

## Scope

**In:** `openai_reply_value()` in `R/chat.R` reads `finish_reason` for every reply with `simplify = TRUE`. A schema reply parsed without logprobs aborts with `rlmstudio_bad_response`. Two kinds of reply return their value and warn with class `rlmstudio_reply_cut_off`: a text reply, and a schema reply with `logprobs = TRUE`. The warning ignores quiet. `lms_chat_batch()` muffles that warning for each input. It gives one warning of the same class for the batch, apart from its failed-inputs warning. Three messages name `max_tokens` and the model's context length: the abort, the warning, and the existing unreadable-reply abort. Either limit can end a reply with `"length"`. The "Malformed response" definition covers a cut-off schema reply. A new "Cut-off reply" help section goes on the three pages that can warn. NEWS gets one bullet for the abort and one for the warning. A D-entry records the choices.

Observed on 2026-09-27 with google/gemma-3-1b. At `max_tokens` 2, a strict integer schema returned content `"3"` with `finish_reason` `"length"`. At `max_output_tokens` 5, `/v1/responses` said `status` `"completed"` and `incomplete_details` null. `/api/v1/chat` carried no cut-off field.

**Out:** The same check on the OpenResponses and native routes. Neither route marks a cut-off reply. That work joins the existing candidate row on unreadable cut-off replies, which waits for such a marker. A `finish_reason` column in the OpenAI data-frame batch gets no row, because the warning names the positions.

## Acceptance criteria

- [x] AC1: This criterion covers `simplify = TRUE`, a `schema`, and `logprobs = FALSE`. A reply whose `finish_reason` is `"length"` aborts with `rlmstudio_bad_response`, also when its content parses as JSON. The message names `max_tokens` and the context length. The condition's `content` field holds the reply content. Its `finish_reason` field holds `"length"`. Tests feed a mocked reply with content `"3"` to `lms_chat_openai()` and to `lms_chat(api_type = "openai")`. They assert the class, both fields, and the message text. The same reply with `finish_reason` `"stop"` returns `3`. In `lms_chat_batch(api_type = "openai")` with a `schema`, such an input fails. Its slot holds the condition, and the failed-inputs warning names its position. The batch gives no `rlmstudio_reply_cut_off` warning.
- [x] AC2: This criterion covers `simplify = TRUE`. A reply whose content is one string and whose `finish_reason` is `"length"` returns what the same reply with `"stop"` returns. It gives one warning of class `rlmstudio_reply_cut_off`, and the message names `max_tokens` and the context length. This holds in three settings: no `schema`, `logprobs = TRUE`, and a `schema` with `logprobs = TRUE`. Tests call `lms_chat_openai()` in each of the three settings. They also call `lms_chat(api_type = "openai")` with no `schema`. They assert the value, the class, and a count of one warning. A reply with `finish_reason` `"stop"` gives no warning. A reply with no `finish_reason` gives no warning.
- [x] AC3: The warning of AC2 shows with `options(rlmstudio.quiet = TRUE)`. A test calls `lms_chat_openai()` with the option set and asserts the warning class.
- [x] AC4: This criterion covers `lms_chat_batch(api_type = "openai")` with no `schema`, or with `logprobs = TRUE`. It gives at most one `rlmstudio_reply_cut_off` warning per call. Its message names the count and every position of the cut-off inputs. Each such input keeps its value. The warning shows with `quiet = TRUE`. A test runs four mocked replies: `"stop"`, `"length"`, `"stop"`, `"length"`. It runs them in each of the three formats and once with `logprobs = TRUE`. It asserts one such warning that names positions 2 and 4, and it asserts the four outputs. One run has `quiet = TRUE`. In one run, one input also fails with status 500. That run gives the failed-inputs warning and the cut-off warning. A batch with no cut-off reply gives no such warning.
- [x] AC5: With `simplify = FALSE`, a cut-off reply returns the parsed body unchanged, with no warning and no abort. Tests assert this for `lms_chat_openai()` with a `schema` and without one. A test also asserts it for `lms_chat_batch(api_type = "openai", simplify = FALSE, format = "list")`.
- [x] AC6: The "Malformed response" section of the condition help page says that a cut-off schema reply is a bad response, also when it parses. A "Cut-off reply" section on that page names the `rlmstudio_reply_cut_off` class. It says when the warning is given and that it shows with quiet on. The help pages of `lms_chat_openai()`, `lms_chat()`, and `lms_chat_batch()` carry that section, and no other help page does. `NEWS.md` has one bullet for the abort and one for the warning. Neither bullet names a milestone number.
- [x] AC7: `devtools::test()` runs clean, and `devtools::document()` produces no diff.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T4
- AC3 → T4
- AC4 → T5
- AC5 → T2, T4, T5
- AC6 → T6
- AC7 → T2, T3, T4, T5, T6

## Tasks

- [x] T1: Append D-021 to `cairn/DECISIONS.md`. A cut-off schema reply is a bad response, which annotates D-007 and D-018. A cut-off text reply warns. The warning ignores quiet. D-021 widens the class that D-010 names to warnings that report lost or incomplete results. It does not count exceptions, because the batch format warnings and the server-wait warnings in `R/serve.R` also ignore quiet. Only the OpenAI route is covered, because the other two routes do not mark a cut-off. D-012 had a shared case, and this one does not. Record the rejected options: a warning for schema replies, an abort for text replies, a warning that honors quiet, and one folded batch warning.
- [x] T2: Write the AC1 and AC5 tests in `tests/testthat/test-chat-schema.R` first. Use `completion_body()` from `tests/testthat/helper-chat-bodies.R`, and use `local_request_sequence()` for the batch. Then add the abort to `openai_reply_value()` through `abort_unread_reply()`. It runs before `parse_schema_reply()` when the finish reason is `"length"`. Plant a check that skips a reply that parses, and see the `"3"` test go red.
- [x] T3: Reword the `"length"` detail in `abort_unread_reply()` to name the context length and `max_tokens`. Update the existing `max_tokens` message tests to assert both.
- [x] T4: Write the AC2 and AC3 tests first. Raise the warning in `openai_reply_value()`, not in `lms_chat_openai()`. The data-frame batch reads the body through that helper in `read_reply()`. Use `cli::cli_warn(class = "rlmstudio_reply_cut_off")` outside the quiet helpers. Raise it only after every abort check in `openai_reply_value()` passes, just before the value returns, so a reply never both warns and fails. Make sure that `simplify = FALSE` returns before the warning.
- [x] T5: Write the AC4 tests first. In `lms_chat_batch()`, wrap the whole expression for each input inside the `tryCatch()` in `withCallingHandlers()`. Both branches go inside it, `read_reply()` included, because the data-frame format warns after `lms_chat()` returns. The handler records the position and muffles only `rlmstudio_reply_cut_off`. `tryCatch()` lets a warning through (M014 lesson). Join the positions with `cli::ansi_collapse(trunc = Inf)` (M018 lesson). Give the batch warning after the failed-inputs warning.
- [x] T6: Write the AC6 roxygen text in `R/conditions.R` and the three chat pages. Add `@aliases rlmstudio_reply_cut_off`, run `devtools::document()`, and add the two NEWS bullets. Grep `man/` for "Cut-off reply", and make sure that it appears on those three pages only.

## Work log

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: live probe on google/gemma-3-1b. `/v1/chat/completions` sent `finish_reason` `"length"` with a parseable `"3"` at `max_tokens` 2. `/v1/responses` and `/api/v1/chat` sent no cut-off marker at `max_output_tokens` 5, so those routes stay in their candidate row.
- 2026-09-27: criteria audit (full mode, fresh [O] reader) returned 16 findings. 14 were fixed before the gate. The fixes drop a recorded-fixture promise from AC1, add probes for routes, settings, formats, quiet, and `simplify = FALSE`, and limit AC4 to text batches. They also give the warning its own help section and name the context length in the message. Two findings went to the gate: the quiet exception and the batch warning shape.
- 2026-09-27: plan gate chose an abort for a cut-off schema reply and a warning for a cut-off text reply over one rule for both, because a cut-off number is wrong data in a scoring batch and a short text limit is often on purpose; falsified by a user who needs a cut-off schema value kept, or who treats every cut-off text as a failure.
- 2026-09-27: plan gate chose a warning that ignores quiet over one that honors it, because a quiet batch otherwise keeps cut-off answers with no sign (GP2); falsified by a user who runs quiet batches and treats the warning as noise.
- 2026-09-27: plan gate chose a separate classed batch warning over folding it into the failed-inputs warning, because the class tells a caller which fault it reports; falsified by a user who needs a batch to give one warning at most.
- 2026-09-27: criteria re-audit (full mode, same fresh [O] reader) returned 4 findings, all fixed. AC2 is limited to one-string content again. T4 warns only after every abort check. T5 wraps `read_reply()` too. T1 widens the D-010 class and does not count exceptions.
- 2026-09-27: implement started on branch m035-openai-cut-off-reply. No question gate, because the plan left no choice open.
- 2026-09-27: T1 done. D-021 appended.
- 2026-09-27: T2 done. The AC1 and AC5 tests went red on the old code, which skipped a cut-off reply that parses, and green after the abort. New `tests/testthat/helper-conditions.R` collects warnings as condition objects. `devtools::test()` clean.
- 2026-09-27: T3 done. The `"length"` detail names `max_tokens` and the context length of the model. The four message tests share one helper that asserts both, and they went red before the reword. `devtools::test()` clean.
- 2026-09-27: T4 done. `warn_if_cut_off()` runs in `openai_reply_value()` after every abort check, just before each text return. The AC2 and AC3 tests went red before it. `devtools::test()` clean.
- 2026-09-27: planted a warning before the `simplify = FALSE` return of `lms_chat_openai()`. The AC5 test went red, and the plant was reverted.
- 2026-09-27: T5 done. The batch muffles each input's cut-off warning inside its `tryCatch()` and warns once after the failed-inputs warning. New `tests/testthat/test-chat-batch-cut-off.R` went red before the change. A plant that left the data-frame path unmuffled turned it red too. `devtools::test()` clean.
- 2026-09-27: T6 done. "Cut-off reply" section and `rlmstudio_reply_cut_off` alias on the conditions page, inherited by the three chat pages. A grep of `man/` finds the phrase on those four pages only. The shared "Malformed response" text links to the conditions page, so it does not carry the phrase. Two NEWS bullets. `devtools::document()` gives no diff on a second run, and `devtools::test()` is clean.
- 2026-09-27: claim audit: 49 claims read, 2 corrected — R/chat.R, R/conditions.R
- 2026-09-27: the two corrections name the `lms_chat_openai()` setting that aborts in its `@return` text, and limit the warning class to the OpenAI route in the conditions page intro. The same reader re-read both as true. `devtools::test()` clean, and status set to review.
- 2026-09-27: review evidence recorded for AC1 to AC7, gate clean. The three review lenses reported 11 findings, which go to the merge gate.
- 2026-09-27: gate triage chose fix now for O1, O2, O4, O5, and O10, follow-up rows for O3 and O7, and rejection for the rest. Merge was approved on the condition that the O1 fix is shown once more before the push.
- 2026-09-27: fix-now work done. `devtools::test()` clean, 9862 passed.

## Decisions

## Review

Evidence gathered 2026-09-27 on branch head 1cd4a1f, which contains `origin/main` (dcb9344), so no merge was needed.

- AC1: `test-chat-schema.R` "a schema reply cut off at the token limit aborts even when it parses" feeds content `"3"` with `"length"` to `lms_chat_openai()` and `lms_chat(api_type = "openai")`. It asserts `rlmstudio_bad_response`, `content` `"3"`, `finish_reason` `"length"`, and a message naming `max_tokens` and the context length. The `"stop"` reply returns `3L`. "a batch with a schema fails an input whose reply was cut off" asserts, in list and data-frame formats, the condition in slot 2, one failed-inputs warning naming position 2, and no cut-off warning. Pass in `devtools::test()`.
- AC2: "a text reply cut off at the token limit warns and keeps its value" runs `lms_chat_openai()` with no `schema`, with `logprobs = TRUE`, and with a `schema` and `logprobs = TRUE`. Each asserts the same value as `"stop"`, one `rlmstudio_reply_cut_off` warning, and a message naming both limits. `"stop"` and a missing finish reason give no warning. `lms_chat(api_type = "openai")` gives one warning of the class. Pass.
- AC3: "the cut-off warning shows with quiet on" sets `rlmstudio.quiet = TRUE` and asserts the `rlmstudio_reply_cut_off` class from `lms_chat_openai()`. Pass.
- AC4: `test-chat-batch-cut-off.R` runs the four replies `"stop"`, `"length"`, `"stop"`, `"length"` in the vector, list, and data-frame formats with `quiet = TRUE`, and in the list format with `logprobs = TRUE`. Each run asserts one cut-off warning naming "2 inputs" and "positions 2 and 4" and the four outputs. A run with status 500 at position 3 asserts the failed-inputs warning first and the cut-off warning second. A batch with no cut-off reply gives no warning. Pass.
- AC5: "simplify = FALSE returns a cut-off reply unchanged" asserts the parsed body and no warning for `lms_chat_openai()` with and without a `schema`. It asserts the same for `lms_chat_batch(api_type = "openai", simplify = FALSE, format = "list")`. Pass.
- AC6: `grep -l "Cut-off reply" man/*.Rd` lists `lms_chat.Rd`, `lms_chat_batch.Rd`, `lms_chat_openai.Rd`, and `rlmstudio-conditions.Rd` only. The "Malformed response" text says a cut-off schema reply is raised also when it parses. The "Cut-off reply" section names the class, when it is given, and that it shows with quiet on. `NEWS.md` has one bullet for the abort and one for the warning. Neither names a milestone. Pass.
- AC7: `devtools::test()` gave 9850 passed, 0 failed, 0 errors, and 0 skipped. After `devtools::document()`, `git status` was clean. Pass.
- Consistency gate: `cairn_validate.py` exit 0. No DESIGN principle changed, so `cairn_impact` was skipped. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, with live vignette builds. The branch did not touch README.Rmd. The repo has no pkgdown site and no new top-level files.
- Review lenses: the blame-history reader found nothing. The prior-review reader found no prior-review evidence. The diff reader reported 11 findings, ranked below. Triage is pending at the merge gate.
- O1: A batch that aborts partway, on a lost server or on status 401, 403, or 404, drops the cut-off positions it already muffled. The condition's `results` then hold cut-off text with no sign.
- O2: The "with the option on" run in `test-chat-batch-cut-off.R` does not test the option. `lms_chat_batch()` defaults to `quiet = FALSE`, so `rlmstudio.quiet` is never read.
- O3: The shared "Malformed response" sentence about the warning links to the conditions page from that same page. Through `@inheritSection`, it also lands on about ten pages that cannot warn.
- O4: The conditions page title still says "Error conditions", and its intro still counts three classes. The page now also documents a warning class.
- O5: The detail string "The reply is not complete." in `openai_reply_value()` is never shown. `abort_unread_reply()` replaces the detail for `"length"`.
- O6: Under `options(warn = 2)`, the batch cut-off warning becomes an error after every request ran, so no result returns.
- O7: Only `choices[[1]]` is checked. With `n = 2` in `...`, a cut-off second choice gives no warning.
- O8: A `finish_reason` that is not one string, such as `["length"]`, is not read as a cut-off.
- O9: `warn_if_cut_off()` passes `call = NULL` and the batch warning does not. The single-call message does not mention the content.
- O10: The `lms_chat()` case of the AC2 test and the AC3 test do not assert the message text.
- O11: No test covers a cut-off input before a batch abort. The failed-plus-cut-off run covers the vector format only.
- Triage at the gate: O1 fix now. The batch gives its cut-off warning before a lost server or a 401, 403, or 404 abort. A new test went red first, then green. NEWS and the "Cut-off reply" section say so.
- Triage: O2, O4, O5, and O10 fix now. O2 drops the option run and says why. O4 retitles the page "Conditions raised by rlmstudio". O5 passes `NULL` for the unused detail. O10 asserts the message in both tests.
- Triage: O3 follow-up, folded into the candidate row on the shared "Malformed response" section. O7 follow-up, a new candidate row.
- Triage: O6 rejected, because `warn = 2` is the user's own choice to turn warnings into errors. O8 rejected, because LM Studio sends `finish_reason` as a string. O9 rejected as cosmetic. O11 rejected in part, because AC4 allows the narrower run. The O1 test covers the abort case.
- After the fixes: `devtools::test()` gave 9862 passed and 0 failed. `devtools::document()` regenerated the three chat pages and the conditions page. `grep -l "Cut-off reply" man/*.Rd` still lists the same four pages.
