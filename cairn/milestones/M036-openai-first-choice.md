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

- [x] AC1: With `simplify = TRUE`, `lms_chat_openai()` reads a reply that holds two choices from its first choice alone. Tests over mocked bodies whose two choices hold different content show both orders of finish reasons on each route. With no `schema`, a first choice with `"stop"` and a second with `"length"` returns the first choice's text with no `rlmstudio_reply_cut_off` warning. The swapped pair returns the first choice's text with one such warning. With `logprobs = TRUE`, the same two pairs return an `lms_chat_result` whose text is the first choice's, with no warning and with one warning. With a `schema` and `logprobs = FALSE`, the first pair returns the first choice's parsed value. The swapped pair raises `rlmstudio_bad_response` whose `content` field holds the first choice's content and whose `finish_reason` field is `"length"`.
- [x] AC2: `lms_chat_batch(api_type = "openai")` reads each reply from its first choice. A test runs two inputs. The second reply has a first choice with `"stop"` and a second with `"length"`. The test asserts the first choice's text at position 2 and no `rlmstudio_reply_cut_off` warning.
- [x] AC3: The `@return` of `lms_chat_openai()` and the "Cut-off reply" section of `R/conditions.R` say three things. With `simplify = TRUE`, a reply is read from its first choice. No other choice is read. `simplify = FALSE` returns the body with every choice. The "Malformed response" section says that the `content` field holds the content of the first choice.
- [x] AC4: `NEWS.md` has one bullet under the development version that states the first-choice rule. The bullet names no milestone.
- [x] AC5: `devtools::test()` runs clean, and `devtools::document()` produces no diff.

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

- Sync 2026-09-27: `origin/main` is an ancestor of the branch head. No merge was needed.
- AC1 evidence: the text test in `test-chat-first-choice.R` has 16 expectations. It runs both orders of finish reasons on three routes: no schema, `logprobs = TRUE`, and a schema with `logprobs = TRUE`. It asserts the text "first", the `lms_chat_result` class, and 0 or 1 cut-off warnings. The schema test has 5 expectations. It asserts `list(score = 3L)` with no warning for the first pair. For the swapped pair, it asserts `rlmstudio_bad_response` with `content` `'{"score": 3}'` and `finish_reason` `"length"`. Both tests pass in a fresh `devtools::test()`. A scratch-copy plant read the last choice at `R/chat.R:435-436`. It failed 12 of 16 in the text test and errored the schema test.
- AC2 evidence: the batch test runs `lms_chat_batch(api_type = "openai")` over two inputs in the vector, list, and data-frame formats. The second reply has "two" with `"stop"` first and "other" with `"length"` second. It asserts "two" at position 2 and no cut-off warning in each format, 6 expectations, and passes. The same plant failed all 6.
- AC3 evidence: read in `R/chat.R:307-311` and `man/lms_chat_openai.Rd:78-82`. The `@return` says three things. With `simplify = TRUE`, the reply is read from the first element of `choices`. No other element is read. With `simplify = FALSE`, the body holds every choice. The "Cut-off reply" section (`R/conditions.R:239-242`) sits in a paragraph about `simplify = TRUE`. It says the same three things in its own words. The "Malformed response" section (`R/conditions.R:216-218`) says that `content` holds the reply content of the first choice. The cut-off text reaches `man/lms_chat.Rd` and `man/lms_chat_batch.Rd` too.
- AC4 evidence: `git diff main..HEAD -- NEWS.md` adds one bullet, at `NEWS.md:3` under "rlmstudio (development version)". It states that with `simplify = TRUE` a reply is read from its first choice alone. A search for `M[0-9]{3}` in `NEWS.md` finds 0 hits.
- AC5 evidence: a fresh `devtools::test()` gave 9889 pass, 0 fail, 0 error, 0 skip, 0 warning. A fresh `devtools::document()` left `git status` clean. It prints one roxygen warning, that the `@aliases` at `R/conditions.R:257` spans two lines. That line came from M035 on main, and the alias still renders at `man/rlmstudio-conditions.Rd:8`.
- Gate: `cairn_validate.py` passed, exit 0. `devtools::check()` with the API token set gave 0 errors, 0 warnings, 0 notes. `pkgdown::check_pkgdown()` found no problems. `devtools::document()` gave no diff. The branch touches no README, DESIGN principle, or new top-level file. The changelog entry is the AC4 bullet.
- Review fan-out: [O] diff-bug found 8 minor findings and no AC failure. [S] blame-history found none. [S] prior-review found none. The PR-thread probe returned no comments. Proposed dispositions, pending the gate:
  - O1 (`NEWS.md:3`): "first choice" can read as `index` 0, but the code takes the first array element. Proposed reject, because the `@return` says "first element of the `choices` field".
  - O2 (`R/chat.R:309-310`, `NEWS.md:3`): the text says the cut-off warning "reports" the finish reason. The warning at `R/chat.R:495-505` names no finish reason. Proposed fix now: say that the warning and abort depend on the finish reason of that choice.
  - O3 (`R/conditions.R:219`): "Both are `NULL` for a response with no `choices`" omits other unreadable `choices`. Proposed reject, because the line predates the branch.
  - O4 (`R/conditions.R:239-240`): the new sentence names only the cut-off abort, but the other aborts also word their message from the first choice. Proposed reject, because the text is incomplete but true.
  - O5 (test batch block): the batch test runs one order of finish reasons only. Proposed reject, because AC2 asks for that order.
  - O6 (test batch loop): `local_request_sequence()` stacks a mock on each loop pass. Proposed reject, because each pass uses the newest mock and passes.
  - O7: three new lines are over 80 characters. Proposed reject, because a formatter catches it and the files hold other such lines.
  - O8: `lms_chat(api_type = "openai")` has no direct first-choice test. Proposed reject, because it calls `lms_chat_openai()` at `R/chat.R:382`.
  - Review-side note: `devtools::document()` warns that the `@aliases` at `R/conditions.R:257` spans two lines. Proposed follow-up candidate row, because the line came from M035.
