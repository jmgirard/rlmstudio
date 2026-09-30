# M058: Continue a chat thread by its reply id

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP4
- **Resolves:** —
- **Surface tier:** user-facing — it adds an exported argument and changes the value that exported chat functions return
- **Branch/PR:** m058-chat-thread-id

## Goal

A user continues a stored LM Studio chat thread from R on the native and
OpenResponses routes, with no parse of the raw reply body.

## Scope

**In:** The candidate row on stateful chat, taken whole. A named
`previous_response_id` on `lms_chat_native()`, `lms_chat_openresponses()`,
and `lms_chat()`, checked before the server probe (D-008). A route refusal
on the OpenAI route of `lms_chat()` and `lms_chat_batch()`. A
`response_id` attribute on the simplified value of the two thread routes.
Recorded live fixtures, help text, and NEWS. D-030 records the choices.

**Out:** A named `store` argument and a batch stop at an unknown id each
keep a new candidate row. `/v1/chat/completions` has no thread, so the
OpenAI route gets no argument. A shortened name in `...`, such as
`previous`, goes to the server unchecked (D-003). Structured output on
`/v1/responses` keeps its own candidate row.

## Acceptance criteria

- [ ] AC1: `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat()` take a named
      argument `previous_response_id`, placed after `...` with the default `NULL`. A string
      value reaches the request body as the JSON string field `previous_response_id`, and
      `NULL` leaves the field out. This holds for the two functions called directly. It holds
      for `lms_chat()` on its native and OpenResponses routes. It holds for `lms_chat_batch()`
      with the value in `...` on those two routes.
- [ ] AC2: `lms_chat_native()`, `lms_chat_openresponses()`, `lms_chat()`, and `lms_chat_batch()`
      each abort on each of these `previous_response_id` values: `NA_character_`, `""`, `" "`,
      `c("a", "b")`, `character(0)`, and `1`. The abort has no condition class, and its message
      names `previous_response_id`. It comes before the check for a running server and before
      any request. `"resp_1"` and `NULL` pass. With `api_type = "openai"`, `lms_chat()` and
      `lms_chat_batch()` abort the same way on `"resp_1"`. The message names the native and
      OpenResponses routes as the ones that accept it. `NULL` passes on all three routes. A
      shortened name, such as `previous = 1`, is not checked and reaches the body under that name.
- [ ] AC3: Take `lms_chat_native()` and `lms_chat_openresponses()` with `simplify = TRUE`.
      If the reply holds its id as one string, the value they return carries the id in an
      attribute `response_id`. The id is the `response_id` field of a native reply and the
      `id` field of an OpenResponses reply. An empty string counts as one string. For an
      `lms_chat_result`, the attribute is on the object. If the field is absent, `null`, a
      number, or an array, the value has no `response_id` attribute. Tests probe each function
      with each of those reply shapes. The OpenResponses probes run with `logprobs = FALSE`.
      They also run with `logprobs = TRUE`, both with and without a part that carries logprobs. `lms_chat()` returns the attribute on its native and OpenResponses routes.
      `lms_chat_openai()`, and every call with `simplify = FALSE`, return values with no
      `response_id` attribute. With the attribute removed, each value is `identical()` to what
      the same function at 30a743e returns for the same reply body. The review checks this by
      running the 30a743e functions over the reply bodies of these tests.
- [ ] AC4: `lms_chat_batch()` keeps the attribute on each reply in a `format = "list"`
      result. It keeps it in the list that `format = "vector"` returns with `logprobs = TRUE`. A
      `format = "vector"` character vector and the `output` column of a `format = "data.frame"`
      result carry no `response_id` attribute. The `response_id` column of the data frame keeps
      its values and type.
- [ ] AC5: For an id the server does not hold, `lms_chat_native()` and
      `lms_chat_openresponses()` raise `rlmstudio_api_error` with status 400. Its `code` field
      holds `"invalid_value"` on the native route and `"previous_response_not_found"` on the
      OpenResponses route. On each of the two routes, `lms_chat_batch()` keeps going past such
      a reply. The slot of that input holds the `rlmstudio_api_error`, and the next input is
      sent. The tests replay the two reply bodies recorded from a live LM Studio into fixture
      files.
- [ ] AC6: The help pages of `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat()`
      state what `previous_response_id` accepts, and that only the exact name is checked. They
      state the route rule of AC2 and the `response_id` attribute of AC3, with the reply field
      it comes from. They state that an OpenResponses reply sent with `store = FALSE` still
      carries an id, and that a native one carries none. The help of `lms_chat_batch()` states
      which formats keep the attribute (AC4), and that an unknown id fails its input alone
      (AC5). NEWS.md gains one entry under the development version that names the argument and
      the attribute. It says that a simplified reply with an id now prints an
      `attr(,"response_id")` line. It says that `identical()` of such a reply and a plain
      string returns `FALSE`. `devtools::document()` leaves no diff.
- [ ] AC7: `devtools::test()` reports no failure. `devtools::check()` gives 0 errors and 0
      warnings, and no note whose heading the check of 30a743e does not give.

## Coverage

- AC1 → T1
- AC2 → T1, T6
- AC3 → T2, T6
- AC4 → T3
- AC5 → T3, T4
- AC6 → T5
- AC7 → T7

## Tasks

