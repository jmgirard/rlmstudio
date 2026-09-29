# M051: A schema data-frame batch returns one column per schema property

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2
- **Resolves:** —
- **Surface tier:** user-facing — it changes the data frame that the exported `lms_chat_batch()` returns
- **Branch/PR:** m051-batch-schema-columns

## Goal

With an object `schema` and `format = "data.frame"`, `lms_chat_batch()` returns one typed column per top-level schema property after the reply columns.

## Scope

**In:** The column, type, `NA`, and `NULL` rules of AC1 to AC4. They apply on the `api_type = "openai"` data-frame route with `logprobs = FALSE`. The abort for a bad or clashing property name. The help page, NEWS, and D-027.

**Out:** The properties of a nested object get no columns of their own. A user request for them adds a candidate row. Structured output on the other two routes stays with its candidate row. The vector format keeps its fallback to a list, for the reason in the `lms_chat_batch()` code comment. The list format and single calls do not change.

## Acceptance criteria

- [ ] AC1: The batch that AC1 covers has `api_type = "openai"`, `format = "data.frame"`, `logprobs = FALSE`, and an object `schema`. An object `schema` has a `type` of `"object"`, written as a string or as a list that holds that one string. Its `properties` is a list of one or more entries with a names attribute. Such a batch returns one column per property after the four reply columns. Each column has the property name, in the order of `properties`. `input`, `output`, and the four reply columns keep their positions, names, types, and values. Tests assert `names()` for a one-property schema. They also assert `names()` for a three-property schema whose properties are not in alphabetical order and whose reply fields come in another order. They assert `identical()` on `input`, `output`, and the four reply columns against their expected values. The `names()` test near line 135 of `tests/testthat/test-chat-batch-usage.R` expects the new `score` column.
- [ ] AC2: A property column's type follows the property's `type`. `"string"` gives character, `"integer"` gives integer, `"number"` gives double, and `"boolean"` gives logical. Each type can be a string or a list that holds that one string. A `type` of one of these four types and `"null"` gives the same column type. That pair can come in either order, as a character vector or as a list. Any other `type`, no `type`, or a property that is not a list gives a list-column. A nested object gives a list-column too, and its own properties get no columns. Tests assert the column type for each of the four types, as a string and as a one-string list. They assert it for each type paired with `"null"`, in both orders and both forms. They assert it for `"object"`, for `"array"`, for no `type`, and for a property that is not a list.
- [ ] AC3: This criterion covers the character, integer, double, and logical property columns. If the field's parsed value is one value of the column type, the cell holds that value. Otherwise the cell holds `NA`, the call gives no warning, and the row's `output` element keeps the parsed reply. One value means a length-one atomic vector after `jsonlite::parse_json(simplifyVector = TRUE)`. A one-item JSON array therefore counts as one value. A character cell takes a string, and an empty string is kept. A logical cell takes a logical, and a double cell takes any number. An integer cell takes an integer, or a whole double from -2147483647 to 2147483647. So `3.0` gives `3L`, and `3.5`, `2147483648`, and `-2147483648` give `NA`. For each column type, tests cover an absent field and a `null` field. They cover a field of another type as a scalar, as an array of two items, and as an object. They also cover `["x"]` giving `"x"`, an empty string, `3.0`, `3.5`, both integer range edges, and both values just outside them. Each test asserts that no warning is given.
- [ ] AC4: In a list property column, a cell holds the field's parsed value. If the field is absent or `null`, the cell holds `NULL`. A reply that is not a JSON object gives `NA` in every atomic property cell of its row and `NULL` in every list property cell. Examples are an array of one object, a number, and `null`. The row of a failed input holds the same values. If every input failed, each property column is still there with the type that AC2 gives it. This holds in a batch of one input and in a batch of three. Tests cover each case that this criterion names.
- [ ] AC5: The batches below return the columns that they returned before this milestone, and tests assert those columns. A data-frame batch returns `input`, `output`, `response_id`, `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens` for six schemas. They are the empty list, a `type` of `"array"`, a `type` of `c("object", "null")`, no `properties`, an empty `properties`, and a `properties` list with no names attribute. A data-frame batch with `logprobs = TRUE` and an object `schema` returns `input`, `output`, `logprobs`, and then the four reply columns. With an object `schema`, the list format returns one parsed reply per input. The vector format still warns and returns that list.
- [ ] AC6: In a batch that AC1 covers, a bad property name aborts before the server probe and before any request. A bad name is empty, is `NA`, repeats, or equals a column name. The column names are `input`, `output`, `response_id`, `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens`. The message names the property or the fault. The list and vector formats with the same schema do not abort. Tests cover each listed column name, an empty name, an `NA` name, and a repeated name. Each test asserts the message. It also asserts that the mocked server probe was not called and that no request was recorded.
- [ ] AC7: The `lms_chat_batch()` help page and `NEWS.md` state the column rule, the type rule, the `NA` and `NULL` rule, and the abort of AC6. The help page no longer says that the reply columns end the data frame on every route. `devtools::document()` gives no diff. `devtools::test()` and `devtools::check()` are clean.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T1, T2
- AC5 → T5
- AC6 → T4
- AC7 → T6

