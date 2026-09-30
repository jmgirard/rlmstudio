# M062: A chat call aborts on a text input that is not one prompt

- **Status:** in-progress
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

- [ ] AC1: `lms_chat()`, `lms_chat_openresponses()`, and `lms_chat_native()` abort when `input` is a character vector that holds no NA and whose length is not one. The message names `input`, states the length given, and names `lms_chat_batch()`. The abort has no condition class. It comes before the check for a running server, and no request is sent. A vector that holds an NA gets the NA message of M013, whatever its length. Tests pass `character(0)`, `c("a", "b")`, and `c("a", NA)` to each function, and to `lms_chat()` on each of its three `api_type` values. They assert the message and that the server check was not called.
- [ ] AC2: The rule lets two forms through to the request body. For each of the three functions, and for `lms_chat()` on each of its three routes, a test reads the serialized request body. The input `"hi"` is there as the JSON string `"hi"`. The input `list(list(type = "message", role = "user", content = "hi"))`, an unnamed list of one message object, is there as a JSON array of one object. The body field is `input`, and on the OpenAI route it is the `content` of the user message.
- [ ] AC3: `lms_chat_batch()` with `inputs = c("a", "b")` sends two requests, and the `input` field of each is one JSON string, `"a"` and then `"b"`. A test reads both serialized bodies.
- [ ] AC4: The `input` entry on the help pages of the three functions states the length rule and names `lms_chat_batch()` for many prompts. NEWS.md has one entry that names the three functions and states the rule. It also states that before, a two-string `input` went to the server and got a 400.
- [ ] AC5: `devtools::test()` reports 0 failures and 0 errors. `devtools::check()`, run with `RLMSTUDIO_API_TOKEN` set, reports 0 errors and 0 warnings.

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

## Decisions

## Review