- [x] T1: The argument and its checks. Add `previous_response_id = NULL` after `...` in
      `lms_chat()` (`R/chat.R:64`), `lms_chat_openresponses()` (`R/chat.R:196`), and
      `lms_chat_native()` (`R/chat.R:1192`). Check it above `stop_if_no_server()`, with a
      `NULL` allowance on `rlm_check_id()` (`R/utils-args.R:12`) or a sibling check whose
      message names a response id. Add a route check beside `rlm_check_ttl_route()`
      (`R/utils-args.R:302`). In `lms_chat_batch()`, read the value from `rlm_chat_dots()`
      and run both checks before its probe (M017 lesson). If the value is not `NULL`, put the
      field in the body. Tests go in a new `tests/testthat/test-thread.R`, one `test_that()` block per
      function. Read sent bodies through `local_request_recorder()` (M004 and M008 lessons).
      Stubs for the probe and the request count their calls (M015 lesson). Stub the delegates
      of `lms_chat()`, so its own checks are the ones under test (M003 and M013 lessons).
- [x] T2: The attribute. Set it in the `simplify = TRUE` branch of the two exported
      functions (`R/chat.R:238-241` and `R/chat.R:1238-1241`). Do not set it in the shared
      readers `native_reply_text()` and `responses_reply_value()`, so the data-frame batch
      stays as it is. Read the id with `[[` (M018 lesson). Test the AC3 reply shapes with bodies from
      `helper-chat-bodies.R`. Update existing tests that compare a whole reply with
      `identical()`.
- [x] T3: The batch. Test the AC4 formats and the AC5 batch case on both routes, with a
      two-input batch whose first reply is the unknown-id 400.
- [x] T4: Live fixtures. Add `data-raw/record-thread-cassette.R` in the form of
      `data-raw/record-model-mismatch-cassette.R`. It records a native reply with an id and a
      continued OpenResponses reply. It records a native reply and an OpenResponses reply sent
      with `store = false`. It records the two unknown-id 400 bodies. Clean up in `finally` (M017
      lesson), and restore the server and model state. Add the AC5 single-call tests over the
      400 fixtures.
- [ ] T5: Help text for `previous_response_id` and the attribute on the three pages, the
      batch help of AC6, and one NEWS entry. Run `devtools::document()`.
- [ ] T6: Planted defects. In a scratch copy, delete one site at a time. The sites are the
      body-field line, the attribute line, the value check, the `NULL` allowance, the route
      check, and the batch early check. Each one turns its own tests red and leaves the others green.
- [ ] T7: Run `devtools::check()` on a `git archive` of 30a743e and record its note headings.
      Then run `devtools::test()` and `devtools::check()` on the branch, with
      `RLMSTUDIO_API_TOKEN` set (M009 lesson).

## Work log

- 2026-09-29: created by /milestone-plan. It absorbs the ROADMAP candidate row on stateful chat.
- 2026-09-29: live probe with google/gemma-3-1b. `/api/v1/chat` and `/v1/responses` each continued a thread from `previous_response_id`, and a native id worked on `/v1/responses`. `/v1/chat/completions` returned 200 and ignored the field. A native reply sent with `store: false` had no `response_id`, and an OpenResponses one had an `id`. An unknown id gave 400 with code `"invalid_value"` (native) and `"previous_response_not_found"` (OpenResponses). Server and model state restored.
- 2026-09-29: criteria audit ran in full mode (fresh Opus reader). It returned 20 findings, each with one clear fix. All were applied before the gate. The fixes touch AC1 scope, the AC2 route rule and shortened name, and the AC3 reply shapes and unchanged values. They add AC4, the AC5 batch case and fixtures, and the AC6 required sentences. They add the AC7 note headings and a planted defect per check site in T6.
- 2026-09-29: plan gate chose a `response_id` attribute over a new reply class. A classed string can fail to combine with plain strings in a batch pipeline (GP2). It also rejected the id through `simplify = FALSE` alone, because a thread then needs a parse of the raw reply. Falsified by a user report that the printed attribute line costs more than a class.
- 2026-09-29: plan gate chose both thread routes over the native route alone, because both continued a thread live. Falsified by an LM Studio release where `/v1/responses` drops `previous_response_id`.
- 2026-09-29: plan gate kept the D-019 rule for a batch with an unknown id over a stop. The two routes answer with different codes, and the condition carries no `param`. Falsified by a user batch that sends every input to an unknown id.
- 2026-09-29: implement started on m058-chat-thread-id. No question gate, because the plan leaves no choice open.
- 2026-09-29: T1 done. `rlm_check_response_id()` and `rlm_check_thread_route()` in `R/utils-args.R`, the argument on the three functions, the batch checks, and `tests/testthat/test-thread.R`. `local_counting_probe()` moved to `helper-mock-http.R` so the new file can use it. Full suite 0 failures, 3 live skips.
- 2026-09-29: T2 done. `with_response_id()` in `R/chat.R` sets the attribute and forces the reply reader first, because a lazy `[[` read of the id failed with a base R error on a bare-value body before the reader could abort. Six tests in four files that compared a whole reply were updated, and `without_response_id()` was added to `helper-chat-bodies.R`. Full suite 0 failures, 3 live skips.
- 2026-09-29: minor amendment. T3 and T4 land in one commit, because the T3 batch case replays the unknown-id bodies that T4 records.
- 2026-09-29: T4 done. `data-raw/record-thread-cassette.R` recorded six calls into `tests/testthat/thread_live/` from google/gemma-3-1b on LM Studio 0.4.25+1. All seven script checks passed. The server and model state were restored, and no token is in the files.
- 2026-09-29: T3 done. `test-thread.R` covers the list, vector, logprobs vector, and data-frame formats on both routes. It covers the recorded thread chain, the recorded `store = FALSE` replies, and the unknown-id cases for the single calls and the batch. Full suite 0 failures, 3 live skips.

## Decisions