## Tasks

- [x] T1: Give `batch_with_reply()` and `batch_with_sequence()` a `schema` argument and an input count. They are in `tests/testthat/test-chat-schema.R` near lines 481 and 554. The defaults are `score_schema` and today's inputs. Write the AC1 to AC4 tests there first, and see them fail.
- [x] T2: In `R/chat.R`, add a helper that reads the column names and types from the schema by the AC1 and AC2 rules. Add a second helper that reads one cell by the AC3 and AC4 rules. A reply that is a named list and not a data frame counts as a JSON object. Read fields with `[[`, never with `$`. Add the columns after `add_reply_columns()` in the data-frame branch, near line 1740.
- [x] T3: Update the `names()` assertion near line 135 of `tests/testthat/test-chat-batch-usage.R`. `score_schema` now adds a `score` column there. Update the two other `names()` assertions in that file too. In `tests/testthat/test-chat-batch.R`, update the schema case of "the other routes add the usage columns and no stats column".
- [x] T4: Add the AC6 name check to the argument checks of `lms_chat_batch()`. It goes after `format` is matched and before `stop_if_no_server()`, near line 1504. Test it in the pattern of `tests/testthat/test-arg-guards.R`, which follows D-008.
- [x] T5: Write the AC5 tests in `tests/testthat/test-chat-schema.R`.
- [ ] T6: Rewrite the `@return` passages of `lms_chat_batch()` that say that the reply columns follow `output` and end the frame. They are near lines 1363 and 1395. Add a NEWS entry that names the new columns and the abort on a property named `output`, under the D-001 waiver. Tie each added claim to a test from T1 to T5. Start the server and set `RLMSTUDIO_API_TOKEN`. Then run `devtools::document()`, `devtools::test()`, and `devtools::check()`.

## Work log

- 2026-09-28: created by /milestone-plan. Absorbs the candidate row "Bind parsed batch replies into data-frame columns".
- 2026-09-28: criteria audit, full mode, by a fresh Opus reader. The first pass gave 24 findings on 7 criteria. Their fixes went into the criteria. The gate changed AC1, and the re-audit gave 5 findings. Those fixes went in too. Both passes asked for D-027.
- 2026-09-28: plan gate kept the `output` list-column rather than replacing it with the property columns. It holds the conditions of failed inputs and values that do not fit a column. Falsified by users who find the extra column in the way.
- 2026-09-28: plan gate put the property columns at the end rather than after `output`, so no existing column moves. Falsified by users who need the fields next to `output`.
- 2026-09-28: plan gate chose an abort on a bad or clashing property name over a prefix on every column or a skipped column. A prefix lengthens every name, and a skipped column gives no sign. Falsified by a user whose schema needs a clashing name in a data frame.
- 2026-09-28: plan chose columns from the schema over columns from the reply fields, so the shape does not depend on the model's answers. Falsified by users whose schemas do not list their properties.
- 2026-09-28: plan chose an integer column for `"integer"` over a double column, because the schema states whole numbers. Falsified by real replies whose integer fields fall outside the integer range.
- 2026-09-28: implement started on branch m051-batch-schema-columns. No question gate, because the plan left no choice open.
- 2026-09-28: T1 and T2 done. The helpers take `schema` and `inputs`, the AC1 to AC4 tests failed first, and `schema_property_columns()` and `schema_property_cell()` make them pass.
- 2026-09-28: minor amendment to T3. Two more `names()` assertions in `test-chat-batch-usage.R` and one in `test-chat-batch.R` also expect the `score` column. T3 done, and `devtools::test()` is clean.
- 2026-09-28: T4 done. `rlm_check_property_names()` runs before `stop_if_no_server()`. The test went red with the check replaced by a no-op, and `devtools::test()` is clean.
- 2026-09-28: T5 done. The six-schema test went red with a planted check that reads `c("object", "null")` as an object type, and `devtools::test()` is clean.

## Decisions

## Review
