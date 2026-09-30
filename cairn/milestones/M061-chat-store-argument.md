# M061: A named store argument on the thread chat routes

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Surface tier:** user-facing — it adds a checked argument to four exported functions.
- **Branch/PR:** m061-chat-store-argument

## Goal

A user turns off the storage of chat replies from R with a checked `store` argument on the native and OpenResponses routes, in one call and in a batch.

## Scope

**In:**
- A `store` argument after `...` on `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()`, beside `previous_response_id`. `lms_chat_batch()` takes it in `...` and checks it before the first call, as it checks `previous_response_id`.
- The value is `NULL`, the default, or a flag. `NULL` sends no field, so the server default applies. The server stores every reply for 30 days by default.
- `lms_chat()` and `lms_chat_batch()` abort on a `store` with `api_type = "openai"`, as they do for `previous_response_id`.
- A live probe of how each endpoint treats `store`. Help, NEWS.md, the R/conditions.R fault list, one D-entry, and tests.

**Out:**
- `store` on `lms_chat_openai()`. The candidate row does not name it, and a `store` in its `...` still goes to the server unchecked (D-003). If T1 shows that `/v1/chat/completions` keeps replies on `store`, T1 adds a candidate row.
- A batch default of `store = FALSE`. The plan gate kept `NULL`. No row.
- Removing the `response_id` attribute from an OpenResponses reply sent with `store = FALSE`. The plan gate kept the attribute. No row.
- A batch stop at a `previous_response_id` that the server does not hold. It stays its own candidate row.

## Acceptance criteria

- [x] AC1: `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()` take a `store` argument after `...`, with the default `NULL`. On the native and OpenResponses routes, a `store` that `isTRUE()` accepts puts `"store":true` in the request body. A `store` that `isFALSE()` accepts puts `"store":false` there, and `store = NULL` puts no `store` field there. Tests read the serialized request body of each direct function, and of `lms_chat()` on both routes. They do so for `TRUE`, `FALSE`, `NULL`, `c(a = TRUE)`, `matrix(FALSE)`, and `structure(TRUE, class = "foo")`.
- [x] AC2: Take a `store` that is not `NULL` and that neither `isTRUE()` nor `isFALSE()` accepts. It aborts with a message that names `store` and has no condition class. It aborts before the check for a running server and sends no request. This holds for `lms_chat()`, `lms_chat_native()`, `lms_chat_openresponses()`, and a `store` in the `...` of `lms_chat_batch()`. Tests pass `NA`, `NA_character_`, `"yes"`, `1`, `list(TRUE)`, `c(TRUE, FALSE)`, and `logical(0)` to each of the four. They assert the message and that the server check was not called.
- [x] AC3: With `api_type = "openai"`, `lms_chat()` and `lms_chat_batch()` abort on `store = TRUE` and on `store = FALSE`, before the check for a running server. The message names `store` and the two routes that take it, and the abort has no condition class. With `api_type = "openai"`, `store = NULL` passes, and the request body has no `store` field. Tests cover both functions and the three values.
- [x] AC4: `lms_chat_batch()` sends a `store` in its `...` to every call. With three inputs and `store = FALSE`, a test reads `"store":false` in each of the three request bodies, with `format = "data.frame"` on the native route. A second test does the same with `format = "list"` on the OpenResponses route. A third test reads `"store":true` in each body for `store = TRUE`. Two `store` values in its `...` abort with the message that names the argument, as two `previous_response_id` values do. A test asserts that message.
- [x] AC5: The help pages of `lms_chat()`, `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat_batch()` document `store`. They state its value rule, its default, and that `NULL` sends no field. The two pages whose function has an `"openai"` route state the abort there. Each page states that only the exact name `store` is checked, so a shortened name such as `sto` goes into the request body unchecked. Take each route of a page's function that takes `store`. The page states what the T1 probe showed about the reply id of a reply sent there with `store = FALSE`. No sentence on the pages of `lms_chat()`, `lms_chat_native()`, or `lms_chat_openresponses()` describes `store` as a field of `...`. The `lms_chat_batch()` page states that a `store` in its `...` goes to `lms_chat()` and is checked there. After `devtools::document()`, neither search below finds a line:

      grep -rnF 'store = FALSE` in `...`' R/
      grep -rnF 'store = FALSE} in \code{...}' man/

