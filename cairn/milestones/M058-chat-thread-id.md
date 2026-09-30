# M058: Continue a chat thread by its reply id

- **Status:** review
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

- [x] AC1: `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat()` take a named
      argument `previous_response_id`, placed after `...` with the default `NULL`. A string
      value reaches the request body as the JSON string field `previous_response_id`, and
      `NULL` leaves the field out. This holds for the two functions called directly. It holds
      for `lms_chat()` on its native and OpenResponses routes. It holds for `lms_chat_batch()`
      with the value in `...` on those two routes.
- [x] AC2: `lms_chat_native()`, `lms_chat_openresponses()`, `lms_chat()`, and `lms_chat_batch()`
      each abort on each of these `previous_response_id` values: `NA_character_`, `""`, `" "`,
      `c("a", "b")`, `character(0)`, and `1`. The abort has no condition class, and its message
      names `previous_response_id`. It comes before the check for a running server and before
      any request. `"resp_1"` and `NULL` pass. With `api_type = "openai"`, `lms_chat()` and
      `lms_chat_batch()` abort the same way on `"resp_1"`. The message names the native and
      OpenResponses routes as the ones that accept it. `NULL` passes on all three routes. A
      shortened name, such as `previous = 1`, is not checked and reaches the body under that name.
- [x] AC3: Take `lms_chat_native()` and `lms_chat_openresponses()` with `simplify = TRUE`.
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
- [x] AC4: `lms_chat_batch()` keeps the attribute on each reply in a `format = "list"`
      result. It keeps it in the list that `format = "vector"` returns with `logprobs = TRUE`. A
      `format = "vector"` character vector and the `output` column of a `format = "data.frame"`
      result carry no `response_id` attribute. The `response_id` column of the data frame keeps
      its values and type.
- [x] AC5: For an id the server does not hold, `lms_chat_native()` and
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
- [x] AC7: `devtools::test()` reports no failure. `devtools::check()` gives 0 errors and 0
      warnings, and no note whose heading the check of 30a743e does not give.

## Coverage

- AC1 → T1
- AC2 → T1, T6
- AC3 → T2, T6
- AC4 → T3
- AC5 → T3, T4
- AC6 → T5, T8
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
- [x] T5: Help text for `previous_response_id` and the attribute on the three pages, the
      batch help of AC6, and one NEWS entry. Run `devtools::document()`.
- [x] T6: Planted defects. In a scratch copy, delete one site at a time. The sites are the
      body-field line, the attribute line, the value check, the `NULL` allowance, the route
      check, and the batch early check. Each one turns its own tests red and leaves the others green.
- [x] T7: Run `devtools::check()` on a `git archive` of 30a743e and record its note headings.
      Then run `devtools::test()` and `devtools::check()` on the branch, with
      `RLMSTUDIO_API_TOKEN` set (M009 lesson).
- [x] T8: Review return 1. On the `lms_chat_native()` page, state that the attribute of
      `lms_chat_openresponses()` comes from the `id` field and that its `store = FALSE` reply
      still carries one. On the `lms_chat_openresponses()` page, state the native field and
      that a native `store = FALSE` reply carries none. Run `devtools::document()`.

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
- 2026-09-29: T5 done. Help text on the four pages and one NEWS entry. The print line and the `identical()` result in NEWS were read from an R run. The `store = FALSE` claims rest on the recorded replies. A second `devtools::document()` run left no diff.
- 2026-09-29: T6 done. A scratch copy took ten plants, one at a time, and ran the 33 blocks of `test-thread.R`. The control had 0 red blocks. The body field of the native route turned 4 blocks red, and that of the OpenResponses route 5. The attribute line turned 8 red. Each of the five value and route checks turned only its own block red. The `NULL` allowance turned 25 red, because every call that leaves the argument out passes `NULL` through it.
- 2026-09-29: T7 done. `devtools::check()` on a `git archive` of 30a743e gave 0 errors, 0 warnings, and 0 notes. On the branch at 85cbdb3 it gave the same. `devtools::test()` with `RLMSTUDIO_API_TOKEN` set gave 0 failures and 3 live skips, because the server was not running. The server and model state were the same after both checks.
- 2026-09-29: claim audit: 131 claims read, 8 corrected — NEWS.md, R/chat.R, data-raw/record-thread-cassette.R, tests/testthat/test-thread.R
- 2026-09-29: the claim audit found 14 testthat failure files in `tests/testthat/_problems/` that the T2 commit took in. They are removed, and `.gitignore` and `.Rbuildignore` now exclude that folder. After these fixes, the full suite gave 0 failures and 3 live skips.
- 2026-09-29: review return 1 (defect). AC6 fails as written: `man/lms_chat_native.Rd` omits the OpenResponses `store = FALSE` fact and the `id` field, and `man/lms_chat_openresponses.Rd` omits the native ones. AC1 to AC5 and AC7 passed.
- 2026-09-29: implement resumed after review return 1. Minor amendment: T8 added for the AC6 fix, and Coverage now maps AC6 to T5 and T8. No question gate, because the return names the fix.
- 2026-09-29: T8 done. Two sentences each on the `lms_chat_native()` and `lms_chat_openresponses()` pages give the other route's reply field and `store = FALSE` fact. A second `devtools::document()` run left no diff. Full suite 0 failures, 3 live skips.
- 2026-09-29: claim audit: 6 claims read, 0 corrected — R/chat.R
- 2026-09-29: status review.

