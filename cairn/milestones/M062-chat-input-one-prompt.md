# M062: A chat call aborts on a text input that is not one prompt

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Surface tier:** user-facing — it narrows the `input` argument of three exported chat functions.
- **Branch/PR:** m062-chat-input-one-prompt

## Goal

A chat call stops in R when a character `input` does not hold exactly one prompt, and the message points to `lms_chat_batch()`.

## Scope

**In:**
- A length rule on a character `input` in `lms_chat()`, `lms_chat_openresponses()`, and `lms_chat_native()`. Length one passes. Any other length aborts before the check for a running server. The NA check runs first, so its message stays for a vector that holds an NA. A list `input`, the structured input form, passes as before. Today every route answers a two-string `input` with a 400.
- The live probe facts of 2026-09-30 in cairn/references/lmstudio-api-surface.md. Help, NEWS.md, the R/conditions.R fault list, one D-entry, and tests.

**Out:**
- Pasting the strings into one prompt. The plan gate chose the abort. No row.
- `lms_chat_openai()`, which takes `messages` and not `input`. Its `messages` rules stand (M038 to M046).
- A length rule on a list `input`. The server validates it (D-003). No row.
- Text longer than the loaded context → M063.

## Acceptance criteria

- [x] AC1: `lms_chat()`, `lms_chat_openresponses()`, and `lms_chat_native()` abort when `input` is a character vector that holds no NA and whose length is not one. The message names `input`, states the length given, and names `lms_chat_batch()`. The abort has no condition class. It comes before the check for a running server, and no request is sent. A vector that holds an NA gets the NA message of M013, whatever its length. Tests pass `character(0)`, `c("a", "b")`, and `c("a", NA)` to each function, and to `lms_chat()` on each of its three `api_type` values. They assert the message and that the server check was not called.
- [x] AC2: The rule lets two forms through to the request body. For each of the three functions, and for `lms_chat()` on each of its three routes, a test reads the serialized request body. The input `"hi"` is there as the JSON string `"hi"`. The input `list(list(type = "message", role = "user", content = "hi"))`, an unnamed list of one message object, is there as a JSON array of one object. The body field is `input`, and on the OpenAI route it is the `content` of the user message.
- [x] AC3: `lms_chat_batch()` with `inputs = c("a", "b")` sends two requests, and the `input` field of each is one JSON string, `"a"` and then `"b"`. A test reads both serialized bodies.
- [x] AC4: The `input` entry on the help pages of the three functions states the length rule and names `lms_chat_batch()` for many prompts. NEWS.md has one entry that names the three functions and states the rule. It also states that before, a two-string `input` went to the server and got a 400.
- [x] AC5: `devtools::test()` reports 0 failures and 0 errors. `devtools::check()`, run with `RLMSTUDIO_API_TOKEN` set, reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T1
- AC4 → T3
- AC5 → T4

## Tasks

