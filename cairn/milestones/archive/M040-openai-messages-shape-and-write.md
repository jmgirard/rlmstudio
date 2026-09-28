# M040: The OpenAI chat function refuses a messages value that jsonlite cannot write or that breaks a shape rule

**Status:** done (2026-09-27, PR #40 https://github.com/jmgirard/rlmstudio/pull/40)

**Goal:** `lms_chat_openai()` refuses, before the server probe, a
`messages` value that jsonlite cannot write or that breaks a shape rule.

**Outcome:** In `R/utils-args.R`, `empty_rows()` counts a `NULL` list cell
as empty. It reads a matrix or list-matrix column per row and recurses
into a data-frame column. `messages_fault()` refuses a list or a message
with a `dim` attribute. `nested_names_fault()` and `has_bad_name()` walk
both forms for an `NA`, empty, or repeated name. `messages_write_fault()`
runs a trial `jsonlite::toJSON()` last and aborts with the jsonlite text.
Help at `messages`, NEWS, and tests say so.

**Decisions:** none. The plan gate made four choices. It refuses a
list-matrix and repeated nested names. Only `NULL` cells count as empty.
A trial write replaces a class allow-list. The work log in git holds each
reason.

**Review:** One pass, three-lens fan-out. All five criteria passed, and
`devtools::check()` gave 0 notes. Two lenses found no regression. The
gate fixed a false abort on a list-matrix row, `NULL` cells in a nested
data frame, and four wording gaps. It moved the write-abort header to a
candidate row and rejected three items.
