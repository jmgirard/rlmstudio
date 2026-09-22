<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M022: A native chat batch reports each reply's stats and response id

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP4
- **Resolves:** —
- **Surface tier:** user-facing — it changes the columns that an exported function returns
- **Branch/PR:** m022-native-batch-stats

## Goal

With `api_type = "native"` and `format = "data.frame"`, `lms_chat_batch()` returns the `response_id` and the six `stats` fields of each reply as columns.

## Scope

**In:** Seven new columns in the native data-frame batch. The `NA` rules for a bad field and a failed input. The help pages of `lms_chat_batch()` and `lms_chat_native()`. A NEWS entry.

**Out:**
- The `usage` and `id` fields of the OpenResponses and OpenAI routes go to a new candidate row.
- Stateful chat stays on its candidate row. That row covers a named `previous_response_id` argument and help text about threads (GP4).
- Stats on a single simplified call were rejected at the plan gate. `simplify = FALSE` already returns them. See the work log.

## Acceptance criteria

- [ ] AC1: With `api_type = "native"` and `format = "data.frame"`, `lms_chat_batch()` returns its existing columns and then seven new columns. In order, they are `response_id`, `input_tokens`, `total_output_tokens`, `reasoning_output_tokens`, `tokens_per_second`, `time_to_first_token_seconds`, and `model_load_time_seconds`. The `response_id` cell is the top-level `response_id` of the reply, as character. Each stats cell is the field of the same name in the `stats` object of the reply, converted to double. The seven names are fixed. The row names match those of the same batch on the OpenAI route. A test with unique `inputs` names asserts this. A test in `tests/testthat/test-chat-batch.R` mocks two replies with a different value in every field. At least one stats field is a JSON integer, and one has a fraction. The test asserts every cell with `expect_identical()`. It runs with `logprobs = FALSE`, where the columns are `input`, `output`, and the seven. It also runs with `logprobs = TRUE`, where the columns are `input`, `output`, `logprobs`, and the seven. In that run, the test expects the native logprobs warning once per input and no other warning.
- [ ] AC2: A row whose answer text is readable keeps that answer in `output`. The call gives no warning about the new columns. A `response_id` cell keeps only a JSON string, the empty string included. A stats cell keeps only a JSON number. Any other value gives `NA`: absent, `null`, a boolean, an array, an object, or the other scalar type. If `stats` is absent, `null`, an array, a string, a number, or `{}`, all six stats cells are `NA`. A test with `logprobs = FALSE` covers each of these shapes for `response_id`, for at least two stats fields, and for `stats`. It asserts the `NA` cell, the kept `output`, and `expect_no_warning()`.
- [ ] AC3: The row of a failed input holds `NA` in all seven columns. A failed input is one that raised `rlmstudio_api_error` or `rlmstudio_bad_response`. A reply with no readable answer text fails as before, whatever its `stats` or `response_id` holds. If every input failed, the seven columns are still present, `response_id` as character and the six stats columns as double. A test asserts these facts for both failure classes, with `logprobs = FALSE` and with `logprobs = TRUE`. It includes an unreadable reply that holds a valid `stats` object and `response_id`, and it asserts `NA` in all seven columns and the failure warning.
- [ ] AC4: The other two routes get no new column. A test runs data-frame batches on the OpenResponses route and on the OpenAI route. It asserts the columns `input` and `output`. With `logprobs = TRUE`, it asserts `input`, `output`, and `logprobs`. It also runs an OpenAI batch with a `schema` and asserts the columns `input` and `output`.
- [ ] AC5: Single calls and the other native batch formats keep their return shape. `lms_chat_native()` and `lms_chat(api_type = "native")` with `simplify = TRUE` return one character string, and its `attributes()` is `NULL`. On a mocked body that holds `stats` and `response_id`, `lms_chat_native(simplify = FALSE)` returns the parsed body with both. A native batch with `format = "vector"` returns a character vector with no attribute other than `names`. With `format = "list"`, it returns a list whose elements are each one string with `attributes()` `NULL`. In a native data-frame batch, a lost server still aborts with `rlmstudio_no_server`. Its `results` field holds the answer strings so far. In a native list batch, a 400 reply stores an `rlmstudio_api_error`, and an unreadable reply stores an `rlmstudio_bad_response`. A test asserts each of these facts.
- [ ] AC6: The help page of `lms_chat_batch()` names the seven columns and the route and format that give them. It states the `NA` rules of AC2 and AC3. A search of `man/lms_chat_batch.Rd` finds each of the seven names. The help page of `lms_chat_native()` says that `simplify = FALSE` returns the body with its `stats` and `response_id`. `NEWS.md` has an entry for the new columns.
- [ ] AC7: `devtools::test()` passes with no failures. `devtools::check()` gives 0 errors and 0 warnings. `devtools::document()` makes no diff.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T3, T4
- AC5 → T3, T4
- AC6 → T5
- AC7 → T6

