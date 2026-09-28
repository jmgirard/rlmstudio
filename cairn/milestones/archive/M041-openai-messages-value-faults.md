# M041: The OpenAI chat function refuses a function or a list array inside a message, with a header for value faults

**Status:** done (2026-09-27, PR #41 https://github.com/jmgirard/rlmstudio/pull/41)

**Goal:** `lms_chat_openai()` refuses, before the server probe, a function
or a list array inside a message, and it reports a value fault under its
own header.

**Outcome:** In `R/utils-args.R`, `has_inner_list_array()` refuses a list
with a `dim` attribute inside a message. It also refuses a data-frame list
column with one, three, or more dimensions. A list-matrix column stays allowed. It runs
before the name rule. `has_function()` refuses a function anywhere in the
value, and `empty_rows()` reads a function column with no warning.
`rlm_check_messages()` gives the function and trial-write faults a new
header with no hint: "`messages` holds a field value that cannot be sent
as JSON."
Help at `messages`, NEWS, and tests say so.

**Decisions:** none. The plan gate chose the separate header, the refusal
of an inner list array, and no new D-entry (reasons in git).

**Review:** One pass, three lenses, all five criteria passed, 0 notes.
Findings O1 and O4 (`empty_rows()` on odd columns) became one candidate
row, and O2 (boxed list-matrix cells) another. Three were rejected.
