# M018: A failed structured reply keeps its text and no longer ends a batch

**Status:** done (2026-09-22, PR #18 https://github.com/jmgirard/rlmstudio/pull/18,
every check green, squash f50a4f7)

**Goal:** An unreadable structured reply aborts with its text and finish reason
attached, and a batch stores that abort in the failed input's slot.

**Outcome:** `lms_chat_openai()` guards `choices` and its first `message`,
reads fields with `[[`, and aborts through `rlm_abort_bad_response()`.
`parse_schema_reply()` adds `content`, `finish_reason`, and a `max_tokens`
message for `"length"`. `lms_chat_batch()` stores a trace-free condition per
failed input and warns once through `cli::cli_warn()`, positions joined by
`cli::ansi_collapse(trunc = Inf)`. `local_request_sequence()` mocks a reply
per request. `data-raw/record-cutoff-cassette.R` records `chat_cutoff_live`.

**Decisions:** none new. D-010 covers the warning that ignores `quiet`.

**Review:** Two passes, three-lens fan-out, user-facing tier. Pass 1 returned
the milestone once: the warning cut positions past 20 (AC4); nine findings
became T8 to T13, two were rejected. Pass 2 passed all seven criteria; six
findings were fixed at the gate, one became a candidate row, one was
rejected. Retired the M017 `list()` as `[]` lesson: the `schema` docs own it.
