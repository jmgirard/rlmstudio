# M061: A named store argument on the thread chat routes

- **Status:** in-progress
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

- [ ] AC1: `lms_chat()`, `lms_chat_native()`, and `lms_chat_openresponses()` take a `store` argument after `...`, with the default `NULL`. On the native and OpenResponses routes, a `store` that `isTRUE()` accepts puts `"store":true` in the request body. A `store` that `isFALSE()` accepts puts `"store":false` there, and `store = NULL` puts no `store` field there. Tests read the serialized request body of each direct function, and of `lms_chat()` on both routes. They do so for `TRUE`, `FALSE`, `NULL`, `c(a = TRUE)`, `matrix(FALSE)`, and `structure(TRUE, class = "foo")`.
- [ ] AC2: Take a `store` that is not `NULL` and that neither `isTRUE()` nor `isFALSE()` accepts. It aborts with a message that names `store` and has no condition class. It aborts before the check for a running server and sends no request. This holds for `lms_chat()`, `lms_chat_native()`, `lms_chat_openresponses()`, and a `store` in the `...` of `lms_chat_batch()`. Tests pass `NA`, `NA_character_`, `"yes"`, `1`, `list(TRUE)`, `c(TRUE, FALSE)`, and `logical(0)` to each of the four. They assert the message and that the server check was not called.
- [ ] AC3: With `api_type = "openai"`, `lms_chat()` and `lms_chat_batch()` abort on `store = TRUE` and on `store = FALSE`, before the check for a running server. The message names `store` and the two routes that take it, and the abort has no condition class. With `api_type = "openai"`, `store = NULL` passes, and the request body has no `store` field. Tests cover both functions and the three values.
- [ ] AC4: `lms_chat_batch()` sends a `store` in its `...` to every call. With three inputs and `store = FALSE`, a test reads `"store":false` in each of the three request bodies, with `format = "data.frame"` on the native route. A second test does the same with `format = "list"` on the OpenResponses route. A third test reads `"store":true` in each body for `store = TRUE`. Two `store` values in its `...` abort with the message that names the argument, as two `previous_response_id` values do. A test asserts that message.
- [ ] AC5: The help pages of `lms_chat()`, `lms_chat_native()`, `lms_chat_openresponses()`, and `lms_chat_batch()` document `store`. They state its value rule, its default, and that `NULL` sends no field. The two pages whose function has an `"openai"` route state the abort there. Each page states that only the exact name `store` is checked, so a shortened name such as `sto` goes into the request body unchecked. Take each route of a page's function that takes `store`. The page states what the T1 probe showed about the reply id of a reply sent there with `store = FALSE`. No sentence on the pages of `lms_chat()`, `lms_chat_native()`, or `lms_chat_openresponses()` describes `store` as a field of `...`. The `lms_chat_batch()` page states that a `store` in its `...` goes to `lms_chat()` and is checked there. After `devtools::document()`, neither search below finds a line:

      grep -rnF 'store = FALSE` in `...`' R/
      grep -rnF 'store = FALSE} in \code{...}' man/

- [ ] AC6: NEWS.md has one entry for `store`. It names the four functions and states the value rule, that `NULL` sends no field, and the `"openai"` route abort in `lms_chat()` and `lms_chat_batch()`. It also states that before, a `store` in `...` went to the server unchecked on every route, the `"openai"` route included. It states that `lms_chat_openai()` still sends a `store` in `...` to the server unchecked.
- [ ] AC7: `devtools::test()` reports 0 failures and 0 errors. `devtools::check()`, run with `RLMSTUDIO_API_TOKEN` set, reports 0 errors and 0 warnings.

## Coverage

- AC1 → T2, T3
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T2, T3
- AC5 → T1, T4
- AC6 → T5
- AC7 → T5

## Tasks

- [ ] T1: Probe a running LM Studio, with the token set and a small model loaded, and record its version. Send `store` as `true` and `false` to `/api/v1/chat` and `/v1/responses`, and record whether each reply carries an id. Continue from the id of a `store: false` reply on each route, and record the status and `code`. Send `store` as `true` and `false` to `/v1/chat/completions`, and record the status. Write the facts, with the version and the date, into the "Stateful chat" bullet of cairn/references/lmstudio-api-surface.md. Restore the server and model state that you found (M009 lesson).
- [ ] T2: Write the AC1 to AC4 tests first with the request recorder of tests/testthat/helper-mock-http.R, and see them red on main. Read the sent bytes, not a parsed body (M004 lesson). In the batch tests, count calls to the server check, because `lms_chat_batch()` reaches `lms_chat()` (M003 lesson).
- [ ] T3: Add `store = NULL` after `...` in the three functions. Check it with `rlm_check_flag(store, "store", null_ok = TRUE)` before `stop_if_no_server()`. If it is not `NULL`, send `isTRUE(store)`, so every accepted form goes out as a plain `true` or `false`. Add a route check beside `rlm_check_thread_route()` (R/utils-args.R:418) and call it in `lms_chat()` and `lms_chat_batch()`. In the batch, check `args[["store"]]` beside `previous_response_id` (R/chat.R:1866). In a scratch copy, remove each check in turn and see a test go red.
- [ ] T4: Write the `store` help on the four pages from the T1 facts, and rewrite the sentences that the two AC5 searches find. Add the `store` faults to the fault list in R/conditions.R:15. Run `devtools::document()`.
- [ ] T5: Add the NEWS.md entry. Append one D-entry: a named `store` is checked, sent as a plain flag, and refused on the OpenAI route, which narrows D-003 as D-030 did. Set `RLMSTUDIO_API_TOKEN`, then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan from the candidate row for a named `store` argument (M058 plan gate).
- 2026-09-30: criteria audit (full mode, fresh Opus reader), pass 1, returned 8 findings. Seven were fixed without a question. Every accepted form is sent as a plain `true` or `false`. AC2 adds two abort probes, and AC5 adds a `man/` search and the exact-name limit. AC6 adds the "before" text. AC4 adds two batch formats and a `store = TRUE` case. The eighth was a conditional reply-id criterion, which the gate dropped.
- 2026-09-30: plan gate chose the default `NULL` everywhere over a batch default of `store = FALSE`. `NULL` keeps today's behavior. Falsified by a user whose batch with `store` unset fills the server store.
- 2026-09-30: plan gate kept the `response_id` attribute of an OpenResponses reply sent with `store = FALSE`, over its removal. The value then matches the reply and needs no new rule. Falsified by a user who passes such an id and gets the 400.
- 2026-09-30: plan gate chose an abort on the OpenAI route over sending the value, as for `ttl` and `previous_response_id`. Falsified by a `/v1/chat/completions` request whose `store` changes what the server keeps.
- 2026-09-30: criteria audit pass 2 (full mode) on the final wording did not run, because the session permission checker gave no verdict for a subagent. The plan is committed as a checkpoint. Run pass 2 before T2 starts.
- 2026-09-30: criteria audit pass 2 (full mode, new fresh Opus reader) ran on the final wording and returned 4 findings, all fixed without a question. AC5 now exempts the batch page, which takes `store` in `...`, and scopes the reply-id fact to each page's routes. AC6 states that `lms_chat_openai()` still sends `store` unchecked. AC2 adds the probe `logical(0)`.

## Decisions

## Review
