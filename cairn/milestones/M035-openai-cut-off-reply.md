# M035: A chat completions reply that the token limit cut off no longer passes as complete

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP6
- **Resolves:** —
- **Surface tier:** user-facing — a new abort, a new warning class, and a new help section on three exported chat functions
- **Branch/PR:** —

## Goal

A `/v1/chat/completions` reply can carry the `finish_reason` `"length"`. Such a reply aborts as a schema reply and warns as text, also when the package can read it.

## Scope

**In:** `openai_reply_value()` in `R/chat.R` reads `finish_reason` for every reply with `simplify = TRUE`. A schema reply parsed without logprobs aborts with `rlmstudio_bad_response`. Two kinds of reply return their value and warn with class `rlmstudio_reply_cut_off`: a text reply, and a schema reply with `logprobs = TRUE`. The warning ignores quiet. `lms_chat_batch()` muffles that warning for each input. It gives one warning of the same class for the batch, apart from its failed-inputs warning. Three messages name `max_tokens` and the model's context length: the abort, the warning, and the existing unreadable-reply abort. Either limit can end a reply with `"length"`. The "Malformed response" definition covers a cut-off schema reply. A new "Cut-off reply" help section goes on the three pages that can warn. NEWS gets one bullet for the abort and one for the warning. A D-entry records the choices.

Observed on 2026-09-27 with google/gemma-3-1b. At `max_tokens` 2, a strict integer schema returned content `"3"` with `finish_reason` `"length"`. At `max_output_tokens` 5, `/v1/responses` said `status` `"completed"` and `incomplete_details` null. `/api/v1/chat` carried no cut-off field.

**Out:** The same check on the OpenResponses and native routes. Neither route marks a cut-off reply. That work joins the existing candidate row on unreadable cut-off replies, which waits for such a marker. A `finish_reason` column in the OpenAI data-frame batch gets no row, because the warning names the positions.

## Acceptance criteria

- [ ] AC1: This criterion covers `simplify = TRUE`, a `schema`, and `logprobs = FALSE`. A reply whose `finish_reason` is `"length"` aborts with `rlmstudio_bad_response`, also when its content parses as JSON. The message names `max_tokens` and the context length. The condition's `content` field holds the reply content. Its `finish_reason` field holds `"length"`. Tests feed a mocked reply with content `"3"` to `lms_chat_openai()` and to `lms_chat(api_type = "openai")`. They assert the class, both fields, and the message text. The same reply with `finish_reason` `"stop"` returns `3`. In `lms_chat_batch(api_type = "openai")` with a `schema`, such an input fails. Its slot holds the condition, and the failed-inputs warning names its position. The batch gives no `rlmstudio_reply_cut_off` warning.
- [ ] AC2: This criterion covers `simplify = TRUE`. A reply whose `finish_reason` is `"length"` returns what the same reply with `"stop"` returns. It gives one warning of class `rlmstudio_reply_cut_off`, and the message names `max_tokens` and the context length. This holds in three settings: no `schema`, `logprobs = TRUE`, and a `schema` with `logprobs = TRUE`. Tests call `lms_chat_openai()` in each of the three settings. They also call `lms_chat(api_type = "openai")` with no `schema`. They assert the value, the class, and a count of one warning. A reply with `finish_reason` `"stop"` gives no warning. A reply with no `finish_reason` gives no warning.
- [ ] AC3: The warning of AC2 shows with `options(rlmstudio.quiet = TRUE)`. A test calls `lms_chat_openai()` with the option set and asserts the warning class.
- [ ] AC4: This criterion covers `lms_chat_batch(api_type = "openai")` with no `schema`, or with `logprobs = TRUE`. It gives at most one `rlmstudio_reply_cut_off` warning per call. Its message names the count and every position of the cut-off inputs. Each such input keeps its value. The warning shows with `quiet = TRUE`. A test runs four mocked replies: `"stop"`, `"length"`, `"stop"`, `"length"`. It runs them in each of the three formats and once with `logprobs = TRUE`. It asserts one such warning that names positions 2 and 4, and it asserts the four outputs. One run has `quiet = TRUE`. In one run, one input also fails with status 500. That run gives the failed-inputs warning and the cut-off warning. A batch with no cut-off reply gives no such warning.
- [ ] AC5: With `simplify = FALSE`, a cut-off reply returns the parsed body unchanged, with no warning and no abort. Tests assert this for `lms_chat_openai()` with a `schema` and without one. A test also asserts it for `lms_chat_batch(api_type = "openai", simplify = FALSE, format = "list")`.
- [ ] AC6: The "Malformed response" section of the condition help page says that a cut-off schema reply is a bad response, also when it parses. A "Cut-off reply" section on that page names the `rlmstudio_reply_cut_off` class. It says when the warning is given and that it shows with quiet on. The help pages of `lms_chat_openai()`, `lms_chat()`, and `lms_chat_batch()` carry that section, and no other help page does. `NEWS.md` has one bullet for the abort and one for the warning. Neither bullet names a milestone number.
- [ ] AC7: `devtools::test()` runs clean, and `devtools::document()` produces no diff.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T4
- AC3 → T4
- AC4 → T5
- AC5 → T2, T4, T5
- AC6 → T6
- AC7 → T2, T3, T4, T5, T6

