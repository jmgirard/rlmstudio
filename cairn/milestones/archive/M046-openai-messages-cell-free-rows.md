# M046: The OpenAI chat function counts an array row with no cells as a field value

**Status:** done (2026-09-28, PR #46 https://github.com/jmgirard/rlmstudio/pull/46)

**Goal:** `lms_chat_openai()` does not count a `messages` column with a
`dim` attribute as empty in a row that holds no cells of it.

**Outcome:** `empty_rows()` in `R/utils-args.R` returns `FALSE` for each
row of a `dim` column whose extents after the first multiply to zero. Such a
row is now sent as `[]` or nested empty arrays. That holds for an atomic
matrix or array with no class, and for a list matrix. A list array of three or more
dimensions now gets the list-array detail. A data-frame column with no
columns still counts as empty, which M040's recursion gives. The help,
the roxygen, NEWS, and three tests match.

**Decisions:** none.

**Review:** All four criteria passed. The three-lens fan-out found no code
bug. The gate fixed O1 to O3 (help and NEWS wording) and added the
list-array test for O6. O5 and the classed-matrix part of O6 became one
candidate row. O4 and P1 were rejected. P1 was RR01 B1, which the first
M044 plan gate kept. No lessons changed.
