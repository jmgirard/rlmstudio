# M049: A chat call aborts on a reply from a different model

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP6
- **Resolves:** —
- **Surface tier:** user-facing — the return and conditions of exported chat functions
- **Branch/PR:** m049-chat-model-mismatch

## Goal

If the server cannot serve the model asked for, `lms_chat_openai()`, `lms_chat_openresponses()`, and
`lms_chat_batch()` abort.

## Scope

**In:** a check of the `model` field of each status-200 reply on `/v1/chat/completions` and `/v1/responses`. A name
that differs from the asked name starts a model-list lookup. A new condition class `rlmstudio_model_mismatch`. A `code` field on
`rlmstudio_api_error` from the two functions. Two new batch stops. Help pages, NEWS, recorded replies, and the
decision D-025.
The probe ran on LM Studio 0.4.25+1 on 2026-09-28 with google/gemma-3-1b and an embedding model loaded. With one
chat model loaded, both routes answered an unknown name such as `"not-a-model"` with status 200 and a reply from
google/gemma-3-1b. With two chat models loaded, the same request got status 400 and `error.code`
`"model_not_found"`. A model key matched in any letter case, and an instance id did not. A model loaded under the
id `my-qwen` and asked for by its key `qwen/qwen3-4b-2507` answered with `model` `"my-qwen"`. A downloaded model
that was not loaded was loaded by the request, and the reply named it. `/api/v1/chat` answered 404 for an unknown
name.

**Out:** `lms_chat_native()`, because `/api/v1/chat` already answers 404, which stops a batch. `lms_embed()`
with a model name that the server does not know goes to a candidate row, because no probe covered it. A check
before each request was rejected at the gate (work log).

## Acceptance criteria

- [x] AC1: `lms_chat_openai()` and `lms_chat_openresponses()` read the `model` field of each status-200 reply.
      For a reply from a model other than the one asked for, they abort with the condition class
      `rlmstudio_model_mismatch`. The rule in AC2 decides which names match. The condition also has the class
      `rlmstudio_bad_response`. It carries the asked name in a `model` field and the reply's name in a
      `reply_model` field, and the message names both. The message gives no hint to call again with
      `simplify = FALSE`. The check runs before the reply is read, with either setting of `simplify`. Tests fire
      the abort on each function with both settings of `simplify` in three cases. The first case is a recorded
      reply to an unknown model name. The second and third are mocked, because a live server does not produce
      them. In the second, the asked name differs in letter case only from the key of model X, and an instance of
      model Y answers. In the third, the asked name is the instance id of model X, and an instance of model Y
      answers. Further tests fire the abort on both functions with `logprobs = TRUE`, and on `lms_chat_openai()`
      with a `schema`. One test fires it on a mismatched reply that holds no answer text. Two tests fire it
      through `lms_chat()`, on the default route and on `api_type = "openai"`.
- [x] AC2: The two functions accept a reply with no abort in each of four cases. A test covers each case on both
      functions with both settings of `simplify`.
      (a) The reply's `model` equals the asked name. The call sends no request after the chat request.
      (b) The asked name differs in letter case only from the key of the model whose loaded instance answered.
      The call sends exactly one model-list request after the chat request.
      (c) The asked name is the key of a model whose loaded instance has another id. The call sends exactly one
      model-list request after the chat request.
      (d) The reply has no `model` field, or its `model` is not one string, or is a blank string. The call sends
      no request after the chat request.
- [x] AC3: If the model-list lookup fails, the chat call raises the condition of that failure with the label of
      the chat function. The message says that the model-list lookup failed. A list reply with a status other
      than 200 raises `rlmstudio_api_error` with that status and the `code` field of AC5. A list body that does
      not parse, or that fails the checks of `list_models()`, raises `rlmstudio_bad_response`. A lookup that
      cannot reach the server raises `rlmstudio_no_server`. The lookup sends the token of the call to
      `api/v1/models` on the same host and prints no message. Tests cover a 401 list reply, a list body that
      does not parse, a list body that fails a `list_models()` check, and a lost server. A test asserts the
      host, path, and `Authorization` header of the lookup, and that it prints nothing.
