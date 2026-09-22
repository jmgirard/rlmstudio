# M021: An unreadable OpenResponses reply names its fault

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — it changes what exported chat functions return and raise
- **Branch/PR:** m021-openresponses-reply-faults

## Goal

A reply that `lms_chat_openresponses()` cannot read aborts with `rlmstudio_bad_response` and a message that names its fault.

## Scope

**In:** Checks on the `logprobs` value of each `output_text` part, with one message per broken rule and exact-name reads of its fields. Unreadable native and OpenResponses replies abort with the detail of the first check they fail, and the tests pin that detail per shape. Help page, `@return` text, and NEWS.

**Out:** The cut-off message on both routes. A live cut-off reply from `/v1/responses` carries `status` `"completed"` and `incomplete_details` `null`. The native docs name no cut-off field. So each route becomes a candidate row. A cut-off reply whose text is readable still returns the partial text with no sign, which is a candidate row.

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
- [x] AC2: A `logprobs` value that follows R1 to R6 gives the same return value as before, with one change. Fields are now read by exact name, so a step that holds a `tokenX` field and no `token` field reads `NA` for its token. The same holds for `logprob`, `top_logprobs`, and the fields of a candidate. A `null` or absent token or logprob still gives `NA`.
- [x] AC3: `lms_chat_batch()` with `logprobs = TRUE` on the OpenResponses route stores the AC1 condition in the slot of the failed input. It keeps the replies of the other inputs and warns once, as it does for other failed inputs.
- [x] AC4: Each unreadable native or OpenResponses reply aborts with the detail sentence of the first check it fails. The checks run in this order: the `output` array, its items, the message items, the `content` of a message, its parts, the `output_text` parts, and the answer texts.
- [x] AC5: The `rlmstudio-conditions` help page, the `@return` text of `lms_chat_openresponses()`, and `NEWS.md` state the AC1 and AC2 behavior.
- [x] AC6: `devtools::test()` and `devtools::check()` pass with no errors, warnings, or notes beyond those on the default branch.

## Coverage

- AC1 → T2, T3
- AC2 → T2, T3
- AC3 → T4
- AC4 → T5
- AC5 → T6
- AC6 → T6

## Tasks

- [x] T1: Send a cut-off request with `max_output_tokens` of 5 to `/v1/responses` and to `/api/v1/chat`. Use each chat model on the machine. If a reasoning model is there, use it as well. Log which fields each reply carries, and write them into the cut-off candidate row. The OpenResponses reply had no `status` `"incomplete"`. So the cut-off criterion and its task moved to that row through the amendment gate. No script or cassette is committed.
- [x] T2: In `R/chat.R` near lines 188 to 238, add a helper that checks a part's `logprobs` value against R1 to R6 in the stated order. It aborts through `rlm_abort_bad_response()` with one message per rule and builds the rows with `[[` reads.
- [x] T3: In `tests/testthat/helper-chat-bodies.R`, add a table of values that break each rule, with two JSON types per rule. R1 takes an object and a number, and R2 takes `[5]`. Test every location that AC1 names, the refusal part, and `logprobs = FALSE`. Test the exact-name reads and the `null` and absent fields of AC2. The existing logprobs tests and the `chat_integration` replays must pass unchanged.
- [x] T4: In `tests/testthat/test-chat-batch.R`, run three inputs with `format = "list"`. The second reply carries `[5]`. Assert the R2 condition in slot 2, the replies in slots 1 and 3, and one warning.
- [x] T5: Pair each shape in `native_unreadable()` and `responses_unreadable()` with the detail sentence of its first failed check. Assert that sentence per shape in `tests/testthat/test-chat.R`.
- [x] T6: Update `R/conditions.R` lines 67 to 77, the `@return` text at `R/chat.R` lines 136 to 139, and `NEWS.md`. Run `devtools::document()`, `devtools::test()`, and `devtools::check()`.

## Work log

