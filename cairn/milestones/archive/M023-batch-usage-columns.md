# M023: A data-frame chat batch reports each reply's id and token counts on the OpenResponses and OpenAI routes

**Status:** done (2026-09-22, PR #23 https://github.com/jmgirard/rlmstudio/pull/23,
squash b6b6cb0. The PR's `test-headless` job passed on its third run, after
two r2u mirror timeouts.)

**Goal:** On the OpenResponses and OpenAI routes, a data-frame
`lms_chat_batch()` returns the id and three token counts of each reply as
columns.

**Outcome:** `responses_reply_value()` and `openai_reply_value()` hold the
`simplify = TRUE` readers that the single calls and the data-frame batch share.
The batch reads each body through `read_reply()`. Then `add_reply_columns()`
adds `response_id`, `input_tokens`, `total_output_tokens`, and
`reasoning_output_tokens`, read from `id` and `usage`. `check_body_object()` makes a
bare JSON value body raise `rlmstudio_bad_response` on all three routes.

**Decisions:** D-014 records the four columns and their native names.

**Review:** One pass, three-lens fan-out, user-facing tier. All seven criteria
passed. The prior-review and blame-history lenses found nothing. The diff lens
reported 11 findings. O1, O6, and O10 were fixed at the gate: the OpenAI
bare-value condition now carries `content` and `finish_reason`. O2, a 200 body
that is not JSON, became a candidate row. The other seven were rejected. The
M002 r2u lesson was corrected to name the second failure message.
