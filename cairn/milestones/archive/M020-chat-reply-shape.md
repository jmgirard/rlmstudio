# M020: A chat reply without readable answer text fails that input, not the batch

**Status:** done (2026-09-22, PR #20 https://github.com/jmgirard/rlmstudio/pull/20,
every check green on the first run, squash 3dbfd99)

**Goal:** Every chat route reads its answer from the message items, and a reply
without one aborts, so `lms_chat_batch()` stores it per input.

**Outcome:** `chat_message_items()` selects the `"message"` items of a native or
OpenResponses reply. `responses_text_parts()` selects the `output_text` parts,
and `join_reply_texts()` pastes the texts in order. Each helper aborts with
`rlmstudio_bad_response` on a shape it cannot read. OpenResponses logprobs rows
come from every selected part. `lms_chat_openai()` aborts on content that is
not one string. It shares `abort_unread_reply()` with `parse_schema_reply()`.
The `data.frame` and `simplify = FALSE` check in `lms_chat_batch()` now runs
before the server probe. The unreadable-reply tables live in
`tests/testthat/helper-chat-bodies.R`, and the batch tests reuse them.

**Decisions:** D-012, which extends D-007 and D-011.

**Review:** One pass, three-lens fan-out, user-facing tier. All seven criteria
passed. The history and prior-review lenses found nothing. The diff lens gave
eight findings and no criterion failure. At the gate, O5 (a token-limit test)
and O6 (a help sentence) were fixed. O1 to O3 became three candidate rows. O4
and O7 were rejected, and O8 was noted. No lesson added or retired.