- [x] T1: Write the AC1 to AC3 tests first with the request recorder of tests/testthat/helper-mock-http.R, and see the AC1 tests red on main. Read the sent bytes, not a parsed body (M004 lesson). Count calls to the server check rather than `fail()` in a stub (M015 lesson). Test `lms_chat()` on the OpenAI route, the one route with no delegate that checks again (M013 lesson).
- [x] T2: Add the rule to R/utils-args.R beside `rlm_check_no_na()` (R/utils-args.R:1278), and call it where the three functions call `rlm_check_no_na(input, "input")` (R/chat.R:132, R/chat.R:311, R/chat.R:1403). In a scratch copy, remove each call in turn and see a test go red.
- [x] T3: Write the help text and run `devtools::document()`. Add the fault to the list in R/conditions.R. Add the NEWS.md entry. Add the probe facts of 2026-09-30 to cairn/references/lmstudio-api-surface.md, with the LM Studio version that `lms version` gives. A two-string `input` got a 400 on `/v1/responses` ("Invalid type for 'input'.") and on `/api/v1/chat` (code `invalid_union`). A two-string `content` got a 400 on `/v1/chat/completions`. An empty `input` array got a 400 on `/v1/responses`.
- [x] T4: Append one D-entry: a character `input` must be one string on the chat routes, which narrows D-003 as D-020 did. Set `RLMSTUDIO_API_TOKEN`, then run `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-30: created by /milestone-plan from the candidate row on an `input` of length two (M013 plan gate).
- 2026-09-30: criteria audit (full mode, fresh Opus reader), pass 1, returned 4 findings, all fixed without a question. The NA check runs first and AC1 adds `c("a", NA)`, AC2 names its two probe forms, the NEWS claim is limited to the probed two-string case, and a line citation is corrected. Pass 2 (new fresh Opus reader) returned no finding.
- 2026-09-30: plan gate chose an abort in R over pasting the strings into one prompt and over documenting the 400. The abort guesses nothing and can be relaxed later. Falsified by users who pass several strings on purpose and expect one joined prompt.
- 2026-09-30: implement started on branch m062-chat-input-one-prompt. The question gate was skipped, because the plan left no choice open.
- 2026-09-30: T1 added tests/testthat/test-input-length.R. On main, the five AC1 length tests failed (10 expectations each), and the NA-order, pass-through, and batch tests passed.
- 2026-09-30: T2 added `rlm_check_one_prompt()` to R/utils-args.R and called it after each `rlm_check_no_na(input, "input")` in R/chat.R. Deleting each of the three calls in a scratch copy turned one AC1 test red (the `lms_chat()` call through its openai route). `devtools::test()`: 802 tests, 0 failures, 0 errors, 3 skips.
- 2026-09-30: T3 rewrote the `input` entry of the three help pages, added the NEWS.md entry, and added the "Chat input of two strings" bullet to the API reference. R/conditions.R needed no edit, because its "Server not running" list already names a bad `input` among the argument aborts.
- 2026-09-30: T4 appended D-036. With `RLMSTUDIO_API_TOKEN` set, `devtools::test()` gave 802 tests, 0 failures, 0 errors, 3 skips, and `devtools::check()` gave 0 errors, 0 warnings, 0 notes. The server was stopped before and after.
- 2026-09-30: claim audit: 37 claims read, 2 corrected — NEWS.md, R/utils-args.R. Both overstated what the server 400 replies said, and the same reader confirmed the corrected wording.
- 2026-09-30: all tasks done; status set to review.
- 2026-09-30: correction to the T2 line (review finding O7). Only the deleted call in `lms_chat()` turned the openai-route test red. A deleted call in `lms_chat_native()` or `lms_chat_openresponses()` turned the direct-call test of that function red.
- 2026-09-30: review ran AC1 to AC5 with fresh evidence, passed the consistency gate, and triaged 17 findings from three reviewers, none of which fails a criterion. Fix-now edits to comments and test formatting are committed.
- 2026-09-30: step-7 approval: m062-chat-input-one-prompt approved for merge

## Decisions

## Review

- AC1 evidence (2026-09-30): `devtools::test(filter = "input-length")` passed all expectations on the branch. On an `origin/main` worktree, the same file failed the five AC1 length tests, 10 expectations each, and passed the other 11. After `load_all()`, `lms_chat(api_type = "openai")` gave "`input` must be one prompt, given as a single string. ✖ You gave 0 strings." The message for `c("a", "b")` said "2 strings". Both messages named `lms_chat_batch()`. The input `c("a", NA)` gave the NA message. The tests assert the class `c("rlang_error", "error", "condition")` and 0 server-check calls.
- AC2 evidence (2026-09-30): the five "sends one string and a list input as given" tests passed on the branch. Each test reads the sent bytes with `request_body_text()`. It matches `"input":"hi"` and `"input":[{"type":"message","role":"user","content":"hi"}]`, with `content` in place of `input` on the openai route of `lms_chat()`.
- AC3 evidence (2026-09-30): the test "lms_chat_batch() sends each of its inputs as one string" passed on the branch. It records 2 requests and matches `"input":"a"` in the first body and `"input":"b"` in the second.
- AC4 evidence (2026-09-30): the `input` entry of `man/lms_chat.Rd`, `man/lms_chat_native.Rd`, and `man/lms_chat_openresponses.Rd` states "its length must be one" and links `lms_chat_batch()` for several prompts. NEWS.md has one entry with the rule. It names the three functions and says that before, a two-string `input` went to the server and got a 400 on each route.
- AC5 evidence (2026-09-30): with `RLMSTUDIO_API_TOKEN` set, `devtools::test()` gave 802 tests, 0 failures, 0 errors, 3 skips. `devtools::check()` then gave 0 errors, 0 warnings, 0 notes.
- Consistency gate (2026-09-30): `cairn_validate.py` passed every check. No DESIGN principle changed, so `cairn_impact.py` was skipped. `devtools::document()` left no diff. The branch did not touch README.Rmd, and the repo has no `_pkgdown.yml`. NEWS.md has the entry, and the branch adds no top-level file.
- Independent review (2026-09-30): three fresh reviewers ran, an Opus diff reviewer (O), a Sonnet history reviewer (B), and a Sonnet prior-review reviewer (P). No finding shows a criterion failing. Proposed dispositions follow, most severe first.
- O1, B5, P2 (follow-up): a one-string `input` with a `dim` or the class `"AsIs"` passes the rule and goes out as an array. A local probe wrote `matrix("a")` as `[["a"]]`. The diff reviewer wrote `I("a")` as `["a"]`. D-034 and D-035 strip such attributes for names and flags. It goes to one new candidate row with O2, O3, and O6.
- O2 (follow-up): a factor `input` skips both checks, so `factor(c("a", "b"))` goes out as a two-string array. This was true before the branch.
- O3 (follow-up): jsonlite cannot write a character `input` with a class such as `"foo"`. The call fails there, after the server check. This was true before the branch.
- O4 (reject): an unnamed list of strings still gets the 400. Scope leaves a list `input` to the server.
- O5 (fixed): the code comment in R/utils-args.R and the test-file header cited D-003 for leaving a list to the server. D-020 limits D-003 to fields in `...`, so both now cite D-036. The plan-owned Scope and D-036 are history and stay.
- O6 (follow-up): `lms_chat_openai()` still sends a two-string `content` that `lms_chat()` now stops. Scope leaves `lms_chat_openai()` out.
- O7 (fixed by a work-log line): the T2 line overstates which test went red for each deleted call.
- O8 (part fixed): `info = name` was added to the `expect_no_match()` in the NA loop. `expect_s3_class()` takes no `info` (LESSONS, M019), so that part is rejected.
- B1 (reject): the zero-length abort was probed on one route only. AC1 requires it, and D-036 gives the reason.
- B2 (reject): D-036 paraphrases the reason M013 gave. D-entries are history, and the paraphrase does not change the decision.
- B3, P3 (reject): the helper has no direct unit test. The profile tests internal helpers through their callers, and AC2 covers the list pass-through.
- B4 (reject): `character(0)` gets a different message from the batch and the chat functions. M013 set the two rules on purpose.
- B6 (reject): the uncommitted file was the review record in progress. It is now committed.
- P1 (fixed): Air reformatted tests/testthat/test-input-length.R, and the long comment line in R/utils-args.R was wrapped. Air also flags R/chat.R and R/utils-args.R on main, so the rest was there before the branch.
- Fix-now rerun (2026-09-30): `air format --check` passed on the test file, and `devtools::test(filter = "input-length")` passed.
