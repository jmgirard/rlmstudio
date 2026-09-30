# M067: A messages data frame with a wrong-length or unwritable column gets a message that names the fault

**Status:** done (2026-09-30, PR #67 https://github.com/jmgirard/rlmstudio/pull/67).

**Goal:** `lms_chat_openai()` names the fault in a `messages` data frame that
holds a column with a wrong row count, or a column that jsonlite cannot write.

**Outcome:** `wrong_row_count()` and `column_row_count()` in R/utils-args.R
add a shape rule after the column-name rule and before the empty-row rule. It
reads data-frame columns and unclassed or `"AsIs"` atomic and list columns at
any depth, with the first `dim` extent as the row count. `empty_rows()` reads a
wrong-length classed column of length 1 in each row, and any other such column
as not empty, so no column is recycled. `first_unwritable_column()` writes each
top-level column alone after a failed trial write. The abort then adds a line
that names the first column that fails. The help and NEWS state both.

**Decisions:** A row-count rule over plain and `"AsIs"` columns, not over
every column by `length()`, so a length-1 `POSIXlt` is still sent. An info
line names the column as a value, so cli does not read its braces.

**Review:** Three lenses, no criterion failing. Fix-now at the gate: a test
for the not-empty reading, the help and NEWS limits for classed columns, and
the column line shown as code. Two findings became one candidate row. Eight
were rejected or noted. LESSONS M019 gained the parent-check count.
