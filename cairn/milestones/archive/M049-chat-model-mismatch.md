# M049: A chat call aborts on a reply from a different model

**Status:** done (2026-09-28, PR #49 https://github.com/jmgirard/rlmstudio/pull/49)

**Goal:** If the server cannot serve the model asked for,
`lms_chat_openai()`, `lms_chat_openresponses()`, and `lms_chat_batch()` abort.

**Outcome:** `check_reply_model()` in `R/chat.R` reads the `model` field of
each status-200 reply on both routes. A name that differs from the asked name
starts one lookup of `/api/v1/models` through `request_model_list()` in
`R/list.R`. The lookup accepts a loaded instance of the asked key in any
letter case. Otherwise the call aborts with `rlmstudio_model_mismatch`, an
`rlmstudio_bad_response` with `model` and `reply_model` fields. The batch
stops with `results` at a mismatch and at a 400 `model_not_found`.
`rlm_abort_api()` adds a `code` field. Help, NEWS, and recorded replies.

**Decisions:** D-025 (the check and its batch stops), D-026 (the fourth
difference between the embedding and chat batches).

**Review:** Three passes of three lenses. At passes 1 and 2, AC2(a) failed
for a named, classed, or S4 model string, and the gate sent it back. T7 to
T10 fixed those and 15 other findings. Pass 3 found no criterion failing. It
fixed a work-log claim and the recorder load flags. Eight model-name findings
went to the candidate row "Six model-name cases outside M049". Two M001
lessons were pruned to fit the LESSONS cap.
