# M059: Batch logprobs and repeated-argument faults

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP4, GP6
- **Resolves:** —
- **Surface tier:** user-facing — it changes the return value, warnings, and argument aborts of the exported `lms_chat_batch()`.
- **Branch/PR:** m059-batch-logprobs-faults

## Goal

`lms_chat_batch()` names a repeated argument in its own abort, and on the native route it treats `logprobs = TRUE` as off, with one warning.

## Scope

**In:**
- An abort in `lms_chat_batch()` for two dots that reach the same `lms_chat()` argument. Today `match.call()` in `rlm_chat_dots()` raises a base R error there (R/chat.R:2167).
- On `api_type = "native"`, the batch returns what `logprobs = FALSE` returns in each format. It gives one warning past `quiet`. Today `lms_chat()` warns once per input (R/chat.R:146), and the batch reads the flag on every route (R/chat.R:1840).
- The help, NEWS.md, a D-entry, and the tests that pin the old behavior (`test-thread.R:572`, `test-chat-batch.R:784`).

**Out:**
- `lms_chat()` and the other chat functions keep R's own error for one argument given twice, as `lms_embed()` does (`test-embed.R:529`). No row, because that is R's argument matching and not a package fault.
- `rlm_chat_dots()` returns an unnamed third dot with an `NA` name and a `NULL` value. The checks read no unnamed dot, so it has no effect. No row.
- The other `lms_chat_batch()` candidate rows stay rows: the schema property columns, `store`, and the stop at an unknown thread id.

## Acceptance criteria

- [ ] AC1: `lms_chat_batch()` aborts when two or more elements of its `...` match the same `lms_chat()` argument. Examples are `logprobs = TRUE, logprobs = "yes"`, `log = TRUE, lo = FALSE`, two `previous_response_id` values, and `input = "y"` beside `inputs = "x"`. The message names that argument. The abort has no condition class and sends no request. It comes before any other check of the dots and before the check for a running server. So `logprobs = TRUE, logprobs = "yes"` gets this abort and not the flag abort. A test takes each name in `formals(lms_chat)` except `...` and the five batch formals `model`, `system_prompt`, `host`, `simplify`, and `token`. For each name, two exact-name dots reach it. For `api_type` and `logprobs`, two shortened-name dots also reach it. For `input`, one dot reaches it, with `inputs` given by its exact name, because the batch passes `input` itself. The test asserts that the message names the argument and does not contain "matched by multiple actual arguments". It also asserts that `log = TRUE, logprobs = FALSE` passes this check.
- [ ] AC2: Take a batch with `simplify = TRUE`, `api_type = "native"`, and `logprobs = TRUE`. In each of the three formats, it returns the value that the same batch returns with `logprobs = FALSE` for the same server replies. That is a character vector for `"vector"`, a list of strings for `"list"`, and a data frame with no `logprobs` column for `"data.frame"`. A test gives both settings the same mocked replies. It compares the whole returned value of each format, attributes included. It runs once with exact names and once with the shortened names `api = "native", log = TRUE`.
- [ ] AC3: Take a native batch with `logprobs = TRUE`. A batch of one input, a batch of three inputs, and a batch of three inputs where one fails each give exactly one warning with the text "The 'native' API type does not support logprobs. Ignoring argument.". This holds in each format and with `quiet = TRUE`, `quiet = FALSE`, and `quiet = NULL` under `options(rlmstudio.quiet = TRUE)`. The batch gives it after the check for a running server. None of these batches warns that the vector format returns a list. The batch where one input fails still warns with that input's position. A native batch with `logprobs = TRUE` and no running server aborts with `rlmstudio_no_server` and gives no such warning. A test collects every warning of these batches and asserts these counts and texts.
- [ ] AC4: On the `"openresponses"` and `"openai"` routes with `simplify = TRUE`, `logprobs = TRUE` keeps its current results. `format = "vector"` warns that it returns a list, and it returns the value that `format = "list"` returns. `format = "data.frame"` has a `logprobs` list-column. A test runs the three formats on both routes and asserts these values. On the OpenResponses route, the mocked reply carries logprobs.
- [ ] AC5: Take each sentence about `lms_chat_batch()` that contains `logprobs`, in the `lms_chat_batch()` roxygen block of R/chat.R and in the development section of NEWS.md. Each one states which routes it covers, or holds on all three routes. The help page and NEWS.md state the abort of AC1 and the native-route rule of AC2 and AC3. The list of argument faults in the "Server not running" section of R/conditions.R (lines 12 to 22) names the AC1 abort. A search for `logprobs` in the two regions finds the sentences that review reads whole.
- [ ] AC6: `devtools::test()` and `devtools::check()` pass with no errors, warnings, or notes.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T2
- AC4 → T3
- AC5 → T4
- AC6 → T5

## Tasks

