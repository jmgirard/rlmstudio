# M036: The chat completions help says that a reply is read from its first choice

**Status:** done (2026-09-27, PR #36 https://github.com/jmgirard/rlmstudio/pull/36)

**Goal:** With `simplify = TRUE`, `lms_chat_openai()` reads a reply from its
first choice alone, and its help pages say so.

**Outcome:** No runtime change. `two_choice_body()` in
`helper-chat-bodies.R` and `test-chat-first-choice.R` pin the rule on the
text, `logprobs`, and schema routes, and on the three batch formats. The
`@return` of `lms_chat_openai()` and the "Cut-off reply" and "Malformed
response" sections now name the first choice. One NEWS bullet states it.

**Decisions:** D-022 records the first-choice rule.

**Review:** One pass, three-lens fan-out. All five criteria passed, and
`devtools::check()` gave 0 notes. Two lenses found nothing. The diff-bug
lens found 8 minor items. The gate fixed O2: the help said that the cut-off
warning reports a finish reason, but the warning names none. It rejected
the other 7. A two-line `@aliases` warning from M035 became a candidate row.
