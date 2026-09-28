# M038: The OpenAI chat function refuses a messages value it cannot send as a list of messages

**Status:** done (2026-09-27, PR #38 https://github.com/jmgirard/rlmstudio/pull/38)

**Goal:** A `messages` value that is not a non-empty list of named lists
makes `lms_chat_openai()` abort before the server probe.

**Outcome:** `rlm_check_messages()`, `messages_fault()`, and
`is_named_message()` in `R/utils-args.R` apply four rules, each with one
detail text. The value is a list or a data frame. It has at least one row
or element. A list that is not a data frame has no names attribute. Each
element is a list of length one or more and not a data frame. Each field
has a name that is not NA or empty. A data frame with rows passes. The
abort has no condition class. `lms_chat_openai()` calls the check after
the model check and above `stop_if_no_server()`. Help at
`messages`, the conditions page, and NEWS say so. Three existing tests now
pass a valid message.

**Decisions:** none. D-020 already covers a check on a named argument.

**Review:** One pass, three-lens fan-out. All four criteria passed, and
`devtools::check()` gave 0 notes. Two lenses found nothing. The diff-bug
lens found 8 items. The gate fixed 3. A data frame as one message was
sent as a nested array. A test comment was stale. A line break was odd.
It moved 2 to one candidate row and rejected 3.
