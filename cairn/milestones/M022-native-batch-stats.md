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

- AC1 → T1, T2, T3, T7
- AC2 → T2, T3, T7
- AC3 → T2, T3, T7
- AC4 → T3, T4, T7
- AC5 → T3, T4
- AC6 → T5, T8
- AC7 → T6

## Tasks

- [x] T1: Send one `/api/v1/chat` request to the local LM Studio. Write the names and JSON types of the `stats` fields and the form of `response_id` in the work log. If a field is present under a name that differs from the six in AC1, stop and amend the plan through the gate. An absent field does not count, because AC2 gives it `NA`.
- [x] T2: In `tests/testthat/helper-chat-bodies.R`, add a builder for a native reply with a `stats` object and a `response_id`. Write the tests for AC1, AC2, and AC3 in `tests/testthat/test-chat-batch.R`, and see them fail.
- [x] T3: In `R/chat.R`, change the native data-frame path of `lms_chat_batch()` so that it reads `response_id` and `stats` from each reply body. Read the answer text through the helpers that `lms_chat_native()` uses, so that a failure keeps its class. A reply that is not 200 still goes through `rlm_abort_api()`. The native logprobs warning stays. Single calls do not change. Read the fields with `[[` (M018 lesson).
- [x] T4: Write the tests for AC4 and AC5.
- [x] T5: Write the roxygen for `lms_chat_batch()` and `lms_chat_native()`. Run `devtools::document()`. Add the NEWS entry.
- [x] T6: Run `devtools::test()`, `devtools::check()`, and `devtools::document()`.
- [x] T7: Move the tests of `tests/testthat/test-chat-batch-stats.R` into `tests/testthat/test-chat-batch.R`, and delete the file. Assert no warning in the AC2 tests with `expect_no_warning()`. Use `["resp_x"]` and `{"a": "resp_x"}` for the `response_id` array and object cases. On the other routes, assert `output` and no warning. If every input failed, assert the full column order.
- [x] T8: Add four rules to the `lms_chat_batch()` help page. A `stats` value that is not an object gives `NA` in all six cells. A reply with no readable answer text fails, whatever its fields hold. An empty `response_id` is kept. If every input failed, the columns stay. Read `response_id` with `[[` in the batch. Wrap the roxygen lines over 80 characters. Run `devtools::test()`, `devtools::check()`, and `devtools::document()`.

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
- 2026-09-22: T3 added `native_reply_text()` and `native_reply_fields()` to `R/chat.R`. The native data-frame batch calls `lms_chat(simplify = FALSE)` and reads the text with the helper that `lms_chat_native()` now uses. `devtools::test()` gave 311 tests, 0 failed. A planted defect that read the stats before the text turned 2 tests red. A second plant, which removed `as.double()`, stayed green, because `vapply(..., double(1))` already converts an integer.
- 2026-09-22: T4 added the AC4 and AC5 tests to `tests/testthat/test-chat-batch-stats.R`. They build their bodies from the shared helpers, because `openai_ok()` and `openresponses_ok()` are local to `test-chat-batch.R`. The file passes.
- 2026-09-22: T5 documented the seven columns on the `lms_chat_batch()` page and the body fields on the `lms_chat_native()` page, and added the NEWS entry. A grep of `man/lms_chat_batch.Rd` finds each of the seven names. The help text names `model_load_time_seconds` as a field the server can leave out, as T1 observed.
- 2026-09-22: T6 `devtools::test()` gave 316 tests, 0 failed, 0 skipped. `devtools::check()` gave 0 errors, 0 warnings, 0 notes. `devtools::document()` made no diff.
- 2026-09-22: claim audit: 46 claims read, 2 corrected — R/chat.R. The `lms_chat_native()` return text no longer says that the body always holds `response_id` and `stats`. A batch code comment now names the route and setting it holds for. The re-read found both accurate and refined the comment once more.
- 2026-09-22: review return 1 (defect). Three criteria fail as written. AC1 names `tests/testthat/test-chat-batch.R`, but the tests are in `test-chat-batch-stats.R`. AC2 names `expect_no_warning()`, but the tests compare `capture_warnings()` to `character()`. The `lms_chat_batch()` help page leaves out two NA rules that AC6 asks for. AC3, AC4, AC5, and AC7 passed. The Review section lists all 13 reviewer findings.
- 2026-09-22: implement resumed after review return 1. At the question gate, the user chose to move the tests into `test-chat-batch.R` over an AC1 amendment. The user also chose to fix findings O2, O3, O4, O6, O9, and O11 in this pass. The minor amendment added T7 and T8 and mapped them in Coverage.
- 2026-09-22: T7 moved the 12 stats tests into `tests/testthat/test-chat-batch.R` and deleted `test-chat-batch-stats.R`. The file gave 30 tests, 0 failed. A plant that unwrapped `response_id` turned 2 checks red. A planted warning in `native_reply_fields()` turned 28 checks red, which includes the `expect_no_warning()` checks.
- 2026-09-22: T8 added the four rules to the `lms_chat_batch()` help page, read `response_id` with `[[`, and wrapped two long roxygen lines. `devtools::test()` gave 316 tests, 0 failed, 0 skipped. `devtools::check()` gave 0 errors, 0 warnings, 0 notes. `devtools::document()` made no further diff.