- [x] AC6: NEWS.md has one entry for `store`. It names the four functions and states the value rule, that `NULL` sends no field, and the `"openai"` route abort in `lms_chat()` and `lms_chat_batch()`. It also states that before, a `store` in `...` went to the server unchecked on every route, the `"openai"` route included. It states that `lms_chat_openai()` still sends a `store` in `...` to the server unchecked.
- [x] AC7: `devtools::test()` reports 0 failures and 0 errors. `devtools::check()`, run with `RLMSTUDIO_API_TOKEN` set, reports 0 errors and 0 warnings.

## Coverage

- AC1 → T2, T3
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T2, T3
- AC5 → T1, T4
- AC6 → T5
- AC7 → T5

## Tasks

- [x] T1: Probe a running LM Studio, with the token set and a small model loaded, and record its version. Send `store` as `true` and `false` to `/api/v1/chat` and `/v1/responses`, and record whether each reply carries an id. Continue from the id of a `store: false` reply on each route, and record the status and `code`. Send `store` as `true` and `false` to `/v1/chat/completions`, and record the status. Write the facts, with the version and the date, into the "Stateful chat" bullet of cairn/references/lmstudio-api-surface.md. Restore the server and model state that you found (M009 lesson).
- [x] T2: Write the AC1 to AC4 tests first with the request recorder of tests/testthat/helper-mock-http.R, and see them red on main. Read the sent bytes, not a parsed body (M004 lesson). In the batch tests, count calls to the server check, because `lms_chat_batch()` reaches `lms_chat()` (M003 lesson).
- [x] T3: Add `store = NULL` after `...` in the three functions. Check it with `rlm_check_flag(store, "store", null_ok = TRUE)` before `stop_if_no_server()`. If it is not `NULL`, send `isTRUE(store)`, so every accepted form goes out as a plain `true` or `false`. Add a route check beside `rlm_check_thread_route()` (R/utils-args.R:418) and call it in `lms_chat()` and `lms_chat_batch()`. In the batch, check `args[["store"]]` beside `previous_response_id` (R/chat.R:1866). In a scratch copy, remove each check in turn and see a test go red.
- [x] T4: Write the `store` help on the four pages from the T1 facts, and rewrite the sentences that the two AC5 searches find. Add the `store` faults to the fault list in R/conditions.R:15. Run `devtools::document()`.
- [x] T5: Add the NEWS.md entry. Append one D-entry: a named `store` is checked, sent as a plain flag, and refused on the OpenAI route, which narrows D-003 as D-030 did. Set `RLMSTUDIO_API_TOKEN`, then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan from the candidate row for a named `store` argument (M058 plan gate).
- 2026-09-30: criteria audit (full mode, fresh Opus reader), pass 1, returned 8 findings. Seven were fixed without a question. Every accepted form is sent as a plain `true` or `false`. AC2 adds two abort probes, and AC5 adds a `man/` search and the exact-name limit. AC6 adds the "before" text. AC4 adds two batch formats and a `store = TRUE` case. The eighth was a conditional reply-id criterion, which the gate dropped.
- 2026-09-30: plan gate chose the default `NULL` everywhere over a batch default of `store = FALSE`. `NULL` keeps today's behavior. Falsified by a user whose batch with `store` unset fills the server store.
- 2026-09-30: plan gate kept the `response_id` attribute of an OpenResponses reply sent with `store = FALSE`, over its removal. The value then matches the reply and needs no new rule. Falsified by a user who passes such an id and gets the 400.
- 2026-09-30: plan gate chose an abort on the OpenAI route over sending the value, as for `ttl` and `previous_response_id`. Falsified by a `/v1/chat/completions` request whose `store` changes what the server keeps.
- 2026-09-30: criteria audit pass 2 (full mode) on the final wording did not run, because the session permission checker gave no verdict for a subagent. The plan is committed as a checkpoint. Run pass 2 before T2 starts.
- 2026-09-30: criteria audit pass 2 (full mode, new fresh Opus reader) ran on the final wording and returned 4 findings, all fixed without a question. AC5 now exempts the batch page, which takes `store` in `...`, and scopes the reply-id fact to each page's routes. AC6 states that `lms_chat_openai()` still sends `store` unchecked. AC2 adds the probe `logical(0)`.
- 2026-09-30: question gate skipped, because the plan left no choice open. Branch `m061-chat-store-argument` cut from the pushed main.
- 2026-09-30: T1 done on LM Studio 0.4.25+1 with google/gemma-3-1b. A native `store: false` reply has no `response_id`. An OpenResponses `store: false` reply has an `id`, and a continuation from it gives 400 `previous_response_not_found`. `/v1/chat/completions` returns 200 and shows no stored reply, so no candidate row. Facts are in the references "Stateful chat" bullet. Server stopped and model unloaded, as found.
- 2026-09-30: T2 done. tests/testthat/test-store.R has 16 tests. On main, 11 were red. Five passed, because a `store` in `...` already reached the body as a plain flag for `TRUE`, `FALSE`, and `NULL`: the shortened name, the OpenAI `NULL` body, and the three batch-send tests. The repeat-domain test in test-batch-repeated-args.R now lists `store`.
- 2026-09-30: T3 done. `store_field()` sends `isTRUE(store)`, and `rlm_check_store_route()` sits beside `rlm_check_thread_route()`. `store` now comes before the dots in the body, so the request hash of the two recorded `store = FALSE` calls changed. data-raw/record-thread-cassette.R re-recorded tests/testthat/thread_live/ live, and all seven of its checks passed. In a scratch copy, removing each of the 10 new lines turned test-store.R red. `devtools::test()`: 0 failed, 0 errors, 19045 passed.
- 2026-09-30: T4 done. `store` help on the four pages, with the T1 reply-id facts per route, and the three "`store = FALSE` in `...`" sentences rewritten. R/conditions.R lists a bad `store` and a `store` on the `"openai"` route. After `devtools::document()`, both AC5 searches find no line. `devtools::test()`: 0 failed, 0 errors.
- 2026-09-30: T5 done. NEWS.md entry and D-035 added, and a test pins that `lms_chat_openai()` still sends a `store` in `...` unchecked. `devtools::test()`: 0 failed, 0 errors, 19048 passed. `devtools::check()` with `RLMSTUDIO_API_TOKEN` set: 0 errors, 0 warnings, 0 notes, run again after the audit fixes. Server state was the same after each run.
- 2026-09-30: claim audit: 102 claims read, 3 corrected — R/chat.R, tests/testthat/test-store.R. The "previous_response_not_found" sentences on three pages now name the OpenResponses route, and two test comments no longer claim more than the tests show. The same reader re-read the fixes once and narrowed one test comment further.
- 2026-09-30: status set to review.
- 2026-09-30: review: all seven criteria verified, gate clean, 10 findings, none failing a criterion. R1 to R3 fixed at the gate.
- step-7 approval: m061-chat-store-argument approved for merge

