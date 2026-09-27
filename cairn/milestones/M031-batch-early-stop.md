# M031: A chat batch stops at an API failure that holds for every input

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3
- **Resolves:** —
- **Surface tier:** user-facing — the milestone changes the abort rule of `lms_chat_batch()` and the fields of its abort
- **Branch/PR:** m031-batch-early-stop

## Goal

`lms_chat_batch()` aborts at the first input that fails with status 401, 403, or 404, and the abort carries the replies so far.

## Scope

**In:** In `lms_chat_batch()`, an `rlmstudio_api_error` with status 401, 403, or 404 aborts the batch with that condition. The condition gets a `results` field by the rule that a lost server follows. Every other API failure and every `rlmstudio_bad_response` still fail their own input alone (D-011). A live check records the status that each chat route sends for a bad token and for a model that is not loaded. The help of `lms_chat_batch()`, the `rlmstudio-conditions` page, and `NEWS.md` change to match. D-019 narrows D-011.

**Out:** A `stream = TRUE` in the dots fails every input as an `rlmstudio_bad_response` with a wrong hint. It goes to its own candidate row. An `on_error` argument stays rejected (D-011). The live check can find a status outside 401, 403, and 404 for a missing model. That status goes to a candidate row from T1. The single chat calls do not change.

## Acceptance criteria

- [ ] AC1: When `lms_chat()` raises an `rlmstudio_api_error` with `status` 401, 403, or 404 for an input, `lms_chat_batch()` aborts with that condition. It sends no request after that input and gives no warning. An earlier failed input does not change this. A test in `tests/testthat/test-chat-batch.R` fires each status at input one and at input two of three. These cases use `format = "list"`. The test also fires 401 on the native and OpenResponses routes, and 401 at input two after a 400 at input one. It asserts the class, the `status`, the absence of a warning, and the count of requests sent.
- [ ] AC2: That abort carries a `results` field by the rule a lost server follows. The field is a list as long as `inputs`, with their names. Each element before the stopping input holds what `format = "list"` returns for that input, a stored failure included. The element for the stopping input and every later element is `NULL`. A test asserts the field for a stop at the middle input in each of the three formats. It also asserts the field for a stop at the first input, for named inputs, and for a stored 400 failure before the stop.
- [ ] AC3: The stop rule decides on the condition's class and `status` field alone. A test fires an `rlmstudio_api_error` with status 400, 422, or 500 at the middle input, and an `rlmstudio_bad_response` there. Each still fails only that input. The batch sends three requests and returns its result with the failed-input warning.
- [ ] AC4: The details of `lms_chat_batch()` and the "API failure" section of the `rlmstudio-conditions` help page name the three statuses. Both say that the batch aborts on them. Review reads the two passages whole, and no sentence in them says that the batch does not abort on an `rlmstudio_api_error`. The help page says that the `results` field of this abort follows the lost-server rule. `NEWS.md` has an entry for the change.
- [ ] AC5: `devtools::test()` passes, `devtools::document()` produces no diff, and `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T2, T3
- AC2 → T2, T3
- AC3 → T2, T3
- AC4 → T4
- AC5 → T3, T4

## Tasks

- [x] T1: Start the local LM Studio server with the token from the user's token file. On each of the three routes, send one chat request with a bad token. Send one for a model that is not loaded. If the server offers a setting for just-in-time loading, turn it off first. Log the status and error text of each route in one work-log line. A route can send a status outside 401, 403, and 404 for the missing model. In that case, add a candidate row that names the route and the status.
- [x] T2: Write the AC1 to AC3 tests in `tests/testthat/test-chat-batch.R` through the shared recorder (D-004). Reuse `run_failing_batch()` where it fits. Plant a 401 at the middle input and see the tests fail against the current code.
- [ ] T3: Change the `rlmstudio_api_error` handler of `lms_chat_batch()` at `R/chat.R:1205`. For status 401, 403, or 404, it aborts with the condition and a `results` field. For any other status, it keeps the stored failure. Run `devtools::test()`.
- [ ] T4: Rewrite the `lms_chat_batch()` details at `R/chat.R:1054-1080` and the "API failure" section at `R/conditions.R:56-61`. State the `results` rule next to the lost-server text. Add the `NEWS.md` entry. Run `devtools::document()`, then run `devtools::check()` with `RLMSTUDIO_API_TOKEN` set.

## Work log

- 2026-09-27: created by /milestone-plan. It absorbs the candidate row on batches in which every input fails.
- 2026-09-27: the criteria audit ran in full mode with a fresh [O] reader and returned 9 findings. The draft fixed 7: probes for an earlier failure, a stored failure, named inputs, and two more routes, the class-and-status wording, the two help passages, and a D-015 note. The gate took 1 as the live check in T1. AC1 took 1 as "no warning".
- 2026-09-27: plan gate chose 401, 403, and 404 over 401 and 403 alone, because a missing model also fails every input. A live 404 that depends on the input falsifies the choice.
- 2026-09-27: plan gate chose 401, 403, and 404 over a streak of three equal failures, because a streak ends a good batch after three bad prompts. An every-input fault with a status outside the set, such as a 400 for a missing model, falsifies the choice.
- 2026-09-27: plan gate chose an abort with a `results` field over an early return with a warning. A script can miss a warning, and scripts already catch a lost server this way. A user who needs the partial result without `tryCatch()` falsifies the choice.
- 2026-09-27: plan gate chose a separate candidate row for `stream = TRUE` over a guard in the batch alone. The fix belongs in every chat function and needs its own decision against D-003. A user report of a batch lost to `stream = TRUE` falsifies the choice.
- 2026-09-27: implement started on branch m031-batch-early-stop. No question gate, because the plan left no choice open.
- 2026-09-27: T1 live check on LM Studio at localhost:1234. A bad, malformed, or absent token gives 401 `invalid_api_key` on all three routes. A model id that is not downloaded gives 404 `model_not_found` on `/api/v1/chat`. On `/v1/responses` and `/v1/chat/completions` it gives 200 with a reply from the loaded model, or 400 "No models loaded" with no model loaded. JIT loading stayed on, because a model that is not downloaded cannot load. A downloaded model that is not loaded was not tried. Candidate row added for the two OpenAI-style routes.
- 2026-09-27: T2 added seven tests and `run_stopping_batch()` to `tests/testthat/test-chat-batch.R`. Against the old handler, a 401 at input two gave a stored slot, a warning, and three requests, so the stop tests fail. This checkpoint is red until T3.

## Decisions

## Review