## Decisions

## Review

Review pass 1, 2026-09-22. The branch holds `origin/main`, so no merge was needed. The pass ended in a return, so no box is ticked. The re-review gathers fresh evidence for all seven criteria.

- AC1: FAIL as written. The tests in `tests/testthat/test-chat-batch-stats.R` pass, 12 tests with 0 failed. They cover each clause: the column order for both `logprobs` settings, `expect_identical()` on every cell, and the row names against the OpenAI route. The criterion names `tests/testthat/test-chat-batch.R`, and the branch leaves that file unchanged.
- AC2: FAIL as written. The tests cover each shape for `response_id`, `input_tokens`, `tokens_per_second`, and `stats`, and they assert the `NA` cell and the kept `output`. They assert no warning with `expect_identical(res$warnings, character())` (lines 139 and 170). The criterion names `expect_no_warning()`. A probe showed that the code gives `NA` for `["resp_x"]` and `[7]`.
- AC3: PASS. The test "a failed input holds NA in every reply column" covers both classes with both `logprobs` settings. It includes an unreadable reply with valid `stats` and `response_id`, and asserts `NA` in all seven columns and one failure warning at position 2. The test "the reply columns are there when every input failed" asserts the column types.
- AC4: PASS. The test "the other routes add no reply column to a data frame" asserts `input` and `output` on OpenResponses and OpenAI, plus `logprobs` with `logprobs = TRUE`, and `input` and `output` for an OpenAI `schema` batch.
- AC5: PASS. Four tests cover it. The single native and `lms_chat()` calls return a string with `NULL` attributes. With `simplify = FALSE`, the call returns the body with `response_id` and `stats`. Vector and list batches hold plain strings. A list batch stores `rlmstudio_api_error` (status 400) and `rlmstudio_bad_response`. A lost server aborts with `rlmstudio_no_server`, and `results` is `list("x", NULL, NULL)`.
- AC6: FAIL as written. A grep of `man/lms_chat_batch.Rd` finds each of the seven names. `NEWS.md` has the entry, and the `lms_chat_native()` page names the body fields. The `lms_chat_batch()` page leaves out two NA rules: a `stats` value that is not an object gives `NA` in all six cells (AC2), and a reply with no readable answer text fails whatever its fields hold (AC3).
- AC7: PASS. `devtools::test()` gave 316 tests, 4800 expectations, 0 failed, 0 skipped. `devtools::check()` gave 0 errors, 0 warnings, 0 notes. `devtools::document()` made no diff.
- Consistency gate: `cairn_validate.py` exit 0. No DESIGN principle changed. No pkgdown site. The README files are untouched. The NEWS entry names no milestone. No new top-level file.

Reviewer findings, ranked by each reviewer, all logged. These return with the milestone for triage at the next gate.

- O1 (diff-bug): AC1 fails as written. The tests are in `test-chat-batch-stats.R`, not `test-chat-batch.R`. Recorded above.
- O2: The `response_id` array and object cases hold a number (`[5]`, `{"a": 1}`), so a mutation to `is_one_string(unlist(id))` at `R/chat.R:841` stays green. Use `["resp_x"]` and `{"a": "resp_x"}`.
- O3: AC6 is partly met. The help page leaves out the NA rules of AC2 and AC3 listed above. It also does not say that the columns stay when every input failed, or that an empty `response_id` is kept.
- O4: The AC4 tests assert only column names, and `run_stats_batch()` swallows warnings, so a regression that failed every input on those routes stays green.
- O5: `capture_warnings()` in place of the `expect_no_warning()` that AC2 names. Recorded above.
- O6: The every-input-failed test checks column presence with `%in%`, not the order.
- O7: No DECISIONS entry records the change to the native data-frame shape, which D-011 treated as a reason against an `error` column, or the choice of a silent `NA`.
- O8: The `lms_chat_native()` page says the body "can hold" `stats` and `response_id`. AC6 says it returns the body "with" them.
- O9: `x$response_id` at `R/chat.R:1127` reads a package-built list with `$`. The stats loop two lines later uses `[[`, as the M018 lesson and T3 ask.
- O10: `body` and `text` are assigned inside the `tryCatch` expression and persist in the function frame. Each input overwrites them before use, so they cause no fault today.
- O11: `R/chat.R:822-823` and `R/chat.R:879` exceed 80 characters.
- S1 (blame-history): no conflict with past milestones, D-007, D-010, D-011, or D-012.
- S2 (prior-review): the same `$` read as O9, rated low severity because the list names cannot collide. The probe for GitHub review comments found none.
