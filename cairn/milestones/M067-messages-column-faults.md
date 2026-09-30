# M067: A messages data frame with a wrong-length or unwritable column gets a message that names the fault

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — the change is the error text of the exported `lms_chat_openai()`
- **Branch/PR:** m067-messages-column-faults

## Goal

`lms_chat_openai()` names the fault in a `messages` data frame that holds a
column with a wrong row count, or a column that jsonlite cannot write.

## Scope

**In:** The cause, from probes on 2026-09-30 on main at 3fc94c1. A column
whose row count differs from its data frame fails the trial write. The
detail is then jsonlite text such as "values must be length 2, but
FUN(X[[3]]) result is length 3", which names no column. Before that,
`empty_rows()` recycles the column. Eight probe shapes give the R warning
"longer object length is not a multiple of shorter object length". A
one-dimensional array of length 1 gives no package abort. It gives the R
error "dims [product 1] do not match the length of object [2]". A 3-by-2 `NA`
matrix alone gets the empty-row detail. Of the classed columns probed with a
wrong length, only a length-1 `POSIXlt` passes, and jsonlite writes its value
in each row. jsonlite writes a classed `dim` column by its class and drops
the `dim`, so a 2-by-2 or 2-by-0 `Date` matrix fails the write. The fix has
three parts. A row-count rule reads plain columns. `empty_rows()` gets a
stated reading of wrong-length columns. A failed write names the column.
`rlm_check_messages()` (R/utils-args.R:587) has one caller,
`lms_chat_openai()` (R/chat.R:640).

**Out:** A `messages` list that is not a data frame keeps the jsonlite text
alone. The number-rule gaps of `lms_chat_openai()` stay in their candidate
row.

## Acceptance criteria

- [ ] AC1: `lms_chat_openai()` refuses a `messages` data frame that holds a
      column whose row count differs from the row count of the data frame
      that holds it. The error has the shape header "`messages` must be a
      data frame or an unnamed list of messages." The detail is "You gave a
      data frame with a column whose row count differs from the row count of
      the data frame." The rule reads each data-frame column, and each atomic
      or list column with no class attribute or with the class `"AsIs"`
      alone. It reads such columns in the data frame and in its data-frame
      columns at any depth. For a data-frame column, the row count is the row
      count of that column. For a column with a `dim` attribute, it is the
      first extent of the `dim`. For any other column, it is the length. The
      rule runs before the empty-row rule. The abort comes before the check
      for a running server. A test in `tests/testthat/test-arg-guards.R`
      asserts the detail and no server call for each of 15 probes in a 2-row
      frame. Seven probes have a `dim`: a 3-by-2 and a 1-by-2 character
      matrix, a 3-by-0 matrix, and a 3-by-2 `NA` matrix that is the only
      column. The other three are one-dimensional arrays of length 3 and of
      length 1, and a 3-by-1 list-matrix. Four probes have no `dim`: a list
      column of length 3, a character column of length 1, `character(0)`,
      and an `I()` character column of length 3. Four probes are data-frame
      columns. Two of them have 3 rows and 0 rows. The other two have 2 rows
      and hold a 3-by-2 matrix or a list column of length 3.
- [ ] AC2: Each AC1 probe raises no warning. Three classed columns in a
      2-row frame also raise no warning and no R error from outside the
      package: a `Date` column of length 3, a `factor` column of length 3,
      and a one-dimensional `Date` array of length 1. Each of the three
      aborts through the trial write with the AC3 line. A length-1 `POSIXlt`
      column in a 2-row frame still passes, and the body that the package
      sends is the same as on main. The empty-row rule reads a length-1
      column as jsonlite writes it, with its one cell in each row. It reads a
      column of any other wrong length as not empty in each row. So a frame
      whose only column that is not all `NA` is an `NA` `POSIXlt` of length 1
      still gets the empty-row detail. A test in
      `tests/testthat/test-arg-guards.R` counts the warnings of each probe
      and asserts each outcome.