- [x] AC4: `lms_chat_batch()` aborts at the first input that raises `rlmstudio_model_mismatch`, on the
      `"openai"` and `"openresponses"` routes. The condition carries a `results` field by the rule that status
      404 follows. The call sends no request after the model-list request of the failed input. Mocked tests
      cover each route in each of the three formats. Each runs a good input, then a mismatched one, then a
      third. It asserts the class, that the first slot of `results` holds the good reply, and the request count.
- [x] AC5: An `rlmstudio_api_error` from `lms_chat_openai()` or `lms_chat_openresponses()` carries a `code`
      field. The field holds the string at `error.code` of the reply body. For a body with no such string, the
      field is `NULL`. `lms_chat_batch()` aborts with the `results` field at such a condition of status 400 whose
      `code` is `"model_not_found"`. A 400 whose `code` is another string or `NULL` still fails its own input
      alone. On both routes, a recorded `model_not_found` reply is tested as a single call, for the `code`, and
      as a batch, for the abort. Mocked tests on both routes cover three other 400 bodies. One has another code,
      one has an `error` object with no code, and one has an `error` that is a string.
- [x] AC6: The help pages of `lms_chat_openai()`, `lms_chat_openresponses()`, `lms_chat()`, and
      `lms_chat_batch()` state the model check, its model-list lookup, and the two batch stops. The
      `rlmstudio-conditions` page documents the class `rlmstudio_model_mismatch` with its `model` and
      `reply_model` fields. It also documents the `code` field of `rlmstudio_api_error`. The pages say that
      `lms_chat_native()` is not checked. They also say that a model unloaded between the reply and the lookup
      makes the call abort. `NEWS.md` has an entry for the change.
- [x] AC7: `devtools::test()` and `devtools::check()` pass with 0 errors and 0 warnings, and
      `devtools::document()` leaves no diff.

## Coverage

- AC1 → T1, T3
- AC2 → T1, T3
- AC3 → T3
- AC4 → T4
- AC5 → T1, T2, T4
- AC6 → T5
- AC7 → T6

## Tasks

- [x] T1: Record the probe facts from Scope in `cairn/references/lmstudio-api-surface.md` as a dated observation
      under the features of endpoints the package calls. Add `data-raw/record-model-mismatch-cassette.R`, in the
      form of `data-raw/record-cutoff-cassette.R`. It records four cases on both routes, each with its model-list
      reply. The cases are an unknown name with one chat model loaded, and a name in other letter case. The
      others are a key asked for a model loaded under another id, and an unknown name with two chat models loaded. The script restores the loaded
      models in the `finally` clause of a `tryCatch()` (LESSONS, M017).
- [x] T2: Add the `code` field to `rlm_abort_api()` in `R/utils-api-error.R:86`, read with `[[` by exact name
      (LESSONS, M018). Tests first, on both routes, for the four bodies that AC5 names.
- [x] T3: Add the model check to `R/chat.R`. Call it in `lms_chat_openai()` and `lms_chat_openresponses()` after
      `parse_ok_body()` and before the `simplify` branch. The lookup reads `key` and `loaded_instances[].id` of every
      model type from `/api/v1/models` through the `list_models()` checks, with no message. The abort goes through
      `rlm_abort_bad_response()` with its own hint and both classes. On the OpenAI route it also carries the
      `content` and `finish_reason` fields. Tests first for AC1, AC2, and AC3. Count requests with the shared
      recorder or a counter around playback, because httptest2 playback does not count two equal requests
      (LESSONS, M008). Delete the call in a scratch copy and see the tests fail (LESSONS, M003).
- [x] T4: In `lms_chat_batch()`, abort with results at `rlmstudio_model_mismatch`, with a class test inside the
      `rlmstudio_bad_response` handler. Extend `keep_or_abort_api()` to a 400 whose `code` is `"model_not_found"`. Tests
      first for AC4 and the batch part of AC5.
- [x] T5: Write the help text that AC6 names, against the T1 record, and the NEWS entry. Run
      `devtools::document()`.
