# M058: Continue a chat thread by its reply id

**Status:** done (2026-09-30, PR #58 https://github.com/jmgirard/rlmstudio/pull/58).

**Goal:** A user continues a stored LM Studio chat thread from R on the
native and OpenResponses routes, with no parse of the raw reply body.

**Outcome:** `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()`
take `previous_response_id` after `...`, and `lms_chat_batch()` takes it in
its dots. `rlm_check_response_id()` checks it above the server probe, and
`rlm_check_thread_route()` refuses it on the OpenAI route. `with_response_id()`
puts the reply id in a `response_id` attribute with `simplify = TRUE`. The
batch data-frame reader sets it too, so an abort's `results` match in every
format. `data-raw/record-thread-cassette.R` recorded `thread_live/`.

**Decisions:** D-030 (named argument and attribute) and D-031 (it reverses
the D-013 attribute rejection and states the whitespace rule).

**Review:** Pass 1 returned the milestone once on AC6, because two help pages
stated one route's `store = FALSE` fact only. T8 fixed it. Pass 2 ran three
lenses with 24 findings and no criterion failing. The gate fixed ten: O1,
where the data-frame abort `results` dropped the id, plus help, vignette,
NEWS, Air, the API reference note, and D-031. Four went to candidate rows,
and six were rejected. Two M007 lessons were joined into one line.
