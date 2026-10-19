# M095: Model-name stops for embeddings and batches

**Status:** done (2026-10-19, PR #98 https://github.com/jmgirard/rlmstudio/pull/98)

**Goal:** A model name that the server answers with another model or with "No models loaded" ends `lms_embed()` and `lms_chat_batch()` at the first request that shows it.

**Outcome:** `embed_request()` in `R/embed.R` runs `check_reply_model()`;
`lms_embed()` ends the call with `results` at `rlmstudio_model_mismatch` and at
a lookup `rlmstudio_no_server`. `rlm_abort_api()` adds `server_message`
(`api_error_text()`), and `is_no_models_loaded()` stops both batch functions
at a 400 whose text starts with "No models loaded". A per-call cache
(`reply_model_cache` in `R/chat.R`, keyed on name, id, and host, restore
registered before start) sends one lookup per accepted id. Recorded replies in
`tests/testthat/stop_live/` from `data-raw/record-model-stop-cassette.R`
(0.4.26+4); tests in `test-model-stops.R`, helpers in `helper-model-check.R`.

**Decisions:** D-046 (narrows D-019, annotates D-024, D-025, D-026). The plan
gate kept the variant-name case in its candidate row at the user's choice.

**Review:** Claim audit corrected 15 of 110 claims. Return 1: AC1 lacked the
recorded reply at request 2 of 3, and AC4 asked for one NEWS entry. Pass 2,
four lenses, 26 findings: 16 fixed (cache host key, restore order, help and
NEWS wording, tests), 8 rejected, 1 follow-up (row "chat-options
server_message"). Check clean, CI green. Narrowed "model-name cases" to the
variant-name case.