## Decisions

## Review

Fresh evidence, 2026-09-30, on branch head 6b0a3bc. main had not moved since the branch was cut. `devtools::test()` in this session: no failed or errored test, 3 live tests skipped because LM Studio was not running.

- AC1: the test-store.R tests "sends store as a plain JSON boolean" passed for `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat()` on both routes. The accepted forms are `TRUE`, `FALSE`, `c(a = TRUE)`, `matrix(FALSE)`, and `structure(TRUE, class = "foo")`. For each, the sent JSON text holds `"store":true` or `"store":false` followed by `,` or `}`. For `NULL` and for no argument, the text holds no `"store"`. The domain test asserts that the three functions take `store` after `...` with the default `NULL`.
- AC2: the four test-store.R tests "aborts on a store that is not a flag" passed. Each passes `NA`, `NA_character_`, `"yes"`, `1`, `list(TRUE)`, `c(TRUE, FALSE)`, and `logical(0)` to its function. `lms_chat()` and `lms_chat_batch()` get each value on all three routes. Each test asserts the message "`store` must be `TRUE`, `FALSE`, or `NULL`." and no `rlmstudio_` class. It asserts 0 calls to the server check, and for `lms_chat()` 0 calls to its three delegates.
- AC3: the test-store.R tests "refuses a store flag on the openai route" for `lms_chat()` and `lms_chat_batch()` passed. For `TRUE` and `FALSE`, each asserts a message that names `store` and the three `api_type` values. Each also asserts no `rlmstudio_` class and 0 calls to the server check. The test "store = NULL on the openai route sends no store field" passed for both functions. Each sent body holds `"messages"` and no `"store"`.
- AC4: three test-store.R batch tests passed with three inputs. A native `"data.frame"` batch and an OpenResponses `"list"` batch with `store = FALSE` each sent `"store":false` in all three bodies. A `"vector"` batch with `store = TRUE` sent `"store":true` in all three bodies on both routes. Each asserts 4 calls to the server check, one for the batch and one per input. The test "two store values in the dots of lms_chat_batch() abort" passed and asserts the message "`store` is given more than once."
- AC5: read in man/ after a fresh `devtools::document()`. All four pages give the value rule, the default `NULL`, that `NULL` sends no field, and the exact-name limit with the example `sto`. `?lms_chat` and `?lms_chat_batch` state the `"openai"` abort. The reply-id fact per route is on `?lms_chat` and `?lms_chat_batch` for both routes, `?lms_chat_native` for the native route, and `?lms_chat_openresponses` for its route. The `...` entries of the three direct pages do not name `store`. The `?lms_chat_batch` `...` entry says a `store` there goes to `lms_chat()` and is checked there. Both AC5 searches exit 1 with no line.
- AC6: read NEWS.md. One top entry, with five sub-bullets, names the four functions. It states the value rule, that `NULL` sends no field, and the `"openai"` abort in `lms_chat()` and `lms_chat_batch()`. It states the "before" behavior on every route, the `"openai"` route included, and that `lms_chat_openai()` still sends a `store` in `...` unchecked. No milestone number appears in it.
- AC7: `devtools::test()` gave no failed or errored test, as stated above. `devtools::check()` with `RLMSTUDIO_API_TOKEN` set: 0 errors, 0 warnings, 0 notes, in 4 min 34 s.

