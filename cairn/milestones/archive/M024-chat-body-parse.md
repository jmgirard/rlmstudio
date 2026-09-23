# M024: A chat reply that does not parse as JSON fails its input alone

**Status:** done (2026-09-23, PR #24 https://github.com/jmgirard/rlmstudio/pull/24)

**Goal:** A status-200 chat reply that does not parse as JSON aborts with
`rlmstudio_bad_response`, so a batch keeps its other replies.

**Outcome:** `parse_ok_body()` in `R/utils-api-error.R` holds the guard that
`lms_embed()` had. It parses with `check_type = FALSE` and aborts with
`rlmstudio_bad_response` and `status` 200L. The message points at the host
and leaves out the body text. `lms_embed()` and the three chat functions call
it before the `simplify` branch. The OpenAI route adds `content` and
`finish_reason` as `NULL`. `lms_chat_batch()` catches the condition through its
existing handler. The unguarded parses in `list_models()`, `lms_load()`, and
the download functions stay in a candidate row.

**Decisions:** D-015 records the abort with `simplify = FALSE`, the parse by
content, and no body field.

**Review:** One pass, three-lens fan-out, user-facing tier. All seven criteria
passed. The prior-review and blame-history lenses found nothing. The diff lens
reported 9 findings. O2, O3, O4, and O7 were fixed at the gate. O9 became
D-015. O1 joined the candidate row on batches where every input fails.
O5, O6, and O8 were rejected. The M019 lesson now names `expect_s3_class()`.
