# M063: A load above the trained context warns, and the help says how to fit a long prompt

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP4, GP6
- **Resolves:** —
- **Surface tier:** user-facing — it adds a warning to `lms_load()` and help text to exported functions.
- **Branch/PR:** —

## Goal

A user with a prompt longer than the loaded context learns from R how LM Studio treats it and how far a larger `context_length` can go.

## Scope

**In:**
- A warning from `lms_load()` when `context_length` is larger than the `max_context_length` in the model list. The server loads such a value with no clamp and no message. The load still goes ahead with the asked value.
- The warning is on the `force = FALSE` path only, which reads the model list already. With `force = TRUE`, `lms_load()` sends no new request. The compare runs only when `as.integer(context_length)` gives one value that is not NA.
- A shape rule on `max_context_length` in the model list, as D-017 asks of a field that a function reads. It must be a number, null, or absent. This also changes `list_models()`.
- A "Long prompts" help section on the `lms_load()` and `lms_chat()` pages. It covers the server error for a prompt longer than the loaded context and the ceiling on `context_length`. It also covers the probed RoPE field and the token counts that a reply reports.
- The live probe facts of 2026-09-30 in cairn/references/lmstudio-api-surface.md. NEWS.md, one D-entry, and tests.

**Out:**
- A RoPE or YaRN setting. The load endpoint rejects `rope_frequency_scale`, and `lms load` has no such flag. It becomes a candidate row, to promote once the load endpoint or `lms load` accepts a rope setting.
- A helper that splits a long text into pieces or summarizes piece by piece. The contract boundary keeps general LLM helpers out (GP1). No row.
- A check on a `context_length` in the `...` of a chat function. D-003 leaves it to the server. No row.
- A warning for an embedding text longer than the context. It stays its own candidate row.

## Acceptance criteria

- [ ] AC1: Take a model-list reply in which `model` is not loaded and has the `max_context_length` 32768. Then `lms_load(model, context_length = 65536)` gives one warning of class `rlmstudio_context_above_max`. Its message names 65536 and 32768. The load request is still sent, and its body holds `"context_length":65536`. A second test passes the string `"65536"` and gets the same warning.
- [ ] AC2: `lms_load()` gives no `rlmstudio_context_above_max` warning in each case below, and a test covers each. The cases are a `context_length` left `NULL`, equal to the maximum, or below it, and a `force = TRUE` call. They also cover a model already loaded, an empty model list, a list with no row whose `key` is `model`, a row whose `max_context_length` is `NA`, and a list with no `max_context_length` column. A `context_length` of `NA`, `"abc"`, or `c(4096, 8192)` gives no such warning and no new error. In each case other than the loaded model, the load request is still sent.
- [ ] AC3: A model-list reply in which the `max_context_length` of one model is a JSON string or a JSON object makes `lms_load()` and `list_models()` abort with `rlmstudio_bad_response`. A null value passes. Tests cover each of the four cases.
- [ ] AC4: The AC1 warning shows when the `rlmstudio.quiet` option is `TRUE`. A test sets the option and asserts the warning.
- [ ] AC5: A chat call that gets an overflow reply recorded on 2026-09-30 raises `rlmstudio_api_error`. The raw bodies are in cairn/references/lmstudio-api-surface.md. The server text is in `error.message` on the Responses and native routes, and in `error` as a string on the OpenAI route. The message holds the server text "The number of tokens to keep from the initial prompt is greater than the context length". Tests cover `lms_chat_openresponses()` and `lms_chat_native()` with the status 500 body, and `lms_chat_openai()` with the status 400 body. A test also runs `lms_chat_batch()` with `format = "list"` over 3 inputs, and the second reply is that 500 body. The result holds the first and third answers and the condition for the second input.
- [ ] AC6: The `lms_load()` and `lms_chat()` help pages each have a "Long prompts" section. It states the AC1 warning and the AC5 error. It states that LM Studio 0.4.25+1 rejected the load field `rope_frequency_scale`. It names the `input_tokens` reply column of `lms_chat_batch()`. NEWS.md has one entry for the warning.
- [ ] AC7: `devtools::test()` reports 0 failures and 0 errors. `devtools::check()`, run with `RLMSTUDIO_API_TOKEN` set, reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T1, T2
- AC5 → T1
- AC6 → T3
- AC7 → T4

