# M042: The OpenAI chat function reads each row of an array or non-vector messages column on its own

**Status:** done (2026-09-28, PR #42 https://github.com/jmgirard/rlmstudio/pull/42)

**Goal:** `lms_chat_openai()` judges each row of a `messages` data frame by
the cells of that row, for an array column or a column that is not a vector.

**Outcome:** `empty_rows()` in `R/utils-args.R` reads a column with a `dim`
attribute whose first extent is the row count through `apply()`, one row at
a time. A column that is neither atomic nor a list is never empty and skips
`is.na()`. The `messages` help states the rule and how a list-matrix column
is sent, with an example row. The `@aliases` tag in `R/conditions.R` is on
one line. NEWS and tests say so.

**Decisions:** one milestone-local entry. RR01 (`cairn/reviews/archive/`)
set AC2 to a text bounded to named test cases, because jsonlite judges a
non-vector value by its class attribute alone.

**Review:** Three passes and two defect returns, both on AC2, each from a
jsonlite write the text did not foresee. The second fired the thrash rule,
and the gate escalated to RB01. Pass 3 passed all six criteria and fixed a
false "still" in NEWS, a comment, a missing no-warning check, and Air
drift. Five findings were rejected, and four candidate rows were added or
rewritten.