- [x] T6: Run `devtools::test()`. Then run `devtools::check()` with `RLMSTUDIO_API_TOKEN` set and the server
      started (LESSONS, M009).

## Work log

- 2026-09-28: created by /milestone-plan.
- 2026-09-28: criteria audit (full) by a fresh [O] reader returned 5 criterion findings and 9 rule gaps on the first draft. After the gate, a second read returned 11 more. All were fixed before the commit. Among them are the hint, one test per abort branch, exact request counts, the lookup failures, and the good-input-first batch tests.
- 2026-09-28: plan gate chose an abort with a new class and a batch stop over an abort that fails each input alone, and over a warning. The wrong model answers every input, and a warned scoring batch keeps wrong answers. Falsified by a user who needs the substituted reply.
- 2026-09-28: plan gate chose a model-list lookup on a name difference over a string compare, and over a lookup before every request. The compare aborts every call to a model loaded under another id, and the pre-check doubles batch requests. Falsified by a reply whose `model` is not the id of the answering instance.
- 2026-09-28: plan gate chose the check with either setting of `simplify` over `simplify = TRUE` only. The data-frame batch reads bodies with `simplify = FALSE`. Falsified by a user who needs the raw body of a substituted reply.
- 2026-09-28: plan decided, with no question, that a reply with no `model` string skips the check. Every mocked chat body in the tests has no `model` field. Falsified by a live reply from another model that has no `model` field.
- 2026-09-28: implement started on branch m049-chat-model-mismatch. Question gate skipped, because the plan left no choice open.
- 2026-09-28: T1 done. The recorder wrote four cases on both routes into `tests/testthat/model_mismatch_live/`, and each reply matched the Scope probe. The reference page records the facts as a dated observation. The server was off at the first run and was started with `lms server start`.
- 2026-09-28: T2 done. `rlm_abort_api()` sets `code` from the new `api_error_code()` on every API error. The new tests in `test-model-check.R` failed on the missing field before the change, and the suite passes after it.
- 2026-09-28: T3 done. `check_reply_model()` and `reply_model_serves()` in `R/chat.R`, and `request_model_list()` in `R/list.R`, which `list_models()` now calls. A failed lookup opens its message with "<label>, because the model-list lookup failed". In scratch copies, deleting the call on either route turned 13 or 14 of the 18 tests red, and an exact-case key compare turned the recorded letter-case test red. Suite passes.
- 2026-09-28: minor amendment to T4. A separate `rlmstudio_model_mismatch` handler before the `rlmstudio_bad_response` one does not abort. `tryCatch()` runs a handler inside the handlers named after it, so the re-raised condition was kept as a failed input. The class test now sits inside the `rlmstudio_bad_response` handler.
- 2026-09-28: T4 done. `keep_or_abort_bad()` aborts at a mismatch, and `keep_or_abort_api()` aborts at a 400 whose `code` is `"model_not_found"`. Both stop tests failed before the change, and the keep-going control passed before and after it. Suite passes.
- 2026-09-28: T5 done. A new "Reply from another model" section on `rlmstudio-conditions`, inherited by the four chat pages, plus the `code` field, the batch stops, the alias, and two NEWS entries. `devtools::document()` rewrote every page that inherits the changed sections. Suite passes.
- 2026-09-28: T6 done. The first `devtools::check()` gave a NOTE for four recorded paths over 100 bytes, so the cassette directory is now `tests/testthat/mismatch_live/` (longest path 98 bytes). The second check gave 0 errors, 0 warnings, 0 notes. `devtools::test()` passes, and `devtools::document()` leaves no diff. The check left the server off, and it was started again.
- 2026-09-28: claim audit: 68 claims read, 4 corrected — NEWS.md, R/chat.R, data-raw/record-model-mismatch-cassette.R
- 2026-09-28: the claim audit narrowed "two or more chat models" to the two that the probe loaded, in NEWS and a code comment. D-025 keeps "two or more", because DECISIONS is history.
- 2026-09-28: review checkpoint: evidence recorded and AC1 to AC7 ticked, consistency gate passed. Three fresh reviewers are running, and triage is still owed.

