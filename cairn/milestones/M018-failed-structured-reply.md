# M018: A failed structured reply keeps its text and no longer ends a batch

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP4, GP6
- **Resolves:** —
- **Surface tier:** user-facing — changes what three exported chat functions return and raise
- **Branch/PR:** m018-failed-structured-reply

## Goal

An unreadable structured reply aborts with its text and finish reason
attached, and a batch stores that abort in the failed input's slot.

## Scope

**In:** An `rlmstudio_bad_response` abort in `lms_chat_openai()` on a body
with a missing or empty `choices`. Two fields, `content` and `finish_reason`,
on the aborts that `parse_schema_reply()` raises. A message for a reply that
the token limit cut off, and a hint that points at the `content` field. A
per-input catch of that class in `lms_chat_batch()`, with one warning that
ignores `quiet` (D-010). A mock that serves a different reply to each request.
A live cut-off reply recorded as a fixture. Docs for a nested empty object.
Edits to the unreleased NEWS bullets for `schema`.

**Out:** The three M017 review candidate rows are absorbed here and removed.
A batch that keeps going past an API error or a stopped server is a new
candidate row. A package conversion of nested empty lists stays out, because
the package does not read schema content (D-003). A batch without a `schema`
still aborts on an empty `choices`, because no parse is in play there.

## Acceptance criteria

- [ ] AC1: With `simplify = TRUE`, `lms_chat_openai()` aborts with class
      `rlmstudio_bad_response` and `status` 200 on two body shapes: a 200
      body with no `choices` field, and one with an empty `choices` list.
      This holds with and without a `schema`, and with `logprobs = TRUE`.
      The condition carries `content` and `finish_reason` as `NULL`. A test
      in `tests/testthat/test-chat-schema.R` fires both shapes under each of
      the three settings. It asserts the class and `status` 200. It also
      asserts that `content` and `finish_reason` are in `names(err)` and are
      `NULL`.
- [ ] AC2: Both aborts that `parse_schema_reply()` raises carry two fields.
      The first abort is for content that is not one string, and the second
      is for content that is not valid JSON. The `content` field holds the
      reply content, or `NULL` where there is none. The `finish_reason`
      field holds `choices[[1]]$finish_reason`, or `NULL` where the response
      has none. The hint names the `content` field and no longer tells the
      user to call again. A test asserts both fields and the hint on an
      invalid JSON string and on a JSON `null` content.
- [ ] AC3: In both aborts of AC2, a `finish_reason` of `"length"` gives a
      message that says the token limit cut the reply off and names
      `max_tokens`. Any other `finish_reason` gives the existing detail and
      no `max_tokens`. A test asserts both messages on the same content, so
      only `finish_reason` differs, for each of the two aborts. A reply that
      LM Studio cuts off at the token limit gets the `max_tokens` message.
      A test shows this by replaying a recorded cut-off reply.
- [ ] AC4: With a `schema`, `simplify = TRUE`, and `logprobs = FALSE`, an
      `rlmstudio_bad_response` from one input no longer aborts
      `lms_chat_batch()`. The failed input's element holds that condition, in
      the returned list for `format = "list"` and `"vector"`, and in the
      `output` list-column for `format = "data.frame"`. Every other element
      holds its parsed reply, in input order. The call gives one warning that
      names the count and the positions of the failed inputs. It gives that
      warning with `quiet = TRUE` and with the `rlmstudio.quiet` option set.
      With no failed input, `format = "vector"` keeps its existing warning.
      A test serves the replies invalid,
      valid, invalid in each format and asserts each element's identity and
      the warning text.
- [ ] AC5: An `rlmstudio_api_error` or an `rlmstudio_no_server` from one
      input still aborts `lms_chat_batch()` with that class. A test fails the
      second of three inputs with each class and asserts the class.
- [ ] AC6: The `schema` docs of `lms_chat_openai()` state that an empty
      object nested in the schema, such as `properties`, is written
      `setNames(list(), character())`, because `list()` is sent as `[]`. A
      test pins it: a schema with that `properties` is sent with
      `properties` as `{}`, read from the request bytes.
- [ ] AC7: The `rlmstudio-conditions` help page names the `content` and
      `finish_reason` fields and the empty-`choices` case. It says that
      `lms_chat_batch()` raises the class only where AC4 does not store the
      condition in a slot. It no longer says
      that every such message names `simplify = FALSE`. The
      `lms_chat_batch()` help page states what a failed element holds and
      that other errors still abort. The NEWS bullets for `schema` describe
      AC1 to AC4.

## Coverage

- AC1 → T2
- AC2 → T3
- AC3 → T3, T4
- AC4 → T1, T5
- AC5 → T1, T5
- AC6 → T6
- AC7 → T7

## Tasks

- [x] T1: Add a mock helper in `tests/testthat/helper-mock-http.R` that
      serves a list of responses in turn. `local_request_recorder` returns
      one response to every request (`helper-mock-http.R:26-48`).
