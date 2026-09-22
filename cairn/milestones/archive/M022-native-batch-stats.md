# M022: A native chat batch reports each reply's stats and response id

**Status:** done (2026-09-22, PR #22 https://github.com/jmgirard/rlmstudio/pull/22,
every check green on the first run, squash ecb0742)

**Goal:** With `api_type = "native"` and `format = "data.frame"`,
`lms_chat_batch()` returns the `response_id` and the six `stats` fields of each
reply as columns.

**Outcome:** The native data-frame batch asks for the body and reads the text
through `native_reply_text()`, the helper `lms_chat_native()` now shares.
`native_reply_fields()` reads `response_id` and six `stats` fields with `[[`.
A value of the wrong type gives `NA` with no warning. A failed row is `NA` in
all seven columns. If every input failed, the columns keep their types.

**Decisions:** D-013 records the new columns and the silent `NA`.

**Review:** Two passes, three-lens fan-out, user-facing tier. Pass 1 failed
AC1, AC2, and AC6 as written. T7 moved the tests into `test-chat-batch.R` and
used `expect_no_warning()`. T8 added four help-page rules. Pass 2 passed all
seven criteria. At the gate, P2 became D-013, and P3, P5, and P6 were code and
test fixes. P8, a bare scalar body that ends a batch, became a candidate row.
P1, P4, P7, P9, P10, and P11 were rejected. No lesson added or retired.
