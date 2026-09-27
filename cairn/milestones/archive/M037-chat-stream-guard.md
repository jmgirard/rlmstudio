# M037: The chat functions refuse a stream field before any request

**Status:** done (2026-09-27, PR #37 https://github.com/jmgirard/rlmstudio/pull/37)

**Goal:** A chat call with a `stream` in `...` other than `FALSE` or `NULL`
aborts before the server probe.

**Outcome:** `rlm_check_stream()` in `R/utils-args.R` checks every `stream`
element of `...` and accepts `NULL` or a `FALSE` that `isFALSE()` accepts.
It aborts with no condition class and cuts a long value to 60 characters.
The three direct chat functions call it above `stop_if_no_server()`.
`lms_chat_batch()` calls it on the raw `list(...)`, because
`rlm_chat_dots()` keeps only the first of two same-named values.
`lms_chat()` gets the check through the function that it calls. Help text
at `...` on the five chat pages, the conditions page, and NEWS say so.

**Decisions:** D-023 narrows D-003 and trades GP4.

**Review:** One pass, three-lens fan-out. All four criteria passed, and
`devtools::check()` gave 0 notes. Two lenses found nothing. The diff-bug
lens found 8 items. The gate fixed 2: a `FALSE` with attributes aborted,
and a long value gave a huge message. It rejected 4 and noted 2. Implement
narrowed AC3 through a gated amendment. The claim audit corrected 3
comments.
