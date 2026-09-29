# M051: A schema data-frame batch returns one column per schema property

- **Status:** review
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

- [x] AC1: The batch that AC1 covers has `api_type = "openai"`, `format = "data.frame"`, `logprobs = FALSE`, and an object `schema`. An object `schema` has a `type` of `"object"`, written as a string or as a list that holds that one string. Its `properties` is a list of one or more entries with a names attribute. Such a batch returns one column per property after the four reply columns. Each column has the property name, in the order of `properties`. `input`, `output`, and the four reply columns keep their positions, names, types, and values. Tests assert `names()` for a one-property schema. They also assert `names()` for a three-property schema whose properties are not in alphabetical order and whose reply fields come in another order. They assert `identical()` on `input`, `output`, and the four reply columns against their expected values. The `names()` test near line 135 of `tests/testthat/test-chat-batch-usage.R` expects the new `score` column.
- [x] AC2: A property column's type follows the property's `type`. `"string"` gives character, `"integer"` gives integer, `"number"` gives double, and `"boolean"` gives logical. Each type can be a string or a list that holds that one string. A `type` of one of these four types and `"null"` gives the same column type. That pair can come in either order, as a character vector or as a list. Any other `type`, no `type`, or a property that is not a list gives a list-column. A nested object gives a list-column too, and its own properties get no columns. Tests assert the column type for each of the four types, as a string and as a one-string list. They assert it for each type paired with `"null"`, in both orders and both forms. They assert it for `"object"`, for `"array"`, for no `type`, and for a property that is not a list.
- [x] AC3: This criterion covers the character, integer, double, and logical property columns. If the field's parsed value is one value of the column type, the cell holds that value. Otherwise the cell holds `NA`, the call gives no warning, and the row's `output` element keeps the parsed reply. One value means a length-one atomic vector after `jsonlite::parse_json(simplifyVector = TRUE)`. A one-item JSON array therefore counts as one value. A character cell takes a string, and an empty string is kept. A logical cell takes a logical, and a double cell takes any number. An integer cell takes an integer, or a whole double from -2147483647 to 2147483647. So `3.0` gives `3L`, and `3.5`, `2147483648`, and `-2147483648` give `NA`. For each column type, tests cover an absent field and a `null` field. They cover a field of another type as a scalar, as an array of two items, and as an object. They also cover `["x"]` giving `"x"`, an empty string, `3.0`, `3.5`, both integer range edges, and both values just outside them. Each test asserts that no warning is given.
- [x] AC4: In a list property column, a cell holds the field's parsed value. If the field is absent or `null`, the cell holds `NULL`. A reply that is not a JSON object gives `NA` in every atomic property cell of its row and `NULL` in every list property cell. Examples are an array of one object, a number, and `null`. The row of a failed input holds the same values. If every input failed, each property column is still there with the type that AC2 gives it. This holds in a batch of one input and in a batch of three. Tests cover each case that this criterion names.
- [x] AC5: The batches below return the columns that they returned before this milestone, and tests assert those columns. A data-frame batch returns `input`, `output`, `response_id`, `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens` for six schemas. They are the empty list, a `type` of `"array"`, a `type` of `c("object", "null")`, no `properties`, an empty `properties`, and a `properties` list with no names attribute. A data-frame batch with `logprobs = TRUE` and an object `schema` returns `input`, `output`, `logprobs`, and then the four reply columns. With an object `schema`, the list format returns one parsed reply per input. The vector format still warns and returns that list.
- [x] AC6: In a batch that AC1 covers, a bad property name aborts before the server probe and before any request. A bad name is empty, is `NA`, repeats, or equals a column name. The column names are `input`, `output`, `response_id`, `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens`. The message names the property or the fault. The list and vector formats with the same schema do not abort. Tests cover each listed column name, an empty name, an `NA` name, and a repeated name. Each test asserts the message. It also asserts that the mocked server probe was not called and that no request was recorded.
- [x] AC7: The `lms_chat_batch()` help page and `NEWS.md` state the column rule, the type rule, the `NA` and `NULL` rule, and the abort of AC6. The help page no longer says that the reply columns end the data frame on every route. `devtools::document()` gives no diff. `devtools::test()` and `devtools::check()` are clean.

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
- [x] T6: Rewrite the `@return` passages of `lms_chat_batch()` that say that the reply columns follow `output` and end the frame. They are near lines 1363 and 1395. Add a NEWS entry that names the new columns and the abort on a property named `output`, under the D-001 waiver. Tie each added claim to a test from T1 to T5. Start the server and set `RLMSTUDIO_API_TOKEN`. Then run `devtools::document()`, `devtools::test()`, and `devtools::check()`.

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
- 2026-09-28: T6 done. The help page and NEWS state the column, type, `NA` and `NULL`, and abort rules. Each claim maps to a T1, T4, or T5 test in `test-chat-schema.R` or `test-arg-guards.R`. With the server running and the token set, `devtools::document()`, `devtools::test()` (no skips), and `devtools::check()` (0 errors, 0 warnings, 0 notes) are clean.
- 2026-09-28: claim audit: 41 claims read, 1 corrected — R/chat.R, man/lms_chat_batch.Rd, NEWS.md, R/utils-args.R, tests/testthat/test-arg-guards.R, test-chat-batch.R, test-chat-batch-usage.R, test-chat-schema.R. The corrected claim says that a data frame with `logprobs = TRUE` also skips the name check. A new test case covers it, and the reader's re-read found that it holds.
- 2026-09-28: `devtools::test()` and `devtools::check()` (0 errors, 0 warnings, 0 notes) are clean after the fix. Status set to review.
- 2026-09-28: review: 7 of 7 criteria verified, gate clean, 3 reviewers. Fix-now O5 and S1 in `NEWS.md`.
- 2026-09-28: step-7 approval: m051-batch-schema-columns approved for merge