## Tasks

- [x] T1: Send one `/api/v1/chat` request to the local LM Studio. Write the names and JSON types of the `stats` fields and the form of `response_id` in the work log. If a field is present under a name that differs from the six in AC1, stop and amend the plan through the gate. An absent field does not count, because AC2 gives it `NA`.
- [x] T2: In `tests/testthat/helper-chat-bodies.R`, add a builder for a native reply with a `stats` object and a `response_id`. Write the tests for AC1, AC2, and AC3 in `tests/testthat/test-chat-batch.R`, and see them fail.
- [ ] T3: In `R/chat.R`, change the native data-frame path of `lms_chat_batch()` so that it reads `response_id` and `stats` from each reply body. Read the answer text through the helpers that `lms_chat_native()` uses, so that a failure keeps its class. A reply that is not 200 still goes through `rlm_abort_api()`. The native logprobs warning stays. Single calls do not change. Read the fields with `[[` (M018 lesson).
- [ ] T4: Write the tests for AC4 and AC5.
- [ ] T5: Write the roxygen for `lms_chat_batch()` and `lms_chat_native()`. Run `devtools::document()`. Add the NEWS entry.
- [ ] T6: Run `devtools::test()`, `devtools::check()`, and `devtools::document()`.

## Work log

- 2026-09-22: created by /milestone-plan. It absorbs the `stats` candidate row. The stateful-chat row stays, with its wording corrected.
- 2026-09-22: the criteria audit ran in full mode, with a fresh Opus reader. It returned 10 findings and 1 suggestion, and the plan took all of them. The GP4 finding removed a help-page promise about `previous_response_id` in `...`. A second pass returned 4 findings and 1 wording point, and the plan took all of them. The findings were row names, an absent live field in T1, a lost server, and an unreadable reply with valid stats.
- 2026-09-22: plan gate chose batch data-frame columns over attributes on the string and over a new result object. `simplify = FALSE` already gives single calls both values, and attributes print under every answer. Falsified by users who ask for stats on single simplified calls.
- 2026-09-22: plan gate chose seven flat columns over one `stats` list-column, because flat columns compute directly. Falsified by a new server stats field that users need.
- 2026-09-22: plan gate chose an `NA` cell with no warning over failing the input. Stats are extra data. With a failed input, a change to the stats block fails every input. Falsified by a user who needs to know that stats went missing.
- 2026-09-22: plan gate kept the OpenResponses `usage` and `id` fields out, because their names and fields differ. Falsified by a need for one column set across routes.
- 2026-09-22: implement started on branch `m022-native-batch-stats`. The plan left no choice open, so no question gate ran.
- 2026-09-22: T1 live probe with google/gemma-3-1b. `stats` held `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens` as JSON integers, and `tokens_per_second` and `time_to_first_token_seconds` as numbers with fractions. `model_load_time_seconds` was absent. `response_id` was a string like `resp_<hex>`. A second call with `previous_response_id` answered with the name from the first turn. No name differs from AC1.
- 2026-09-22: T2 added `native_reply()` and `native_stats()` to the body helpers, and `tests/testthat/test-chat-batch-stats.R` for AC1 to AC3. The tests fail because the columns are missing.

## Decisions

## Review
