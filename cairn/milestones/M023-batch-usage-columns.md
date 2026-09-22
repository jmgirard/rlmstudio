<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M023: A data-frame chat batch reports each reply's id and token counts on the OpenResponses and OpenAI routes

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — it changes the columns that an exported function returns
- **Branch/PR:** m023-batch-usage-columns

## Goal

On the OpenResponses and OpenAI routes, a data-frame `lms_chat_batch()` returns the id and three token counts of each reply as columns.

## Scope

**In:** Four new columns in the data-frame batch on both routes, for every setting of `logprobs` and `schema`. The `NA` rules for a bad field and a failed input. Shared reply readers for `lms_chat_openresponses()` and `lms_chat_openai()`. A classed error for a 200 body that is a bare JSON value, on all three routes. The help page of `lms_chat_batch()`. A NEWS entry.

**Out:**
- Timing columns on these two routes. The servers send no timings there, and the OpenAI `stats` object is empty.
- The `total_tokens` and `cached_tokens` fields. `simplify = FALSE` returns them in the body. No row holds them.
- Stateful chat stays on its candidate row.
- Stats on a single simplified call. M022 rejected them, because `simplify = FALSE` returns the body.

## Acceptance criteria

- [ ] AC1: With `api_type = "openresponses"` and `format = "data.frame"`, `lms_chat_batch()` returns its existing columns and then four new columns. In order, they are `response_id`, `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens`. Their cells hold the reply's `id` as character and three `usage` fields as double. The fields are `input_tokens`, `output_tokens`, and `output_tokens_details.reasoning_tokens`. A test mocks two replies with a different value in every field and asserts every cell with `expect_identical()`. It runs with `logprobs = FALSE` and with `logprobs = TRUE`, and it asserts the full column names each time.
- [ ] AC2: With `api_type = "openai"` and `format = "data.frame"`, `lms_chat_batch()` returns the same four columns in the same order after its existing ones. Their cells hold the reply's `id` as character and three `usage` fields as double. The fields are `prompt_tokens`, `completion_tokens`, and `completion_tokens_details.reasoning_tokens`. A test as in AC1 runs with no `schema`, with a `schema`, and with `logprobs = TRUE`. With a `schema`, `output` stays a list-column of parsed replies.
- [ ] AC3: A row whose answer is readable keeps that answer in `output`, and the call gives no warning about the new columns. A `response_id` cell keeps only a JSON string, the empty string included. A count cell keeps only a JSON number. Any other value gives `NA`: absent, `null`, a boolean, an array, an object, or the other scalar type. If `usage` is absent, `null`, an array, a string, a number, or `{}`, all three count cells are `NA`. The same shapes of the details object make only the reasoning cell `NA`. On each route, a test covers each of these shapes for every column, for `usage`, and for the details object. It asserts the `NA` cell, the kept `output`, and `expect_no_warning()`.
- [ ] AC4: The row of a failed input holds `NA` in all four columns. A failed input is one that raised `rlmstudio_api_error` or `rlmstudio_bad_response`. If every input failed, the four columns are still there, `response_id` as character and the counts as double. A test asserts this on each route with `logprobs = FALSE` and `logprobs = TRUE`, and on the OpenAI route with a `schema`. A lost server still aborts with `rlmstudio_no_server`. Its `results` field holds what it held before: answer strings, `lms_chat_result` objects with `logprobs = TRUE`, and parsed replies with a `schema`. A test asserts each of the three.
- [ ] AC5: The `output` and `logprobs` columns hold what the single call returns for the same body. A test covers a readable reply on each route and setting of AC1 and AC2. It compares each cell with the value that `lms_chat()` returns with `simplify = TRUE`. The unreadable shapes are those that `tests/testthat/helper-chat-bodies.R` builds in `responses_unreadable()`, `logprobs_breaks()`, and `openai_unreadable()`. A new list of `choices` faults joins them. For each shape, the batch row holds `NA` in `output` and the warning names its position. On the OpenAI `schema` route, the `output` cell holds a condition. Its class, message, `status`, `content`, and `finish_reason` equal those of the single call.
- [ ] AC6: A 200 chat body can be a bare JSON value, such as `5`, `"s"`, or `true`. With `simplify = TRUE`, `lms_chat_openresponses()`, `lms_chat_openai()`, and `lms_chat_native()` then raise `rlmstudio_bad_response`. The message says "The response body is not a JSON object.". With `simplify = FALSE`, they still return the body. A body of `null` keeps its present class and message. In `lms_chat_batch()`, such a body fails that input in every format, and the batch goes on. A test covers each of the four bodies on each route.
- [ ] AC7: The help page of `lms_chat_batch()` names the four columns and the source field of each on each route. It states the `NA` rules of AC3 and AC4. A search of `man/lms_chat_batch.Rd` finds each column name and each source field name. `NEWS.md` has an entry for the new columns and one for the bare-value fix. `devtools::test()` passes with no failures, `devtools::check()` gives 0 errors and 0 warnings, and `devtools::document()` makes no diff.

## Coverage

