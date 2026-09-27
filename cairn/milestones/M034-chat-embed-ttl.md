# M034: The OpenAI chat and embedding functions take a ttl for a model that the request loads

- **Status:** review
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

- [x] AC1: `lms_chat_openai()` and `lms_embed()` each take a `ttl` argument placed after `...`, with default `NULL`. With `ttl = NULL`, the serialized request body carries no `ttl` field. With `ttl = 300`, it carries `"ttl":300`. A test for each function reads both serialized bodies.
- [x] AC2: `lms_chat(api_type = "openai", ttl = 300)` and `lms_chat_batch(api_type = "openai", ttl = 300)` send `"ttl":300` in each serialized request body. Take a valid non-`NULL` `ttl` with an `api_type` of `"openresponses"`, `"native"`, or no `api_type`, which means `"openresponses"`. Then `lms_chat()` and `lms_chat_batch()` abort. They abort with no `rlmstudio_` condition class, before the server probe and before any request, and the message names `ttl` and `api_type = "openai"`. A test runs each of the six function-and-route pairs under `local_counting_probe()` and asserts the message and a probe count of 0.
- [x] AC3: The `ttl` value check accepts `NULL` and one whole number from 1 to `.Machine$integer.max`. The number can be a double or an integer. The request carries the value as a JSON integer. The value check runs before the route check. A test in `tests/testthat/test-arg-guards.R` calls each function that `guarded_exports("ttl")` returns, and `lms_chat_batch()`, with `api_type = "openai"` where the function takes one. It passes each of these values: `"300"`, `TRUE`, `list(300)`, `factor(300)`, `numeric(0)`, `c(60, 120)`, `0`, `0L`, `-5`, `0.5`, `1.5`, `NA_real_`, `NA_integer_`, `NaN`, `Inf`, `-Inf`, `2^31`, and `1e22`. Each call aborts with no `rlmstudio_` condition class, before the server probe, with a message that names `ttl`. The test also passes `NULL`, `1`, `300L`, and `.Machine$integer.max`, and asserts that each call reaches the server probe. `lms_chat()` with `ttl = "300"` and `api_type = "native"` gives the value message.
- [x] AC4: The help pages of `lms_chat_openai()`, `lms_embed()`, and `lms_chat()` each document `ttl` as a number of seconds. Each page says that `ttl` has an effect only on a model that the request itself loads. Each page says that a model already loaded keeps its idle time. The `lms_chat()` text also says that `ttl` needs `api_type = "openai"`. The `...` entry of `lms_chat_batch()` names `ttl` among the arguments checked before the first request. The help pages of `lms_chat_openresponses()` and `lms_chat_native()` say what their endpoint does with a `ttl` in `...`. The first endpoint ignores it. The second rejects it with status 400.
- [x] AC5: `NEWS.md` has an entry for the `ttl` argument on `lms_chat_openai()`, `lms_embed()`, and `lms_chat()`. It states that `ttl` applies only to a model that the request loads. It states that `lms_chat_batch()` passes `ttl` on. It states that a `ttl` on another `lms_chat()` route now aborts before the request. It names no milestone number.
- [x] AC6: `devtools::test()` runs clean, and `devtools::document()` produces no diff.

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
- [x] T5: With a running server, call `lms_embed()` with `ttl = 120` and `lms_chat_openai()` with `ttl = 100`, each on a model that is not loaded. Make sure that `lms ps` shows each TTL. Send a request with a `ttl` to a model that is already loaded, and make sure that its TTL does not change. Unload what the check loaded, restore the server state, and log one line.

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
- 2026-09-27: T4 done. `ttl` is documented on the three function pages, and the batch `...` entry names it. The openresponses and native `...` entries say what their endpoint does with it. The NEWS entry is added. A second `devtools::document()` wrote nothing, and `devtools::test()` passed with 9721 tests.
- 2026-09-27: T5 live check on LM Studio 0.4.25+1. `lms_embed(ttl = 120)` and `lms_chat_openai(ttl = 100)`, each on a model that was not loaded, gave a TTL of `2m / 2m` in `lms ps`. `lms_chat(api_type = "openai", ttl = 600)` on the loaded `google/gemma-3-1b` left its TTL empty. As the next just-in-time model loaded, auto-evict unloaded the earlier one. The server was stopped and gemma left loaded, as before the check.
- 2026-09-27: claim audit: 52 claims read, 5 corrected — tests/testthat/test-ttl.R, R/utils-args.R, R/chat.R, R/embed.R
- 2026-09-27: the five corrections were a D-004 citation, a misplaced helper comment, the reason for the upper bound, the route hint that ignored embeddings, and the missing just-in-time loading setting in three `ttl` help texts. `devtools::test()` passed with 9721 tests, and a second `devtools::document()` wrote nothing. Status set to review.

## Decisions

## Review

Branch synced 2026-09-27: `origin/main` is at d3b31ff, the branch base, so no merge was needed.