- [x] T1: Write the AC1 test first, and see it red on main with the base R error. Build its name list from `formals(lms_chat)`, not from a hand list. Then make the batch abort with a message that names the argument. The abort is unclassed and sits above every other dots check and `stop_if_no_server()` (D-008). Delete the new abort in a scratch copy, and see the test go red for the reason that AC1 names.
- [x] T2: Write the AC2 and AC3 tests first. Compare whole values, and do not strip the `response_id` attribute first (M058 lesson). Count warnings with `collect_warnings()`, because `expect_warning()` catches only one (M019 lesson). Then set the logprobs flag of the batch from the route (R/chat.R:1840). Give one batch warning past `quiet`, after the server probe. Keep the per-input warning of `lms_chat()` from reaching the user. Update the pins at `test-thread.R:572` and `test-chat-batch.R:784`.
- [ ] T3: Read the existing OpenResponses and OpenAI `logprobs = TRUE` batch tests. Add the AC4 cases that they miss.
- [ ] T4: Rewrite the `logprobs` sentences about the batch in its roxygen (R/chat.R:1625-1745) and in the development NEWS entries at NEWS.md:6 and NEWS.md:11. Read each whole sentence, because a sentence can wrap across lines. Add NEWS entries for AC1 and for the native rule. Add the AC1 abort to the fault list in R/conditions.R:12-22. Run `devtools::document()`. Append a D-entry: the native batch treats `logprobs` as off, and its one warning shows past `quiet`. The entry trades GP6 as D-010 does, and it annotates D-013 and D-029.
- [ ] T5: Run `devtools::test()` and `devtools::check()`. Set `RLMSTUDIO_API_TOKEN` first, because the vignettes call a server that can require a token (M009 lesson).

## Work log

- 2026-09-29: created by /milestone-plan, from the candidate row on the two `logprobs` faults of `lms_chat_batch()` (M057 review findings O6 and O7, M058 review findings Q3 and O12).
- 2026-09-29: criteria audit (full mode, fresh [O] reader), pass 1 on the first draft, returned 11 findings. Fixed without a question: a non-colliding AC1 example, `input` missing from the AC1 domain, `...` in `formals()`, and exact-name-only probes. Also fixed: AC2 not scoped to `simplify = TRUE` and mocked replies, AC3 probing two inputs only, AC4 missing the list format, and AC5 searching a proxy and binding a grep result. Posed at the gate: whether the native warning honors `quiet`.
- 2026-09-29: criteria audit pass 2, on the wording after the gate, returned 9 findings, all fixed without a question. AC1 now states the `inputs =` precondition, names `api_type` and `logprobs` as the shortened-name cases, and orders its abort first. AC3 now adds the option source of `quiet`, the timing after the server probe, and the warning text. AC5 now limits its sentences to the batch, adds the R/conditions.R fault list, and asks review to read whole sentences.
- 2026-09-29: plan gate chose to drop the native `logprobs` data-frame column over a column of `NULL`, because one rule then covers the three formats. Falsified by a user whose code reads that column on a native batch.
- 2026-09-29: plan gate chose one warning per batch over one per input, because a long batch repeats the same warning once per input. Falsified by a user who needs the warning tied to each input.
- 2026-09-29: plan gate chose to show the native warning past `quiet` over hiding it, because it is the only sign that the asked-for logprobs are missing. Falsified by a quiet-batch user who reports the warning as noise.
- 2026-09-29: plan gate chose the abort for every `lms_chat()` argument that dots can reach over `logprobs` and `previous_response_id` alone, because the same `match.call()` error hits all of them. Falsified by a dots argument whose repeat the batch must pass through.

- 2026-09-29: implement started on branch `m059-batch-logprobs-faults`. No implementation gate: the plan fixed the behavior, and the one open choice has no public surface. The batch will drop the `logprobs` dots before each native call rather than give the `lms_chat()` warning a class.
- 2026-09-29: T1 done. `rlm_check_chat_dots_once()` in R/chat.R matches each named dot alone and holds exact names first, as R does. `test-batch-repeated-args.R` was red on main with the base R error. With the abort removed in a scratch copy, it went red with "matched by multiple actual arguments". Full suite 17491 pass, 3 skip.
- 2026-09-29: T2 done, with the code written before the tests, against the plan's order. To make up for it, `test-batch-native-logprobs.R` ran against the T1-commit R/chat.R in a scratch copy and failed 54 checks: the vector and data-frame values, the notice count, and "Returning list". `rlm_dots_reached()` now serves the repeat check and the native drop. The batch calls `lms_chat()` through `do.call(..., quote = TRUE)` with `simplify` after `...`. Updated pins: `test-thread.R:572` and three native data-frame tests in `test-chat-batch.R`. Full suite 17596 pass, 3 skip.

## Decisions

## Review