- 2026-09-22: created by /milestone-plan. It absorbs the three M020 review candidate rows O1, O2, and O3.
- 2026-09-22: criteria audit, full mode, fresh reader. It returned 12 findings, 9 fixed in the wording and 1 posed at the gate as the no-marker question, with 2 with no finding.
- 2026-09-22: plan gate chose a candidate row for the native cut-off. It rejected a guess from `stats.total_output_tokens` against the request's `max_output_tokens`. The docs name no cut-off field, and the guess misreads a reply that ends at the limit. Falsified by a live native reply that carries a cut-off field.
- 2026-09-22: plan gate chose this: a T1 reply from `/v1/responses` with no cut-off marker moves AC4 to a candidate row. It rejected code against the OpenAI fields anyway, because no live test can show that such code works. Falsified by a T1 recording that carries the marker, which keeps AC4.
- 2026-09-22: plan kept the `logprobs` rule message on a cut-off reply and rejected the cut-off message there. A cut-off does not change the JSON type of a field. Falsified by a live cut-off reply whose `logprobs` breaks a rule.
- 2026-09-22: started by /milestone-implement on branch m021-openresponses-reply-faults. No implementation question was open, so the question gate was skipped.
- 2026-09-22: T1 probe with `max_output_tokens` 5 and temperature 0, on google/gemma-3-1b and qwen/qwen3-4b-2507. `/v1/responses` returned 4 tokens with `status` `"completed"` and `incomplete_details` `null`. `/api/v1/chat` returned only `model_instance_id`, `output`, `stats`, and `response_id`. Neither model is a reasoning model.
- 2026-09-22: amendment (substantive) at the mini gate: old AC4 and T5 removed, and the cut-off message moved to the candidate row with the native one. AC5 to AC7 became AC4 to AC6, and T6 and T7 became T5 and T6. Scope In lost the cut-off line, and Scope Out names both routes.
- re-audit: AC5 (full) — one finding: the wording does not say whether each of the three places states both behaviors. It is read as each place, and the wording is unchanged. It also listed the Scope, Coverage, and T1 references to old AC4, which the amendment fixed.
- 2026-09-22: T2 and T3 done. `check_part_logprobs()` and `logprobs_frame()` in `R/chat.R`, with tests of every rule and location in `tests/testthat/test-chat.R`. The new tests failed before the change. The old and new frame builders gave identical frames on the two recorded replies and on 500 random readable values. `devtools::test()` passed 3840. The suite unloaded the live gemma model, which became a candidate row.
- 2026-09-22: T4 done. The batch test in `tests/testthat/test-chat-batch.R` passes, and it fails with the base R error `$ operator is invalid for atomic vectors` on the `main` version of `R/chat.R`.
- 2026-09-22: T5 done. `helper-chat-bodies.R` pairs every native and OpenResponses unreadable shape with its detail sentence, and `test-chat.R` asserts that sentence and no other. A plant that swapped two detail sentences in `R/chat.R` gave 10 failures.
- 2026-09-22: T6 done. The conditions page, the `@return` text of `lms_chat_openresponses()`, and NEWS state the rules and the exact-name reads. The NEWS "before" claims were read off the `main` code on a `[5]` value and a `tokenX` field. `devtools::test()` passed 4398, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- claim audit: 38 claims read, 2 corrected — R/conditions.R, NEWS.md, tests/testthat/test-chat.R
- 2026-09-22: the claim audit found that a `null` step or candidate now aborts, which the docs had said passes. The conditions page and NEWS now say so, and the reader read the corrected text again and found no problem. After the fix, `devtools::test()` passed 4398, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. Status set to review.

## Decisions

## Review

Sync: 2026-09-22, the branch contains `origin/main` (d3fe11e), so no merge was needed. Run with a live LM Studio server and `RLMSTUDIO_API_TOKEN` set.

- AC1: `devtools::test()` passed the four new tests in `tests/testthat/test-chat.R`. They cover every rule at the first part, a later part, and a later message item. They cover a bad step first and after good steps, a bad `top_logprobs` entry, and a candidate after good candidates. They also cover the refusal part and `logprobs = FALSE`. Not ticked: review finding O1 gives an input on which the rule named is not the first one broken in walk order.
- AC2: the test "reads logprobs fields by their exact names" passed. It covers `tokenX`, `logprobX`, `top_logprobsX`, candidate `tokenX` and `logprobX`, and `null` and absent fields. The `chat_integration` replays passed unchanged. The diff reviewer found that the frame builder gives the same values and column types as the `main` builder.
- AC3: the batch test "a reply that breaks a logprobs rule fails only its own input" passed: the R2 condition in slot 2, replies in slots 1 and 3, and one warning.
- AC4: the native and OpenResponses unreadable-shape tests passed. Each shape asserts its own detail sentence and none of the other seven.
- AC5: read on the branch: `R/conditions.R` lines 76 to 95, the `@return` text of `lms_chat_openresponses()` in `R/chat.R` lines 142 to 151, and the two new `NEWS.md` bullets each state the rules, the first-rule message, the unchecked refusal part, `logprobs = FALSE`, and the exact-name reads.
- AC6: `devtools::test()` gave 4398 passed, 0 failed, 0 skipped. `devtools::check()` gave 0 errors, 0 warnings, 0 notes.

Consistency gate: `cairn_validate.py` passed (exit 0). `devtools::document()` left no diff. README.Rmd and README.md are untouched by the branch. No `_pkgdown.yml`. `NEWS.md` has entries for the change, with no milestone numbers. No new top-level files. No DESIGN principle changed, so `cairn_impact` was skipped.

Independent review (three fresh reviewers): the blame-history reviewer found no regression. The prior-review reviewer found no reintroduced fault, and GitHub holds no PR review comments. The diff reviewer reported 11 findings, ranked:

- O1: `check_part_logprobs()` tests R5 over all candidates of a step before any R6 check, but it checks steps and parts one at a time. A step whose first candidate has token `5` and whose second candidate is `5` reports R5. The same pattern over steps reports R3, and a test pins that. A probe on the branch gives this result.
- O2: no test covers a `null` step or a `null` candidate, which the conditions page and NEWS now describe. A probe shows both abort.
- O3: no test covers an explicit `"logprobs": null`, a `{}` value, a `{}` `top_logprobs`, or a `{}` step, which is readable.
- O4: the refusal-part test and the `logprobs = FALSE` loop also pass on `main`.
- O5: no test covers the order between a bad `text` and a bad `logprobs` on one part.
- O6: each unreadable shape breaks exactly one check, so the AC4 tests still pass after a swap of two adjacent checks.
- O7: if every logprob is a whole number, `step_logprob` is an integer column. This is the same as `main`.
- O8: the conditions page lists the rules without "absent, null, or". The sentence before the list says it.
- O9: the shared "Malformed response" section puts the logprobs rules on the help pages of `lms_embed()`, `lms_chat_native()`, `lms_chat_openai()`, and `lms_chat()`.
- O10: `is_object_array` is defined inside the step loop.
- O11: AC3 is tested with `format = "list"` only.