- AC1: `tests/testthat/test-ttl.R` reads the dry-run JSON bytes of `lms_chat_openai()` and `lms_embed()`. With `ttl` left out and with `ttl = NULL`, the parsed body has no `ttl` key. With `300`, `300L`, `1e5`, and `.Machine$integer.max`, the text holds `"ttl":<integer>`. Both formals sit after `...` with default `NULL`. Fresh `devtools::test()`: 0 failures.
- AC2: `test-ttl.R` sends `ttl = 300` through `lms_chat(api_type = "openai")` and through a two-input `lms_chat_batch(api_type = "openai")`. The test asserts one and two requests, each with `"ttl":300`. In `test-arg-guards.R`, the route test runs the six pairs of `lms_chat()` and `lms_chat_batch()` with `"openresponses"`, `"native"`, and no `api_type` under `local_counting_probe()`. Each pair aborts with a message that holds `api_type = "openai"` and `ttl`, with no `rlmstudio_` class, and the probe count is 0. The same run passes.
- AC3: `test-arg-guards.R` builds its domain from `guarded_exports("ttl")` plus `lms_chat_batch()`. An export with no call makes the test fail. The domain is `lms_chat`, `lms_chat_batch`, `lms_chat_openai`, and `lms_embed`, with `api_type = "openai"` on the two routing functions. All 18 bad values in the criterion abort under the counting probe. Each message holds "must be one whole number" and names `ttl`, and no condition has an `rlmstudio_` class. The probe count is 0. `NULL`, `1`, `300L`, and `.Machine$integer.max` each reach the probe, which raises `rlmstudio_no_server` once per call. `lms_chat()` and `lms_chat_batch()` with `ttl = "300"` and `api_type = "native"` give the value message. `test-ttl.R` shows a JSON integer on the wire. The same run passes, with 1063 tests in the two files.
- AC4: A read of the rebuilt `man/` pages. `lms_chat_openai.Rd`, `lms_embed.Rd`, and `lms_chat.Rd` document `ttl` as a whole number of seconds. Each says that it has an effect only on a model that this request loads, and that a model already loaded keeps its idle time. `lms_chat.Rd` adds that `ttl` needs `api_type = "openai"`. The `...` entry of `lms_chat_batch.Rd` names `ttl` among the arguments checked before the first call. The `...` entry of `lms_chat_openresponses.Rd` says the endpoint accepts `ttl` and ignores it. The entry of `lms_chat_native.Rd` says it rejects `ttl` with status 400. The T5 live check and `cairn/references/lmstudio-api-surface.md` back these claims.
- AC5: A read of the `NEWS.md` diff. The entry names the `ttl` argument on `lms_chat_openai()`, `lms_embed()`, and `lms_chat()`. It says `ttl` has an effect only on a model that the request loads. It says `lms_chat_batch()` passes `ttl` to `lms_chat()`. It says a `ttl` on any other `lms_chat()` route now aborts before the request. It names no milestone number.
- AC6: Fresh `devtools::test()` on 2026-09-27 gave 9721 tests, 0 failures, 0 errors, and 0 skips, with the live server on. A fresh `devtools::document()` left `git status` clean.

Consistency gate, 2026-09-27: `cairn_validate.py` exit 0 with all checks passed. DESIGN.md is unchanged, so `cairn_impact` does not apply. `devtools::document()` gave no diff. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. The branch does not touch `README.Rmd`, the repo has no `_pkgdown.yml`, and the branch adds no top-level file. The `NEWS.md` entry is present, with no milestone number.

Independent review, 2026-09-27, three fresh reviewers. The [S] history lens found nothing. The [S] prior-review lens found nothing, and the PR comment probe returned no comments. The [O] diff lens ran both test files and reported seven findings, ranked. A read of the code backs each one, and none shows a criterion failing. The dispositions below are proposed, and the merge gate decides them.

1. `R/conditions.R` lines 11 and 12 list the arguments that abort before the server probe and do not name `ttl`. Proposed: fix now.
2. `test-ttl.R` matches `"ttl":300` as an open substring, so `"ttl":3000` also passes. On 2026-09-27, httr2 wrote the doubles `300`, `100000`, `2147483647`, and `2000000000` with no decimal part. So the `as.integer()` lines are not visible on the wire. Proposed: fix now by anchoring the match at the end of the field.
3. Three `ttl` help texts say that just-in-time loading is on by default. No recorded observation backs the default. Proposed: fix now by removing "which is the default".
4. The package check on the `ttl` value is an exception to D-003, and no D-entry records it. Proposed: fix now with a D-entry that narrows D-003.
5. `cairn/references/lmstudio-api-surface.md` lines 152 and 153 still list the `ttl` argument as open work. Proposed: fix now.
6. The value loop for `lms_chat()` on the openai route passes even with the `lms_chat()` value check removed, because `lms_chat_openai()` checks again. The native-route order test does go red. Proposed: reject, because one test already fails on that defect.
7. `ttl_fault()` accepts any object for which `is.numeric()` is true, so a class with odd arithmetic methods can pass. Proposed: reject, because no such class is in use and the common ones (difftime, Date, integer64) behave.