## Tasks

- [ ] T1: Write the three raw overflow bodies of 2026-09-30 into cairn/references/lmstudio-api-surface.md, from the plan work log. Write the AC1 to AC5 tests first with `local_request_sequence()` (tests/testthat/helper-mock-http.R:37), a model-list reply and then a load reply. See the AC1, AC3, and AC4 tests red on main. Copy the overflow bodies into the test file. Plant a wrong warning message and see the AC1 test go red (M026 lesson). Count warnings with `withCallingHandlers()` (M019 lesson).
- [ ] T2: In `lms_load()` (R/load.R:64), make the `force = FALSE` pre-check (R/load.R:90) read the model list with `loaded = FALSE`. Keep its loaded filter on that list, so the call still sends two requests (M008 lesson). Compare `as.integer(context_length)` with the `max_context_length` of the row whose `key` is `model`. Warn with `cli::cli_warn()` and the class. A missing row, column, or value gives no warning. Add the `max_context_length` rule to `model_list_fault()` (R/list.R:467) beside the `size_bytes` rule. In a scratch copy, remove the warning and see a test go red.
- [ ] T3: Write the two help sections from the probe facts, then run `devtools::document()`. Add the facts to cairn/references/lmstudio-api-surface.md with the date and version. With gemma-3-1b loaded at 512 tokens, the Responses and native routes answered 500 with the overflow text. The OpenAI route answered 400 with it. The load endpoint loaded gemma-3-1b at 65536 tokens with status 200, above its maximum of 32768. It rejected `rope_frequency_scale` with code `unrecognized_keys`. Add the NEWS.md entry.
- [ ] T4: Append one D-entry: the load warning shows past quiet, which widens the GP6 exceptions of D-010 and D-021. The entry also records the `max_context_length` rule under D-017. Set `RLMSTUDIO_API_TOKEN`, then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan from the user's request to research long inputs, YaRN named. The research and a live probe found no RoPE or YaRN setting that the package can reach.
- 2026-09-30: overflow bodies, gemma-3-1b at 512 tokens. `/v1/responses` 500: `{"error":{"message":"The number of tokens to keep from the initial prompt is greater than the context length. Try to load the model with a larger context length, or provide a shorter input","type":"internal_error","param":null,"code":"unknown"}}`. `/api/v1/chat` 500: the same object with the keys in the order message, type, code, param. `/v1/chat/completions` 400: `{"error":"<the same text>"}`.
- 2026-09-30: criteria audit (full mode, fresh Opus reader), pass 1, returned 6 findings on M063, all fixed without a question. Named the unloaded fixture, added empty-list and missing-column cases and a string `context_length`, bound AC1 to the reply and not the recorder, named `format = "list"`, and narrowed the RoPE claim to the probed field.
- 2026-09-30: plan gate chose the warning on the `force = FALSE` path only over a new model-list request under `force = TRUE`. That request could abort a load that works today. Falsified by a user who loads above the maximum with `force = TRUE` and misses the warning.
- 2026-09-30: plan gate chose a warning that shows past quiet over one that honors quiet. Replies past the trained length can degrade with no other sign. Falsified by a user who runs quiet scripts and treats the warning as noise.
- 2026-09-30: plan gate chose a warning and help text over a text-splitting helper, which GP1 keeps out. Falsified by users who need one vector or answer for a text longer than any context the model allows.
- 2026-09-30: criteria audit pass 2 (full mode, new fresh Opus reader) returned 3 findings, all fixed without a question. Added the D-017 shape rule on `max_context_length` (AC3), a guard and probes for `context_length` values that `as.integer()` cannot read, and the raw overflow bodies with the field that holds the text.

## Decisions

## Review
