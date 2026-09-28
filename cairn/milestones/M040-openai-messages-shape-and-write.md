# M040: The OpenAI chat function refuses a messages value that jsonlite cannot write or that breaks a shape rule

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Surface tier:** user-facing — it changes which `messages` values an exported function accepts
- **Branch/PR:** m040-openai-messages-shape-and-write

## Goal

`lms_chat_openai()` refuses, before the server probe, a `messages` value
that jsonlite cannot write or that breaks one of the shape rules below.

## Scope

**In:** Four checks in `rlm_check_messages()` and its helpers in
`R/utils-args.R:328-460`. They run after the M038 and M039 rules and before
`stop_if_no_server()` in `lms_chat_openai()` (`R/chat.R:380`). The empty-row
rule of a data frame treats a `NULL` list cell as empty. A list with a `dim`
attribute is refused as `messages` and as a message. A walk refuses bad names
at the message level and below. A trial write with jsonlite catches a value
that jsonlite cannot write. The help at `messages` and NEWS state the rules.

**Out:** A `list()` or `list(NA)` cell in a data-frame row passes, because it
writes a field value (`[]` or `[null]`), and field values stay with the
server. A value that jsonlite writes with no error but in an odd form, such
as a function written as its source text, passes. A new candidate row holds
it. A `dim` attribute on a list below the message level passes. The other
chat functions take no `messages` argument.

## Acceptance criteria

- [ ] AC1: A data-frame `messages` value with a row in which each cell is
  `NA` or is a list-column cell that is `NULL` aborts before the server
  probe. The abort gives the empty-row detail text. A row with a `list()` or
  a `list(NA)` cell and `NA` in every other cell reaches the request. Tests in
  `tests/testthat/test-arg-guards.R` fire the abort for a plain list column
  and for an `I()` list column, and send the two passing rows.
- [ ] AC2: A `messages` list that is not a data frame and has a `dim`
  attribute aborts before the server probe. A list message with a `dim`
  attribute also aborts there. Each abort has its own detail text. Each
  `dim` rule runs before the names rule at its level. Tests fire the first
  for a list-matrix and for a one-dimensional list array with and without
  names. Tests fire the second for a one-dimensional list array with names
  as a message.
- [ ] AC3: A walk reads each message and each list and data frame below it.
  For a data-frame `messages` value, it starts at each cell of a list column
  and at each data-frame column. The names of a list column itself are not
  read, because jsonlite does not write them. The walk reads the names
  attribute of each object it reaches. An `NA`, an empty, or a repeated name
  there aborts before the server probe. The abort has its own detail text. A
  list whose names attribute is `NULL` passes. Tests fire the abort in both
  forms of `messages`. The list-form probes are a repeated field name in a
  message, a partly named list in `content`, a list whose names are all
  empty, an `NA` name two levels down, and an `I()` list with a repeated
  name. The data-frame probes are a list-column cell with a repeated name and
  a nested data-frame column with an empty name. Tests also show that a
  fully named and an unnamed nested list, and a list column with names,
  reach the request.
- [ ] AC4: The call writes `unclass_messages(messages)` with
  `jsonlite::toJSON(auto_unbox = TRUE, digits = 22, null = "null")`. The
  write comes after the rules of AC1 to AC3 and the older `messages` rules,
  and before the server probe. If that
  write raises an error, the call aborts there. The abort has no condition
  class. Its message names `messages` and holds the jsonlite message
  verbatim, braces included. Tests fire it for a field with the class
  `"foo"`, a data-frame column with the class `"foo"`, an environment as a
  field, and a `quote()` field. Tests also show that a `Date`, a `factor`,
  and an `I()` field reach the request. For each rule of AC1 to AC3, a test
  sends a value that breaks that rule and also fails the write, and gets the
  rule's detail text.
- [ ] AC5: The help at `messages` in `R/chat.R` and NEWS.md state the rules
  of AC1 to AC4. The help no longer says that the package leaves the content
  of a message to the server alone. `devtools::document()` gives no diff.
  `devtools::test()` passes. `devtools::check()` gives 0 errors and 0
  warnings.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5

## Tasks

- [x] T1: In `data_frame_messages_fault()` (`R/utils-args.R:427`), count a
  `NULL` list cell as empty in the empty-row rule. Add the abort and pass
  cases to the `messages` probe tables in `tests/testthat/test-arg-guards.R`.
- [x] T2: Add the outer `dim` rule to `messages_fault()` and the message
  `dim` rule beside `is_named_message()`, each with its own detail text. Add
  the probes.
