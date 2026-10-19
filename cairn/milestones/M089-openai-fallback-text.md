# M089: The OpenAI batch vector fallback names what it cannot store

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — a warning text and a help page that users read
- **Branch/PR:** m089-openai-fallback-text

## Goal

On the OpenAI route, the warning of a `logprobs = TRUE` vector batch that returns a list names what the vector format cannot store, and the help says where that warning comes among the batch warnings.

## Scope

**In:** the candidate row "openai batch fallback text".
`lms_chat_batch()` sets `vector_fallback` at `R/chat.R:2365-2373`. On the `"openai"` route with `logprobs = TRUE`, each reply is an `lms_chat_result` whose `logprobs` is `NULL`, so the text "cannot store logprobs dataframes" names data frames that the route never returns.
That route gets its own fallback text, which names the `lms_chat_result` replies. The return value stays the list (plan gate answer).
The `"openresponses"` route keeps its text, because its replies can hold logprobs data frames.
The `@return` vector item and the `logprobs` paragraph of `?lms_chat_batch` name this warning and its place among the batch warnings. One NEWS sentence.

**Out:**
- A character vector of reply text on the OpenAI route. The user chose the list at the plan gate. No candidate row.
- The fallback texts for `simplify = FALSE` and for a `schema` do not change. Not asked for, no candidate row.
- A batch that aborts gives no fallback warning, and this milestone does not add one. No candidate row.

## Acceptance criteria

- [ ] AC1: Take `lms_chat_batch()` with `api_type = "openai"`, `logprobs = TRUE`, `simplify = TRUE`, and `format = "vector"`, where every input gets a reply that is read and not cut off. It returns the same value as `format = "list"`. It gives exactly two warnings. The first is not of class `rlmstudio_no_logprobs`, its text contains `lms_chat_result` and `Returning list.`, and it does not contain `logprobs dataframes`. The second has the class `rlmstudio_no_logprobs`. A mocked-server test shows this with `quiet = TRUE` and with `quiet = FALSE`, and with and without a `schema`.
- [ ] AC2: Take the AC1 call with `api_type = "openresponses"`. The fallback warning text does not change. It contains `cannot store logprobs dataframes. Returning list.`, and the batch gives no `rlmstudio_no_logprobs` warning. A mocked-server test shows this.
- [ ] AC3: Take the AC1 settings with other inputs. A batch of one read reply and one reply cut off at the token limit gives exactly three warnings, in this order: the AC1 fallback warning, the `rlmstudio_reply_cut_off` warning, and the `rlmstudio_no_logprobs` warning. A batch of three inputs, where one reply is read, one reply is cut off, and one input fails with status 500, also gives exactly three warnings. The first is the failed-inputs warning, and its text holds the AC1 fallback text. The second is the `rlmstudio_reply_cut_off` warning, and the third is the `rlmstudio_no_logprobs` warning. A mocked-server test shows the classes and the order, with the failed input first and with it last.
- [ ] AC4: In `man/lms_chat_batch.Rd`, the `@return` vector item and the `logprobs` paragraph of `...` say these facts. With `logprobs = TRUE` on the `"openresponses"` or `"openai"` route, the vector format warns and returns the list. In a batch that returns, that reason is a line of the failed-inputs warning if an input failed. Otherwise it is its own warning, before the cut-off and no-logprobs warnings. `man/lms_chat_batch.Rd` is the roxygen output of `R/chat.R`, so `devtools::document()` leaves no diff.
- [ ] AC5: `NEWS.md`, under the development version, states the new OpenAI fallback text and the old text that it replaces. The sentence goes in the existing sub-bullet about the `rlmstudio_no_logprobs` warning.
- [ ] AC6: `devtools::test()` passes with 0 failures. `devtools::check()` gives 0 errors, 0 warnings, and 0 notes.

## Coverage

- AC1 → T1, T2
- AC2 → T1
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4
- AC6 → T5

## Tasks

- [x] T1: Write the tests first, in `tests/testthat/test-batch-native-logprobs.R`. Split the route loop expectation at line 372 by route (AC1, AC2). Add the `quiet` and `schema` cases of AC1, and the two AC3 batches with the failed input first and last. Pin `withr::local_options(rlmstudio.quiet = FALSE)` where a test reads warning text. Run them and see the OpenAI cases fail.
- [ ] T2: In `R/chat.R:2371`, give the `"openai"` route its own fallback text that names the `lms_chat_result` replies. Update the OpenAI expectation at `tests/testthat/test-chat-schema.R:564`, which reads `"cannot store logprobs"`. Run `devtools::test()`.
- [ ] T3: Edit the `@return` vector item at `R/chat.R:1921` and the `logprobs` paragraph at `R/chat.R:1886-1897`. Write each sentence against the T1 test output. Run `devtools::document()`, and read `man/lms_chat_batch.Rd`.
- [ ] T4: Add the NEWS.md sentence to the `lms_chat_batch()` part of the `rlmstudio_no_logprobs` sub-bullet.
- [ ] T5: Run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which work — the candidate row "openai batch fallback text". Return shape on the OpenAI route — keep the list and fix the text.
- 2026-10-18: collision check: absorbed the candidate row "openai batch fallback text" in full. No planned or active milestone. M088 (done) added the `rlmstudio_no_logprobs` batch warning, and D-043 sets its order, which AC3 keeps. Inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-18: plan gate chose route-specific fallback text over one text for both routes, because an OpenResponses reply with no logprobs part is plain text (`R/chat.R:454`), so a shared `lms_chat_result` text is false there; falsified by an OpenAI reply under `logprobs = TRUE` that is not an `lms_chat_result`.
- 2026-10-18: plan gate chose a sentence in the M088 NEWS sub-bullet over a new bullet, because the same batch call is the subject of both.
- 2026-10-18: criteria audit (full mode, fresh Opus reader) gave 7 findings, all fixed. AC1 excludes cut-off replies and is shown with both `quiet` values and with and without a `schema`. AC1 to AC3 promise behavior, not a test file or handler. AC3 states its settings, gains a no-failure batch with a cut-off reply, varies the failed position, and drops "no other warning". AC4 names its two help sentences and covers a batch that returns only. AC4 states the Rd property, with `document()` as its check. The Out list gains the abort case.
- 2026-10-18: T1: route split at line 372 and two new tests in `test-batch-native-logprobs.R` (quiet and schema cases, a cut-off batch, a failed input first and last). The OpenAI text checks fail on the old text, as expected. The tests were appended with a shell heredoc, against the rule that file edits go through Write and Edit.