Consistency gate: `cairn_validate.py` passed, exit 0. DESIGN.md is not in the diff, so no principle impact report. `devtools::document()` left no diff. README.Rmd and README.md are not in the diff, and the repo has no `_pkgdown.yml`. NEWS.md has the entry (AC6). No new top-level file, and the check gave no NOTE.

Independent review: three fresh reviewers (Opus diff, Sonnet history, Sonnet prior review). The prior-review probe of GitHub PR comments returned none. No finding shows a criterion failing. Findings, most severe first, with the proposed disposition:

- R1 (history and prior review, both): the `?lms_chat_native` and `?lms_chat_openresponses` pages each lost the other route's `store = FALSE` reply-id sentence. M058 T8 added those sentences after the M058 review returned AC6 for the same gap. AC5 of M061 asks for each page's own routes only, so no criterion fails. Proposed: fix now.
- R2 (Opus): the `store` param on `?lms_chat` says "It needs `api_type = "native"` or `api_type = "openresponses"`". That reads as a rule on every value, but `NULL` passes on `"openai"`. Proposed: fix now, "A `TRUE` or `FALSE` needs ...".
- R3 (history): `?lms_chat_openai` does not say that a `store` in its `...` goes to the server unchecked, as it does for `previous_response_id`. AC6 asks for NEWS only. Proposed: fix now, one sentence in its `...` entry.
- R4 (Opus): five test-store.R tests pass on main, and the three batch send tests stay green without the batch check. Proposed: reject, because the batch abort tests of AC2 and AC3 fail without that check, and the work log records the five.
- R5 (Opus): no test or help for `store = FALSE` together with `previous_response_id`. Proposed: reject, because the server decides what such a call keeps (D-003) and nothing shows a fault.
- R6 (Opus): the `?lms_chat_batch` text "is checked there by the rules of `lms_chat()`" hides that the batch checks `store` itself before its probe. Proposed: reject, because AC5 asks for that sentence and the same entry states the abort before the server check.
- R7 (Opus): R/conditions.R lists `store` under "a bad `TRUE` or `FALSE` argument", though `NULL` passes. Proposed: reject, because `quiet` is listed the same way.
- R8 (Opus): an `expect_s3_class()` in `expect_store_value_aborts()` has no `info` label. Proposed: reject, a diagnostic nit.
- R9 (history): the re-recorded thread fixtures changed ids, timings, and the request hash. Proposed: noted, because the T3 work-log line records the re-recording and all its checks passed.
- R10 (history): the archived M058 summary still quotes the old "in `...`" wording. Proposed: reject, because archives are history.

Gate triage, 2026-09-30: the maintainer took the proposed dispositions. R1 to R3 were fixed now, R4 to R8 and R10 rejected, and R9 noted, each for the reason above. The fixes add four help sentences in R/chat.R: the other route's `store = FALSE` fact on `?lms_chat_native` and `?lms_chat_openresponses`, "A `TRUE` or `FALSE` needs" on `?lms_chat`, and the unchecked `store` on `?lms_chat_openai`. After `devtools::document()`, `tools::checkRd()` on the four pages reported nothing, both AC5 searches still exit 1, and `devtools::test()` gave no failed or errored test.