## Decisions

## Review

Evidence run 2026-09-28 on branch head 1691e51, which contains `origin/main`. `test-model-check.R` passed with 0
failures. The full `devtools::test()` ran 485 tests with 0 failed, 0 errors, 0 skipped.

- AC1: `test-model-check.R` lines 176 to 305 pass. Three cases abort on both routes with both settings of
  `simplify`. They are the recorded unknown name, a mocked key in other letter case, and a mocked instance id.
  `expect_mismatch()` asserts both classes, the `model` and `reply_model` fields, and status 200. It also asserts
  both names in the message and no "simplify" in it. Other tests fire the abort with `logprobs = TRUE` on both
  routes and with a `schema` on the OpenAI route. One fires it on a reply with no answer text on both routes. Two
  fire it through `lms_chat()`, on the default route and on `api_type = "openai"`.
- AC2: `test-model-check.R` lines 307 to 384 pass on both routes with both settings of `simplify`. In case (a) the
  mocked recorder holds 1 request. Cases (b) and (c) play the recorded `case` and `alias` replies. A log around
  `httr2::req_perform()` holds 2 URLs, and the second is `http://localhost:1234/api/v1/models`. Case (d) covers a
  missing `model`, JSON `null`, a number, an array, an empty string, and a whitespace string. Each sends 1 request.
- AC3: `test-model-check.R` lines 402 to 496 pass on both routes. A 401 list reply raises `rlmstudio_api_error`
  with status 401 and `code` `"bad_token"`. A body that does not parse and a body with `"models": 5` raise
  `rlmstudio_bad_response` without the mismatch class. A second server probe that fails raises
  `rlmstudio_no_server`. Each message holds "<label>, because the model-list lookup failed:". A lookup to
  `http://example.com:9999` is a GET of `/api/v1/models` on that host with `Bearer lookup-token`, under
  `expect_silent()`.
- AC4: `test-model-check.R` lines 505 to 531 pass on both routes in the formats `vector`, `list`, and
  `data.frame`. Each batch runs a good input, a mismatched input, and a third. It aborts with
  `rlmstudio_model_mismatch` and `rlmstudio_bad_response`, `results` is `list("reply", NULL, NULL)`, and the
  recorder holds 3 requests. In `R/chat.R` the mismatch and a 404 both go through `abort_with_results()`.
- AC5: `test-model-check.R` lines 57 to 87 and 533 to 587 pass on both routes. The recorded `not_found` reply gives
  status 400 and `code` `"model_not_found"` as a single call. As a batch it aborts with `results` `list(NULL, NULL)`
  after 1 request. Three mocked 400 bodies hold the code `"E42"`, an `error` object with no code, and a string
  `error`. They give `code` `"E42"`, `NULL`, and `NULL`. In a batch each of them fails its own input alone. The batch sends 3
  requests and warns "1 input failed".
- AC6: `man/rlmstudio-conditions.Rd` has a "Reply from another model" section. It states the model check, the
  model-list lookup, the `model` and `reply_model` fields, and the two batch stops. It says that `lms_chat_native()`
  does not check the reply and that an instance unloaded before the lookup makes the call abort. The "API failure"
  section documents the `code` field. The four chat pages inherit these sections. A grep finds
  `rlmstudio_model_mismatch`, `reply_model`, `model_not_found`, and the unload sentence in each of them.
- AC7: `devtools::test()` ran 485 tests with 0 failed and 0 errors. `devtools::check()` with the API token set gave
  0 errors, 0 warnings, and 0 notes. `devtools::document()` left `git status` clean. The check left the server off,
  and `lms server start` started it again.

Consistency gate: `cairn_validate.py` passed. No DESIGN.md principle changed, so `cairn_impact` did not run.
`devtools::document()` left no diff, and `pkgdown::check_pkgdown()` found no problems. `NEWS.md` has entries. The
branch adds no top-level file, and `data-raw/` is in `.Rbuildignore`. README is not touched. `NEWS.md` has two entries under the development version.