- AC1 → T1, T3
- AC2 → T1, T3
- AC3 → T1, T3
- AC4 → T1, T3
- AC5 → T2, T3, T4
- AC6 → T2, T4
- AC7 → T5, T6

## Tasks

- [x] T1: In `tests/testthat/helper-chat-bodies.R`, add builders for an OpenResponses body and an OpenAI body that hold `id` and `usage`. Write the tests for AC1 to AC4 in `tests/testthat/test-chat-batch.R`, and see them fail.
- [x] T2: In `R/chat.R`, move the `simplify = TRUE` branch of `lms_chat_openresponses()` (lines 191-215) into a shared reader. Do the same for `lms_chat_openai()` (lines 318-375). The single calls use these readers. Add one body check that all three routes run first, for AC6. Single calls keep every other result and message.
- [x] T3: In `lms_chat_batch()`, make the data-frame batch on both routes call with `simplify = FALSE`. Read the answer through the T2 readers, then read `id` and `usage` with `[[` (M018 lesson). Add the columns on the `schema` exit (line 1100) and on the main path. The `results` field of a lost-server abort keeps its present content.
- [x] T4: Add the list of `choices` faults and the bare-value bodies to the helper file. Write the tests for AC5 and AC6. Change the column-name expectations at `test-chat-batch.R:179`, `:207`, `:349`, and `:792-821` to the new columns, and pin the other columns by value.
- [x] T5: Write the roxygen of `lms_chat_batch()`, and replace the sentence "The other routes and formats add no such column". Run `devtools::document()`. Add the two NEWS entries.
- [x] T6: Run `devtools::test()`, `devtools::check()`, and `devtools::document()`.

## Work log

- 2026-09-22: created by /milestone-plan. It absorbs two candidate rows: the OpenResponses and OpenAI token counts, and the bare JSON scalar body (M022 review P8). The recorded replies in `tests/testthat/chat_integration` and `chat_cutoff_live` show the `id` and `usage` fields that AC1 and AC2 name.
- 2026-09-22: the criteria audit ran in full mode, with a fresh Opus reader. It returned 11 findings, and the plan took all of them. AC1 and AC2 now state cell values, not test existence. AC3 probes each JSON kind. AC4 covers the lost-server `results` field. AC5 names its shape lists and adds the `choices` faults. AC6 keeps `null` as a regression probe. AC7 no longer promises unedited tests, and T4 names the four test sites that change.
- 2026-09-22: plan gate chose the native column names over each server's own field names, because batches from different routes then stack. Falsified by users who need the server's names, or by counts that differ in meaning across routes.
- 2026-09-22: plan gate chose columns for every setting of `logprobs` and `schema` over plain-text batches only, so the columns depend on route and format alone. Falsified by a reply reader that cannot serve both the single call and the batch.
- 2026-09-22: plan gate folded in the bare-value fix over a separate hotfix, because the new body readers are where its check goes. Falsified by a review that finds the two changes hard to review together.
- 2026-09-22: T1 done. The builders are in `helper-chat-bodies.R`. The AC1 to AC4 tests are in a new file, `tests/testthat/test-chat-batch-usage.R`, not in `test-chat-batch.R` as T1 said, because that file holds 900 lines. Seven of the eight tests fail on the missing columns with no errors. The lost-server test passes, because it pins the present `results` field.
- 2026-09-22: T2 done. `responses_reply_value()` and `openai_reply_value()` hold the `simplify = TRUE` readers. `check_body_object()` runs first in `chat_message_items()` and in `openai_reply_value()`, and it passes `null` and top-level arrays. `devtools::test()` shows failures only in the new T1 tests, and 5033 expectations pass.
- 2026-09-22: T3 done. Every data-frame batch now reads the body through `read_reply()` in `lms_chat_batch()`, and `add_reply_columns()` adds the route's columns on both exits. The T1 tests pass. Four old tests in `test-chat-batch.R` fail only on the column names that T4 changes.
- 2026-09-22: T4 done. `openai_choices_faults()` and `bare_bodies` are in the helper file. The AC5 tests are in `test-chat-batch-usage.R`, and the AC6 tests are in a new `test-bare-body.R`. The four old tests now expect the usage columns. `devtools::test()` passes with 6232 expectations. A no-op `check_body_object()` made the AC6 tests error with the base R subscript error. Swapped OpenAI count fields failed 72 expectations in `test-chat-batch-usage.R`. Both plants were reverted.
- 2026-09-22: T5 done. The `lms_chat_batch()` help page maps each column to its field on each route. The shared "Malformed response" section names the bare-value case. `NEWS.md` has the two entries. A grep of `man/lms_chat_batch.Rd` finds all four column names and all six source field names.
- 2026-09-22: T6 done. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. `devtools::test()` gave 0 failures and 6232 passed expectations. `devtools::document()` made no diff.
- 2026-09-22: claim audit: 75 claims read, 2 corrected — NEWS.md
- 2026-09-22: status set to review. The two corrected NEWS sentences were an incomplete `NA` rule and an unqualified "return what they did before". The same reader re-read them, and both hold.

## Decisions

## Review