## Tasks

- [ ] T1: Append D-021 to `cairn/DECISIONS.md`. A cut-off schema reply is a bad response, which annotates D-007 and D-018. A cut-off text reply warns. The warning ignores quiet. That is a second GP6 exception, for incomplete results, next to the D-010 exception for lost results. Only the OpenAI route is covered, because the other two routes do not mark a cut-off. D-012 had a shared case, and this one does not. Record the rejected options: a warning for schema replies, an abort for text replies, a warning that honors quiet, and one folded batch warning.
- [ ] T2: Write the AC1 and AC5 tests in `tests/testthat/test-chat-schema.R` first. Use `completion_body()` from `tests/testthat/helper-chat-bodies.R`, and use `local_request_sequence()` for the batch. Then add the abort to `openai_reply_value()` through `abort_unread_reply()`. It runs before `parse_schema_reply()` when the finish reason is `"length"`. Plant a check that skips a reply that parses, and see the `"3"` test go red.
- [ ] T3: Reword the `"length"` detail in `abort_unread_reply()` to name the context length and `max_tokens`. Update the existing `max_tokens` message tests to assert both.
- [ ] T4: Write the AC2 and AC3 tests first. Raise the warning in `openai_reply_value()`, not in `lms_chat_openai()`. The data-frame batch reads the body through that helper in `read_reply()`. Use `cli::cli_warn(class = "rlmstudio_reply_cut_off")` outside the quiet helpers. Make sure that `simplify = FALSE` returns before the warning.
- [ ] T5: Write the AC4 tests first. In `lms_chat_batch()`, wrap each `lms_chat()` call in `withCallingHandlers()`. The handler records the position and muffles only `rlmstudio_reply_cut_off`. `tryCatch()` lets a warning through (M014 lesson). Join the positions with `cli::ansi_collapse(trunc = Inf)` (M018 lesson). Give the batch warning after the failed-inputs warning.
- [ ] T6: Write the AC6 roxygen text in `R/conditions.R` and the three chat pages. Add `@aliases rlmstudio_reply_cut_off`, run `devtools::document()`, and add the two NEWS bullets. Grep `man/` for "Cut-off reply", and make sure that it appears on those three pages only.

## Work log

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: live probe on google/gemma-3-1b. `/v1/chat/completions` sent `finish_reason` `"length"` with a parseable `"3"` at `max_tokens` 2. `/v1/responses` and `/api/v1/chat` sent no cut-off marker at `max_output_tokens` 5, so those routes stay in their candidate row.
- 2026-09-27: criteria audit (full mode, fresh [O] reader) returned 16 findings. 14 were fixed before the gate. The fixes drop a recorded-fixture promise from AC1, add probes for routes, settings, formats, quiet, and `simplify = FALSE`, and limit AC4 to text batches. They also give the warning its own help section and name the context length in the message. Two findings went to the gate: the quiet exception and the batch warning shape.
- 2026-09-27: plan gate chose an abort for a cut-off schema reply and a warning for a cut-off text reply over one rule for both, because a cut-off number is wrong data in a scoring batch and a short text limit is often on purpose; falsified by a user who needs a cut-off schema value kept, or who treats every cut-off text as a failure.
- 2026-09-27: plan gate chose a warning that ignores quiet over one that honors it, because a quiet batch otherwise keeps cut-off answers with no sign (GP2); falsified by a user who runs quiet batches and treats the warning as noise.
- 2026-09-27: plan gate chose a separate classed batch warning over folding it into the failed-inputs warning, because the class tells a caller which fault it reports; falsified by a user who needs a batch to give one warning at most.

## Decisions

## Review
