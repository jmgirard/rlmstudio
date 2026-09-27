# M034: The OpenAI chat and embedding functions take a ttl for a model that the request loads

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — a new argument on four exported functions
- **Branch/PR:** m034-chat-embed-ttl

## Goal

A chat or embedding request can load a model. The user of such a request sets a named and checked `ttl` argument, which is the number of idle seconds that the model stays loaded.

## Scope

**In:** A `ttl` argument after `...` on `lms_chat_openai()`, `lms_embed()`, and `lms_chat()`. `lms_chat_batch()` passes it to `lms_chat()` through `...` and checks it before its server probe. A value check and a route check in `R/utils-args.R`, both above the server probe (D-008). On the `"openresponses"` and `"native"` routes, `lms_chat()` and `lms_chat_batch()` abort, as for `schema`. Help text on five pages and a NEWS entry.

The facts behind the scope were observed on 2026-09-27 against LM Studio 0.4.25+1, and `cairn/references/lmstudio-api-surface.md` records them. `/v1/chat/completions` and `/v1/embeddings` honor `ttl` only for a model that the request itself loads. `/v1/responses` returns 200 and keeps the 60-minute default. `/api/v1/chat` and `/api/v1/models/load` answer 400 "Unrecognized key(s) in object: 'ttl'".

**Out:** `ttl` on `lms_load()`. The REST load endpoint rejects the field, so this work goes to a candidate row in `cairn/ROADMAP.md`. `lms_chat_openresponses()` and `lms_chat_native()` get no `ttl` argument. A `ttl` in their `...` still goes to the server (GP4), and their help pages say what the server does with it.

## Acceptance criteria

- [ ] AC1: `lms_chat_openai()` and `lms_embed()` each take a `ttl` argument placed after `...`, with default `NULL`. With `ttl = NULL`, the serialized request body carries no `ttl` field. With `ttl = 300`, it carries `"ttl":300`. A test for each function reads both serialized bodies.
- [ ] AC2: `lms_chat(api_type = "openai", ttl = 300)` and `lms_chat_batch(api_type = "openai", ttl = 300)` send `"ttl":300` in each serialized request body. Take a valid non-`NULL` `ttl` with an `api_type` of `"openresponses"`, `"native"`, or no `api_type`, which means `"openresponses"`. Then `lms_chat()` and `lms_chat_batch()` abort. They abort with no `rlmstudio_` condition class, before the server probe and before any request, and the message names `ttl` and `api_type = "openai"`. A test runs each of the six function-and-route pairs under `local_counting_probe()` and asserts the message and a probe count of 0.
- [ ] AC3: The `ttl` value check accepts `NULL` and one whole number from 1 to `.Machine$integer.max`. The number can be a double or an integer. The request carries the value as a JSON integer. The value check runs before the route check. A test in `tests/testthat/test-arg-guards.R` calls each function that `guarded_exports("ttl")` returns, and `lms_chat_batch()`, with `api_type = "openai"` where the function takes one. It passes each of these values: `"300"`, `TRUE`, `list(300)`, `factor(300)`, `numeric(0)`, `c(60, 120)`, `0`, `0L`, `-5`, `0.5`, `1.5`, `NA_real_`, `NA_integer_`, `NaN`, `Inf`, `-Inf`, `2^31`, and `1e22`. Each call aborts with no `rlmstudio_` condition class, before the server probe, with a message that names `ttl`. The test also passes `NULL`, `1`, `300L`, and `.Machine$integer.max`, and asserts that each call reaches the server probe. `lms_chat()` with `ttl = "300"` and `api_type = "native"` gives the value message.
- [ ] AC4: The help pages of `lms_chat_openai()`, `lms_embed()`, and `lms_chat()` each document `ttl` as a number of seconds. Each page says that `ttl` has an effect only on a model that the request itself loads. Each page says that a model already loaded keeps its idle time. The `lms_chat()` text also says that `ttl` needs `api_type = "openai"`. The `...` entry of `lms_chat_batch()` names `ttl` among the arguments checked before the first request. The help pages of `lms_chat_openresponses()` and `lms_chat_native()` say what their endpoint does with a `ttl` in `...`. The first endpoint ignores it. The second rejects it with status 400.
- [ ] AC5: `NEWS.md` has an entry for the `ttl` argument on `lms_chat_openai()`, `lms_embed()`, and `lms_chat()`. It states that `ttl` applies only to a model that the request loads. It states that `lms_chat_batch()` passes `ttl` on. It states that a `ttl` on another `lms_chat()` route now aborts before the request. It names no milestone number.
- [ ] AC6: `devtools::test()` runs clean, and `devtools::document()` produces no diff.

