# M035: A chat completions reply that the token limit cut off no longer passes as complete

**Status:** done (2026-09-27, PR #35 https://github.com/jmgirard/rlmstudio/pull/35)

**Goal:** A `/v1/chat/completions` reply can carry the `finish_reason`
`"length"`. Such a reply aborts as a schema reply and warns as text, also
when the package can read it.

**Outcome:** On a cut-off schema reply without logprobs, even one that
parses, `openai_reply_value()` aborts with `rlmstudio_bad_response`. For a text reply,
`warn_if_cut_off()` gives an `rlmstudio_reply_cut_off` warning past quiet.
`lms_chat_batch()` muffles it for each input. `warn_cut_off_inputs()` gives
one batch warning with the positions, and it also runs before a batch abort.
The messages name `max_tokens` and the context length. A "Cut-off reply"
section covers three chat pages.

**Decisions:** D-021 records the abort and warning split and the quiet choice.

**Review:** One pass, three-lens fan-out. All seven criteria passed, and
`devtools::check()` was clean. Two lenses found nothing. The diff-bug lens
found 11 items. The gate fixed 5. A batch abort lost the cut-off warning.
The other four were test and doc fixes: an option test, the page title, a
dead detail string, and two messages. O3 and O7 became candidate rows. It
rejected 4 items (`warn = 2`, a non-string reason, cosmetic, test breadth).
