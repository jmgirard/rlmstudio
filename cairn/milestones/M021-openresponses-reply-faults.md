# M021: An unreadable OpenResponses reply names its fault

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — it changes what exported chat functions return and raise
- **Branch/PR:** —

## Goal

A reply that `lms_chat_openresponses()` cannot read aborts with `rlmstudio_bad_response` and a message that names its fault.

## Scope

**In:** Checks on the `logprobs` value of each `output_text` part, with one message per broken rule and exact-name reads of its fields. A cut-off message for an unreadable OpenResponses reply that the server marks as cut off by the token limit. Unreadable native and OpenResponses replies abort with the detail of the first check they fail, and the tests pin that detail per shape. Help page, `@return` text, and NEWS.

**Out:** The native route's cut-off message. Its docs name no field for a cut-off, so it becomes a candidate row. A cut-off reply whose text is readable still returns the partial text with no sign, which is a candidate row. A condition field for the cut-off reason is not added, because `simplify = FALSE` returns the body.

## Acceptance criteria

Rules for a `logprobs` value. The value must follow these rules, checked in this order.
R1: the value is absent, `null`, or an array.
R2: each step in the array is a JSON object.
R3: the `token` of a step is absent, `null`, or a string.
R4: the `logprob` of a step is absent, `null`, or a number.
R5: the `top_logprobs` of a step is absent, `null`, or an array of JSON objects.
R6: the `token` and `logprob` of each of those objects follow R3 and R4.
The checks go over the parts in order, then the steps of a part in order, then the candidates of a step in order.

- [ ] AC1: Take a reply whose `output_text` part carries a `logprobs` value that breaks a rule. With `simplify = TRUE` and `logprobs = TRUE`, `lms_chat_openresponses()` raises `rlmstudio_bad_response` for it. The message names the first rule broken. The bad value can be in the first part, a later part, or a part of a later message item. The bad field can be in the first step or in a step after good steps. It can also be in a `top_logprobs` entry, or in a candidate after good candidates. A `logprobs` value on a part of another type, such as a refusal, is not checked. With `logprobs = FALSE`, a reply that breaks a rule returns its text.
- [ ] AC2: A `logprobs` value that follows R1 to R6 gives the same return value as before, with one change. Fields are now read by exact name, so a step that holds a `tokenX` field and no `token` field reads `NA` for its token. The same holds for `logprob`, `top_logprobs`, and the fields of a candidate. A `null` or absent token or logprob still gives `NA`.
- [ ] AC3: `lms_chat_batch()` with `logprobs = TRUE` on the OpenResponses route stores the AC1 condition in the slot of the failed input. It keeps the replies of the other inputs and warns once, as it does for other failed inputs.
- [ ] AC4: Take a reply that fails one of the checks in `chat_message_items()`, `responses_text_parts()`, or `join_reply_texts()`. It carries `status` `"incomplete"` and `incomplete_details.reason` `"max_output_tokens"`. Its `rlmstudio_bad_response` message says that the token limit cut the reply off and names `max_output_tokens`, in place of the shape detail. The shape detail stays in three cases: `status` is not `"incomplete"`, the reason is absent, or the reason is another value. A reply that breaks a `logprobs` rule keeps the rule message.
- [ ] AC5: Each unreadable native or OpenResponses reply aborts with the detail sentence of the first check it fails. The checks run in this order: the `output` array, its items, the message items, the `content` of a message, its parts, the `output_text` parts, and the answer texts.
- [ ] AC6: The `rlmstudio-conditions` help page, the `@return` text of `lms_chat_openresponses()`, and `NEWS.md` state the AC1, AC2, and AC4 behavior.
- [ ] AC7: `devtools::test()` and `devtools::check()` pass with no errors, warnings, or notes beyond those on the default branch.

## Coverage

- AC1 → T2, T3
- AC2 → T2, T3
- AC3 → T4
- AC4 → T1, T5
- AC5 → T6
- AC6 → T7
- AC7 → T7

## Tasks

- [ ] T1: Write a `data-raw/` script that sends a cut-off request with `max_output_tokens` of 5 to `/v1/responses` and to `/api/v1/chat`. If a reasoning model is on the machine, use it as well, so that a reply can end before any message item. Commit the OpenResponses reply as a cassette. Log which fields the native reply carries, and write them into the native candidate row. If the OpenResponses reply has no `status` `"incomplete"` or no reason `"max_output_tokens"`, stop. Then move AC4 and T5 to a candidate row through the amendment gate.
- [ ] T2: In `R/chat.R` near lines 188 to 238, add a helper that checks a part's `logprobs` value against R1 to R6 in the stated order. It aborts through `rlm_abort_bad_response()` with one message per rule and builds the rows with `[[` reads.
- [ ] T3: In `tests/testthat/helper-chat-bodies.R`, add a table of values that break each rule, with two JSON types per rule. R1 takes an object and a number, and R2 takes `[5]`. Test every location that AC1 names, the refusal part, and `logprobs = FALSE`. Test the exact-name reads and the `null` and absent fields of AC2. The existing logprobs tests and the `chat_integration` replays must pass unchanged.
- [ ] T4: In `tests/testthat/test-chat-batch.R`, run three inputs with `format = "list"`. The second reply carries `[5]`. Assert the R2 condition in slot 2, the replies in slots 1 and 3, and one warning.
- [ ] T5: Read `status` and `incomplete_details` once in `lms_chat_openresponses()`, and pass the cut-off state to the three helpers that AC4 names. Test every shape in `responses_unreadable()` with the cut-off fields, and the three cases that keep the shape detail.
- [ ] T6: Pair each shape in `native_unreadable()` and `responses_unreadable()` with the detail sentence of its first failed check. Assert that sentence per shape in `tests/testthat/test-chat.R`.
- [ ] T7: Update `R/conditions.R` lines 67 to 77, the `@return` text at `R/chat.R` lines 136 to 139, and `NEWS.md`. Run `devtools::document()`, `devtools::test()`, and `devtools::check()`.

## Work log

- 2026-09-22: created by /milestone-plan. It absorbs the three M020 review candidate rows O1, O2, and O3.
- 2026-09-22: criteria audit, full mode, fresh reader. It returned 12 findings, 9 fixed in the wording and 1 posed at the gate as the no-marker question, with 2 with no finding.
- 2026-09-22: plan gate chose a candidate row for the native cut-off. It rejected a guess from `stats.total_output_tokens` against the request's `max_output_tokens`. The docs name no cut-off field, and the guess misreads a reply that ends at the limit. Falsified by a live native reply that carries a cut-off field.
- 2026-09-22: plan gate chose this: a T1 reply from `/v1/responses` with no cut-off marker moves AC4 to a candidate row. It rejected code against the OpenAI fields anyway, because no live test can show that such code works. Falsified by a T1 recording that carries the marker, which keeps AC4.
- 2026-09-22: plan kept the `logprobs` rule message on a cut-off reply and rejected the cut-off message there. A cut-off does not change the JSON type of a field. Falsified by a live cut-off reply whose `logprobs` breaks a rule.

## Decisions

## Review