## Coverage

- AC1 → T2
- AC2 → T1, T3
- AC3 → T1, T2, T3
- AC4 → T4, T5
- AC5 → T4
- AC6 → T1, T2, T3, T4

## Tasks

- [x] T1: Write the AC3 value tests and the AC2 route tests in `tests/testthat/test-arg-guards.R` first, next to the `schema_calls` tests. Then add the value check and the route check to `R/utils-args.R`, modeled on `rlm_check_schema()` and `rlm_check_schema_route()`. If `guarded_exports("ttl")` returns fewer than the three functions that take `ttl`, make the value test fail. Plant a value check that accepts `0` and a route check that skips `"native"`, and see each test go red.
- [x] T2: Add `ttl` after `...` on `lms_chat_openai()` and `lms_embed()`. The check runs above `stop_if_no_server()`. If `ttl` is not `NULL`, the body gets `as.integer(ttl)`. Write the AC1 body tests first. Read the serialized bytes, as the M012 lesson on array forms describes.
- [x] T3: Add `ttl` after `...` on `lms_chat()`. Run the value check and the route check next to the `schema` checks, and forward `ttl` on the `"openai"` route. In `lms_chat_batch()`, read `ttl` through `rlm_chat_dots()` and check it with `schema`, before `stop_if_no_server()`. Write the AC2 body tests for both functions first. Test the `"openai"` route of `lms_chat()` directly, because its delegate checks again (M013 lesson).
- [x] T4: Write the roxygen text for the five pages in AC4, run `devtools::document()`, and add the AC5 entry to `NEWS.md`. Write each claim about the server from the 2026-09-27 observations or from T5, not from memory.
- [ ] T5: With a running server, call `lms_embed()` with `ttl = 120` and `lms_chat_openai()` with `ttl = 100`, each on a model that is not loaded. Make sure that `lms ps` shows each TTL. Send a request with a `ttl` to a model that is already loaded, and make sure that its TTL does not change. Unload what the check loaded, restore the server state, and log one line.

## Work log

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: live probe on LM Studio 0.4.25+1 found that only `/v1/chat/completions` and `/v1/embeddings` honor `ttl`, which moved `lms_load()` out of scope. The candidate row claimed that the load endpoint takes it.
- 2026-09-27: criteria audit (full mode, fresh [O] reader) returned ten findings. All ten were fixed before the gate. The fixes cover the value-test route, the check order, the upper bound, and the probe axes. They also cover the default route, the batch body, two help texts, the NEWS change, and the body wording.
- 2026-09-27: plan gate chose an abort on the non-openai routes of `lms_chat()` over `ttl` on the two direct functions only, because the default openresponses route ignores it silently; falsified by a live `/v1/responses` or `/api/v1/chat` request whose `ttl` sets the idle time.
- 2026-09-27: plan gate chose a candidate row for `lms_load()` over a command-line route through `lms load --ttl`, because that mixes a CLI call into a REST function; falsified by a load endpoint that accepts `ttl`, or a user need for a `ttl` on an explicit load.
- 2026-09-27: plan gate chose a package check on the value over forwarding it unchecked, because the server accepts "abc" and -5 without an error; falsified by a server that rejects bad `ttl` values with its own error.
- 2026-09-27: implement started on branch `m034-chat-embed-ttl`. The question gate was skipped, because the plan left no choice open.
- 2026-09-27: T1 to T3 done in one checkpoint, because the T1 tests cover the functions that T2 and T3 change. The body tests are in the new `tests/testthat/test-ttl.R`. Four planted defects each turned a test red: a value check that accepts 0, a route check that skips native, no batch check, and no `ttl` in the embed body. `devtools::test()` passed with 9721 tests.
- 2026-09-27: T2 finding: httr2 writes the double 1e5 as `100000`, so `as.integer()` changes nothing on the wire today. It stays so that the field is an integer whatever the serializer does with a double.
- 2026-09-27: T4 done. `ttl` is documented on the three function pages, the batch `...` entry names it, and the openresponses and native `...` entries say what their endpoint does with it. The NEWS entry is added. A second `devtools::document()` wrote nothing, and `devtools::test()` passed with 9721 tests.

## Decisions

## Review
