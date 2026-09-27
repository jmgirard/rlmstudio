# M036: The chat completions help says that a reply is read from its first choice

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Surface tier:** user-facing — help text and NEWS for an exported function, and tests of its return value
- **Branch/PR:** m036-openai-first-choice

## Goal

With `simplify = TRUE`, `lms_chat_openai()` reads a reply from its first choice alone, and its help pages say so.

## Scope

**In:** Tests that pin the first-choice rule for a reply with two choices. They cover the text, `logprobs = TRUE`, and schema routes of `lms_chat_openai()`, and one `lms_chat_batch(api_type = "openai")` input. Help text in the `@return` of `lms_chat_openai()` and in the "Cut-off reply" and "Malformed response" sections of `R/conditions.R`. One NEWS bullet. D-022 records the rule. The code in `openai_reply_value()` does not change.

Observed on 2026-09-27 with google/gemma-3-1b: a `/v1/chat/completions` request with `n` 2 and `max_tokens` 5 returned one choice, with `finish_reason` `"length"`.

**Out:** A warning or abort for a cut-off choice other than the first. D-022 rejects it. The token columns of the OpenAI data-frame batch keep reading `usage` as they do. LM Studio sends one choice, so no row is added for them.

## Acceptance criteria

- [ ] AC1: With `simplify = TRUE`, `lms_chat_openai()` reads a reply that holds two choices from its first choice alone. Tests over mocked bodies whose two choices hold different content show both orders of finish reasons on each route. With no `schema`, a first choice with `"stop"` and a second with `"length"` returns the first choice's text with no `rlmstudio_reply_cut_off` warning. The swapped pair returns the first choice's text with one such warning. With `logprobs = TRUE`, the same two pairs return an `lms_chat_result` whose text is the first choice's, with no warning and with one warning. With a `schema` and `logprobs = FALSE`, the first pair returns the first choice's parsed value. The swapped pair raises `rlmstudio_bad_response` whose `content` field holds the first choice's content and whose `finish_reason` field is `"length"`.
- [ ] AC2: `lms_chat_batch(api_type = "openai")` reads each reply from its first choice. A test runs two inputs. The second reply has a first choice with `"stop"` and a second with `"length"`. The test asserts the first choice's text at position 2 and no `rlmstudio_reply_cut_off` warning.
- [ ] AC3: The `@return` of `lms_chat_openai()` and the "Cut-off reply" section of `R/conditions.R` say three things. With `simplify = TRUE`, a reply is read from its first choice. No other choice is read. `simplify = FALSE` returns the body with every choice. The "Malformed response" section says that the `content` field holds the content of the first choice.
- [ ] AC4: `NEWS.md` has one bullet under the development version that states the first-choice rule. The bullet names no milestone.
- [ ] AC5: `devtools::test()` runs clean, and `devtools::document()` produces no diff.

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T2
- AC4 → T3
- AC5 → T1, T2, T3

## Tasks

- [x] T1: Add a two-choice chat completions body helper to `tests/testthat/helper-chat-bodies.R`, beside `completion_body()`. Write the AC1 and AC2 tests in a new `tests/testthat/test-chat-first-choice.R`. In a scratch copy, make `openai_reply_value()` (`R/chat.R:429-430`) read the last choice, and make sure that each test goes red. Read fields with `[[`, per the M018 lesson.
- [x] T2: Edit the `@return` of `lms_chat_openai()` (`R/chat.R:285-305`) and the "Cut-off reply" and "Malformed response" sections (`R/conditions.R:175-240`). Run `devtools::document()`. Make sure that the change reaches `man/lms_chat_openai.Rd`, `man/lms_chat.Rd`, `man/lms_chat_batch.Rd`, and `man/rlmstudio-conditions.Rd`.
- [x] T3: Add the NEWS bullet. Run `devtools::test()`.

## Work log

- 2026-09-27: created by /milestone-plan from the candidate row on `choices[[1]]` (M035 review finding O7).
- 2026-09-27: criteria audit (full mode, fresh [O] reader) found no IP or D-entry conflict. Fixes applied: a `logprobs = TRUE` route and a batch probe, different content in the two choices, and an assert on the abort's `finish_reason` field. The help now says "no other choice is read" and covers the `content` field. A criterion that bound the render of four `.Rd` files moved to T2.
- 2026-09-27: plan gate chose to keep and document the first-choice rule over a warning for any cut-off choice. The call returns the first choice alone, and LM Studio sent one choice for `n` 2. A server reply that holds more than one choice falsifies the choice.
- 2026-09-27: implement started on m036-openai-first-choice. Question gate skipped, nothing open.
- 2026-09-27: T1 done. `two_choice_body()` and three tests in `test-chat-first-choice.R`. Plant "read the last choice" turned all three tests red, and plant "finish reason from the last choice" also did. `devtools::test()` 9885 pass, 0 fail.
- 2026-09-27: T2 done. First-choice text in the `@return` of `lms_chat_openai()` and in the "Cut-off reply" and "Malformed response" sections. `devtools::document()` wrote it to the four named pages. The "Malformed response" change also reaches the eight other pages that inherit that section.
- 2026-09-27: T3 done. One NEWS bullet under the development version. A second `devtools::document()` gave no diff. `devtools::test()` 9885 pass, 0 fail.
- 2026-09-27: claim audit: 17 claims read, 3 corrected. Files: R/chat.R, R/conditions.R, tests/testthat/test-chat-first-choice.R. The help now says "no other element of `choices`", since the batch token columns read `usage`. The cut-off sentence says the choice "the call reads". The batch test now runs the vector, list, and data-frame formats. The plant "read the last choice" turned all three tests red again.
- 2026-09-27: all tasks done. `devtools::test()` 9889 pass, 0 fail. `devtools::document()` gave no diff. Status set to review.

## Decisions

## Review