- [x] T3: Add the name walk as a helper that `messages_fault()` calls after
  the message rules, in both forms. Add the probes, including the passing
  nested lists.
- [x] T4: Add the trial write to `rlm_check_messages()` after
  `messages_fault()`. Pass the jsonlite text to cli as a value, not as
  format text. Add the probes and the rule-order probes. Rewrite the test
  "a class below the message level still reaches jsonlite"
  (`tests/testthat/test-arg-guards.R:1190-1215`), because its calls now
  abort before the probe.
- [x] T5: Update the help at `messages` (`R/chat.R:268-297`), the roxygen
  comment on `rlm_check_messages()`, and NEWS.md. Run
  `devtools::document()`, `devtools::test()`, and `devtools::check()`.

## Work log

- 2026-09-27: created by /milestone-plan. Absorbs three candidate rows from the M039 review (the `NULL` cell row, the list-matrix, and the classes and names below the message level).
- 2026-09-27: criteria audit (full mode, fresh reader) returned 10 findings. Seven were fixed at the gate: goal wording, `NULL` names wording, literal jsonlite options, no condition class, the help sentence on content, a message-level `dim` rule, and wider probes. Three became gate questions. The reader also asked for a D-entry that narrows D-003. None was written, because D-020 already limits D-003 to fields in `...`.
- 2026-09-27: second fresh reader on the changed criteria returned 7 findings, all fixed: the walk starts at list-column cells, `dim` rules run before names rules, rule-order probes moved into AC4, the old class test is rewritten in T4, wider name probes, and the jsonlite text is kept verbatim.
- 2026-09-27: status in-progress on branch m040-openai-messages-shape-and-write. Question gate skipped, because nothing was left open and jsonlite is already an import.
- 2026-09-27: T1 done. `empty_rows()` reads each column alone, because `is.na()` on the whole data frame spreads a matrix column over several. Three abort probes and three pass probes added. The old `is.na()` rule planted in place turned the abort test red. `devtools::test()` passed.
- 2026-09-27: T2 done. The message `dim` rule skips a data frame, which rule 4 refuses with its own text. Four probes added. Removing each `dim` rule in place turned the abort test red. `devtools::test()` passed.
- 2026-09-27: T3 done. `nested_names_fault()` and `has_bad_name()` walk both forms. Seven abort probes and three pass probes added. Four planted walk defects each turned a test red: no repeated-name check, no list-column cells, no data-frame branch, and reading list-column names. The last one needed the pass probe to use an empty list-column name. `devtools::test()` passed.
- 2026-09-27: T4 done. `messages_write_fault()` runs after `messages_fault()`. Nine probes added: five for the write and four rule-order probes, which a new test shows also fail the write. A braces test and a Date, factor, and `I()` pass test were added. The old test that let a class below the message level reach jsonlite is replaced. Three plants each turned a test red: no write check, the write before the rules, and the jsonlite text passed to cli as format text. `devtools::test()` passed.
- 2026-09-27: T5 done. Help at `messages` and NEWS updated. `devtools::document()` gives no further diff, apart from the known `@aliases` warning at `R/conditions.R:257`. `devtools::test()` passed. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-27: claim audit: 31 claims read, 4 corrected — R/chat.R, R/utils-args.R, NEWS.md, tests/testthat/test-arg-guards.R. The corrections cover how jsonlite writes `NA` and `NULL` cells, the matrix-row case in `empty_rows()`, the NEWS "Before" text of the name rule, and `names()` on one-dimensional list arrays. The re-read found one more gap, the `NA` list cell, and it was fixed. `devtools::test()` passed after the wording fixes. The fixes change roxygen, comments, and NEWS only.
- 2026-09-27: status review.
- 2026-09-27: plan gate chose to refuse a list-matrix over sending it flat in storage order, because the order can differ from the order on screen; falsified by a user who builds `messages` as a matrix on purpose.
- 2026-09-27: plan gate chose to treat only a `NULL` cell as empty over any length-0 cell, because `list()` writes the field value `[]`; falsified by a server that treats a message holding only an empty-array field as no message.
- 2026-09-27: plan gate chose to refuse repeated names below the message level over `NA` and empty names alone, because jsonlite renames a repeated `a` to `a.1`; falsified by a jsonlite version that keeps repeated keys.
- 2026-09-27: plan gate chose a trial jsonlite write over a class allow-list, because the write covers each class jsonlite cannot write with no list to keep; falsified by a jsonlite write that succeeds in the check and fails in the request.

## Decisions

## Review