## Decisions

## Review

Run 2026-09-28 on branch head 066311e, which contains `origin/main` (no merge needed). The LM Studio server ran and `RLMSTUDIO_API_TOKEN` was set. `devtools::test()`: 13756 passed, 0 skipped, 1 failed. The failure is `test-server-ready.R:170` ("each token source reaches the Authorization header", the option case). The branch does not touch that file, and 3 reruns of it passed 39 of 39. `devtools::check()`: 0 errors, 0 warnings, 0 notes.

- AC1: `test-chat-schema.R` "a schema data frame adds one column per property after the reply columns" asserts `names()` for the one-property `score_schema`. It also asserts `names()` for `zeta`, `alpha`, `mid` with reply fields in other orders. It asserts `identical()` on `input`, `output`, and the four reply columns. "a schema type written as a one-string list adds the columns too" covers `type = list("object")`. `test-chat-batch-usage.R` expects `score` in its `names()` tests. All pass.
- AC2: `test-chat-schema.R` "a property column's type follows the property type" asserts `typeof()` and the values for the four types. Each type comes as a string, a one-string list, and a pair with `"null"` in both orders and both forms. It asserts a list-column for a nested object, `"array"`, a two-type union, no `type`, and a property that is not a list. It also asserts that the nested property `inner` gets no column. It passes.
- AC3: `test-chat-schema.R` "a property cell holds one value of its column type, and NA otherwise" runs each column type. The cases are an absent field, `null`, another type as a scalar, as a two-item array, and as an object. They include `["x"]`, `""`, `3.0`, `3.5`, both integer range edges, and both values outside them. It asserts each cell and zero warnings. It asserts that `output` keeps the parsed reply, also once against a literal `list(v = 3.5)`. It passes.
- AC4: In `test-chat-schema.R`, the list-cell test covers a present, absent, and `null` list field. It also covers a failed input and three replies that are not objects: an array of one object, a number, and `null`. It asserts the `NA` and `NULL` cells of those rows. The all-failed test asserts the names and the typed `NA` or `NULL` columns. It runs a batch of one input and a batch of three. Both tests pass.
- AC5: In `test-chat-schema.R`, the non-object test asserts the six reply-and-input columns for the six named schemas. The logprobs test asserts `input`, `output`, `logprobs`, and the four reply columns. It also asserts one parsed reply per input from the list format, and the warning and the same list from the vector format. Both tests pass.
- AC6: The name-check test in `test-arg-guards.R` covers each of the six column names. It also covers an empty name, an `NA` name, and a repeated name. It asserts each message text and that the error has no `rlmstudio_` class. It asserts zero probe calls and zero recorded requests. The same schemas in the list and vector formats send their requests and return the parsed replies. It passes.
- AC7: The help page and `NEWS.md` state the column, type, `NA` and `NULL`, and abort rules (read in the diff). The help page now says that the four reply columns follow `output` or `logprobs`, and that the property columns come after them. `devtools::document()` left `git status` clean. A second full `devtools::test()` gave 13749 passed, 0 failed, and 3 live skips in `test-embed.R` and `test-list-instances.R`, files the branch does not touch. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and its test run passed.

