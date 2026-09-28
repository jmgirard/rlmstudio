# M039: The OpenAI chat function sends a classed messages list and refuses a data frame with a bad column name or an empty row

**Status:** done (2026-09-27, PR #39 https://github.com/jmgirard/rlmstudio/pull/39)

**Goal:** `lms_chat_openai()` sends a `messages` list that has a class at
the outer level or on a message. It refuses a data frame that jsonlite
sends with empty or renamed messages, before the server probe.

**Outcome:** `unclass_messages()` in `R/utils-args.R` removes the class of
the outer list and of each message after `rlm_check_messages()`. It leaves
a data frame and any class below a message alone. `lms_chat_openai()`
builds the body from it. `data_frame_messages_fault()` adds two rules,
each with one detail text. The column rule refuses no columns, or a name
that is NA, empty, or repeated. The empty-row rule then refuses a row with
`NA` in every cell. Help at `messages`, NEWS, and tests say so.

**Decisions:** none. The plan gate chose class removal over refusal and
refusal of repeated column names. Both are in the git history.

**Review:** One pass, three-lens fan-out. All four criteria passed, and
`devtools::check()` gave 0 notes. Two lenses found no regression. The
diff-bug lens found 8 items. The gate fixed 2 in comments only and
rejected 3. It moved 3 to candidate rows: a `NULL` list cell row, the
dropped `dim`, and nested column names.