- [x] T2: Guard `choices` in `lms_chat_openai()` before `R/chat.R:324`, on
      every `simplify = TRUE` path. Abort through `rlm_abort_bad_response()`
      with `content` and `finish_reason` as `NULL`. Add the AC1 tests.
- [x] T3: Pass `finish_reason` into `parse_schema_reply()` (`R/chat.R:374`).
      Add the two fields, the `"length"` detail, and the new hint to both
      aborts. `rlm_abort_bad_response()` in `R/utils-api-error.R:127` takes
      the extra fields. Add the AC2 and AC3 mocked tests.
- [x] T4: Add `data-raw/record-cutoff-cassette.R`, modeled on
      `data-raw/record-schema-cassette.R`, with a small `max_tokens`. Clean
      up in a `tryCatch()` `finally` clause (LESSONS, M017). Record the
      fixture with LM Studio running and add the replay test. The test
      asserts that the recorded `finish_reason` is `"length"`.
- [x] T5: In `lms_chat_batch()`, wrap only the `lms_chat()` call
      (`R/chat.R:532`) in a handler for class `rlmstudio_bad_response`, so
      the progress bar still moves. Warn once after the loop through
      `cli::cli_warn()`, not the quiet helpers (D-010). If an input failed in
      vector format, give only the warning about failures. Add the
      AC4 and AC5 tests. The `rlmstudio_no_server` test mocks
      `is_server_running` to return TRUE, TRUE, FALSE across the batch probe
      (`R/chat.R:514`) and the first two calls (`R/chat.R:299`).
- [x] T6: Write the nested empty-object sentence in the `schema` docs and
      add the AC6 test.
- [x] T7: Rewrite `R/conditions.R:49-61` and the batch `@details` at
      `R/chat.R:476-480`. Edit the unreleased NEWS bullets for `schema` in
      place. Map each NEWS claim to a test named in AC1 to AC6. Run
      `devtools::document()` and `devtools::check()`.

## Work log

- 2026-09-21: created by /milestone-plan. Absorbs three candidate rows from the M017 review (findings R5, R6, R7, R10, R11).
- 2026-09-21: criteria audit ran in full mode with a fresh reader. It returned findings on all seven criteria. AC1 to AC3 had unprobed branches. AC4 lacked a sequenced mock and gave a second warning. AC5 had an unbounded "any other error", and AC7 bound a review-side mapping. All were fixed before the gate.
- 2026-09-21: second full-mode audit pass over the revised text returned six findings, all fixed before commit. AC1 asserts `status` and the field names. AC3 names the LM Studio reply rather than the recording. AC4 covers the option and the vector warning with no failure. T5 names the `no_server` mock, and AC7 states the cases where the batch still raises.
- 2026-09-21: plan gate chose to store the condition in the failed slot over storing `NULL`, because `NULL` loses the reply text. It also rejected aborting with partial results attached, because a script then has to catch the error to recover them. Falsified by users who filter batch output and find a condition object in a list-column harder to handle than `NULL`.
- 2026-09-21: plan gate chose a warning that ignores `quiet` over one that honors it, because a quiet batch then returns failed slots with no signal. Falsified by a user who runs quiet batches and treats the warning as noise.
- 2026-09-21: plan gate chose to document nested empty objects over converting known keywords such as `properties`. A keyword list goes stale as JSON Schema changes (D-003). Falsified by repeated server errors from users who write `properties = list()`.
- 2026-09-21: plan gate chose a live recorded cut-off reply over mocks only, so the `"length"` value comes from LM Studio and not from the OpenAI format. Falsified by an LM Studio reply that reports the cut-off in another field.
- 2026-09-21: implement gate: the user allowed starting the LM Studio server for the T4 recording. If the model is already loaded, the script skips the load and the unload.
- 2026-09-21: T1 done. `local_request_sequence()` serves a list of responses in turn and raises past its end. Both recorders share `local_mock_perform()`. Suite 1542 pass.
- 2026-09-21: T2 and T3 done in one commit, because both edit the same lines of `lms_chat_openai()`. The detail clause carries plain backticks, because cli does not read markup inside an inserted value. Suite 1612 pass.
- 2026-09-21: T4 done. The live gemma-3-1b reply with `max_tokens` 5 came back as `{"why":` with `finish_reason` `"length"`. The script records with `simplify = FALSE`, because with `simplify = TRUE` the abort stops the recording. The server was started for the recording and stopped after it, and the loaded model stayed loaded.
- 2026-09-21: T5 done. If the batch parses replies, it catches `rlmstudio_bad_response`. Otherwise it does not, so a batch without a `schema` still aborts. Suite 1657 pass.
- 2026-09-21: T6 done. The test also pins that a bare `list()` goes out as `[]`, the reason the docs give. Suite 1659 pass.
- 2026-09-21: T7 done. NEWS map: nested empty object to AC6, the two fields to AC2, the `max_tokens` message to AC3. No `choices` maps to AC1, and the batch bullet to AC4 and AC5. A run on main showed the old behavior: an empty `choices` gave `subscript out of bounds`, and a missing one returned `NULL`. `devtools::check()` 0 errors, 0 warnings, 0 notes.

## Decisions

## Review