## Decisions

## Review

Pass 1, 2026-09-29, on 22013ee. The default branch had not moved (origin/main at d3d3849, the merge base).

- AC1: `devtools::test()` ran the four `sends previous_response_id` blocks and the four `shortened name` blocks of `test-thread.R` with 0 failures. The string reached the body of each direct call, of `lms_chat()` on both thread routes, and of both batch requests on both routes. `NULL` and no argument left the field out.
- AC2: the four `aborts on a previous_response_id` blocks passed. So did the four `passes a string and NULL` blocks and the two `refuses previous_response_id on the openai route` blocks. They cover the six bad values on each function and route, with no package class and the argument named. They count 0 probe and delegate calls, and `NULL` passes on all three routes.
- AC3: a scratch script ran 63 calls over the AC3 reply shapes against mocked 200 bodies. It ran them once with the package at 30a743e (`git archive`) and once on the branch. The branch set `response_id` for a string and for an empty string. It set none for an absent field, `null`, a number, or an array. It set none for `simplify = FALSE` and none on the OpenAI route. With the attribute removed, all 63 values were `identical()` to the 30a743e values. No 30a743e value had the attribute. The calls covered `lms_chat_native()` and `lms_chat()` on its three routes. They covered `lms_chat_openresponses()` with `logprobs = FALSE`, and with `logprobs = TRUE` both with and without a logprobs part.
- AC4: the four batch-format blocks of `test-thread.R` passed. List replies and logprobs-vector replies keep the ids. The character vector and the `output` column have none. The `response_id` column holds `c("resp_a", "resp_b")`.
- AC5: the two recorded unknown-id blocks passed with status 400 and codes `"invalid_value"` and `"previous_response_not_found"`. On each route, the batch block sent the second input after the recorded 400 and stored the `rlmstudio_api_error` in slot 1. The two `.R` fixtures hold those codes with `param` `previous_response_id`. No fixture holds a token.
- AC6: fails as written. The criterion requires that three pages state two `store = FALSE` facts. An OpenResponses reply still carries an id, and a native one carries none. The three pages are those of `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat()`. `man/lms_chat.Rd` states both facts. `man/lms_chat_native.Rd` states only the native fact, and `man/lms_chat_openresponses.Rd` states only the OpenResponses fact. The same holds for the reply field of the attribute. Each single-route page names only its own field. The batch help and the NEWS entry meet the criterion. An R run printed the `attr(,"response_id")` line, and `identical()` returned `FALSE`.
- AC7: `devtools::test()` with `RLMSTUDIO_API_TOKEN` set gave 0 failures and 3 live skips, because the server was not running. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, so no note heading is new against 30a743e. The server and model state were the same after both runs.
- Gate: `cairn_validate.py` passed with exit 0. `devtools::document()` left no diff. `pkgdown::check_pkgdown()` found no problems. NEWS.md has the entry. README.Rmd is unchanged on the branch. The one new ignore entry is `^tests/testthat/_problems$`, and the check gave no note.
- Result: returned to `in-progress` on AC6 alone. The step-5 review did not run.