Consistency gate: `cairn_validate.py` exited 0. `devtools::document()` gave no diff. README is not touched, and there is no pkgdown site. `NEWS.md` has an entry. The branch adds no top-level file. No DESIGN principle changed, so `cairn_impact.py` did not run. `devtools::check()` is clean.

Independent review: three fresh reviewers, [O] diff-bug, [S] blame-history, and [S] prior-review. Findings, with the dispositions proposed at the merge gate:

- O1: A property named `logprobs` is not a reserved name. With `logprobs = FALSE`, it gives a `logprobs` column that holds the model field, the same name as the list-column of a `logprobs = TRUE` frame. AC6 lists six names, so it is not a contract break. Proposed: follow-up candidate row.
- O2: `logprobs = 1` counts as no logprobs, because `isTRUE()` reads it. The name check and the columns then apply. `openai_reply_value()` reads it the same way, and the server checks the field. Proposed: reject, the handling is older than this branch.
- O3: A nullable property written as `anyOf` or `oneOf`, or an `enum` with no `type`, gives a list-column. That matches AC2, but schema generators often write nullables that way. Proposed: follow-up candidate row.
- O4: A `type` of `"Object"` adds no columns and no message. Proposed: reject, JSON Schema names are case-sensitive.
- O5: The first `NEWS.md` bullet does not name `api_type = "openai"`. Proposed: fix now.
- O6: The abort names only the first bad name. Proposed: reject, AC6 is met and the D-008 checks each report one fault.
- O7 and S10: `is_json_object()` is defined twice with the same body, in `R/list.R` and `R/embed.R`. Proposed: reject, older than this branch.
- S1: The older `NEWS.md` entry for the OpenResponses and OpenAI reply columns says that they come "at the end of the data frame". With an object schema, that is now false. Proposed: fix now.
- S2: D-014 has no pointer to D-027. Proposed: reject, DECISIONS is append-only and the D-027 heading names D-014.
- S3 to S9: no consequence found. They cover the check order, the skipped formats, the silent `NA`, the test updates, the helper defaults, the failed-input cells, and the reserved-name list. Proposed: noted.
- P1: The prior-review lens found no regression of an earlier review. It noted that a name made only of spaces passes the check. Proposed: noted.
- R1: The first `devtools::test()` run failed once at `test-server-ready.R:170`, a file the branch does not touch. Three reruns of the file and a second full run passed. Proposed: follow-up candidate row.

Gate triage, 2026-09-28: the maintainer accepted every proposed disposition. O5 and S1 are fixed in `NEWS.md`. O1, O3, and R1 become candidate rows at the hygiene pass.