- [ ] AC3: The trial write of a `messages` data frame can fail. When a
      top-level column fails alone, the abort keeps its detail "You gave a
      value that jsonlite cannot write: <jsonlite message>" and adds a line
      that names that column. The package writer writes each top-level column
      alone, as a data frame with the same row count, in column order. The
      line names the first column that this write fails on. A test in
      `tests/testthat/test-arg-guards.R` asserts the named column for these
      probes, each placed after a column that writes. Three probes are a
      2-by-0 `Date` matrix, a 2-by-2 `Date` matrix, and a 2-by-1 matrix with
      the class `"foo"` alone. A fourth probe puts the `"foo"` matrix in a
      column named `"{a}"` and asserts that the line shows `{a}` as written.
      In a fifth probe, a data-frame column holds a 2-by-2 `Date` matrix and
      comes before a `"foo"` matrix column. The test asserts that the line
      names the data-frame column. A `messages` list that is not a data frame
      and fails the trial write gets no such line, and a test asserts that.
- [ ] AC4: The `messages` help of `lms_chat_openai()` states the AC1 rule
      among the shape rules and states the AC3 line. `NEWS.md` has an entry
      for each.
- [ ] AC5: `devtools::test()` reports 0 failed and 0 errors.
      `devtools::check()` reports 0 errors, 0 warnings, and 0 notes.

## Coverage

- AC1 → T1, T2, T6
- AC2 → T1, T2
- AC3 → T3, T4, T6
- AC4 → T5
- AC5 → T6

## Tasks

- [ ] T1: Write the AC1 and AC2 tests first in `test-arg-guards.R`. Add the
      AC1 detail to the rule table near line 1114, stated by hand. Build
      each probe with `structure()`. Collect warnings with
      `withCallingHandlers()` and count them. For the `POSIXlt` probe, state
      the expected body text by hand. Run the tests on main and record the
      failure identity of each.
- [ ] T2: Add the row-count rule to `data_frame_messages_fault()`, before
      `empty_rows()`, with a helper that goes down data-frame columns. Change
      `empty_rows()` to read a wrong-length column as AC2 states. Update the
      `@noRd` text of `rlm_check_messages()`, `data_frame_messages_fault()`,
      and `empty_rows()` on rule order.
- [ ] T3: Write the AC3 tests first. Run them on the T2 code and record the
      failure identity of each.
- [ ] T4: In `messages_write_fault()`, on a failed write of a data frame,
      write each top-level column alone through `rlm_json_text()` and add the
      line for the first that fails. Splice the column name as a value, so
      cli does not read its braces (the M012 lesson).
- [ ] T5: Update the `messages` help in `R/chat.R` near line 489 and add two
      `NEWS.md` entries. Run `devtools::document()`.
- [ ] T6: In a scratch copy, move the row-count rule after `empty_rows()` and
      see the `NA` matrix probe go red. Remove the column line and see the
      AC3 tests go red. Restore both. Run `devtools::test()` and
      `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan, from the candidate row on two `messages` data-frame columns that `empty_rows()` reads badly (M046 review findings O5 and O6).
- 2026-09-30: criteria audit (full mode, fresh Opus reader, two passes). Pass 1: AC1 refused a length-1 `POSIXlt` that works today. The `NA` matrix frame was unstated. Probes missed shapes, among them a 1-d array of length 1 that gives a raw R error. AC2 and AC3 promised past their probes. Pass 2: `empty_rows()` needed a stated reading of wrong-length columns, and the Facts undercounted the warning probes. Each finding was fixed before the gate.
- 2026-09-30: plan gate chose a row-count rule over plain and `"AsIs"` columns over one over every column by `length()`. The wider rule refuses a length-1 `POSIXlt` that is sent today. Falsified by a report that such a column sent a wrong value, or a classed wrong-length column whose column line a user misreads.
- 2026-09-30: plan gate chose naming the first column that fails a lone write over keeping the jsonlite text alone. Falsified by a data frame whose write fails while each column writes alone.
- 2026-09-30: implement started on branch m067-messages-column-faults. The question gate chose an info line for AC3. Its text is `Column {.val {name}} is the first column that jsonlite cannot write on its own.` The name is quoted, as model names are in other errors.

## Decisions

## Review
