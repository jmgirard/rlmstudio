# M038: The OpenAI chat function refuses a messages value it cannot send as a list of messages

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — an exported chat function starts to reject `messages` values that it sent before
- **Branch/PR:** m038-openai-messages-guard

## Goal

A `messages` value that is not a non-empty list of named lists makes
`lms_chat_openai()` abort before the server probe. Today it goes to the
server, which answers three such shapes with garbled errors.

## Scope

**In:** a check on `messages` in `lms_chat_openai()`, above
`stop_if_no_server()` and with no condition class (D-008). A data frame with
at least one row stays accepted, because the server takes it as one message
per row. Help text at `messages`, the argument list on the conditions page,
and a NEWS entry. On 2026-09-27 the server rejected every shape the check
refuses. Some of those rejections were clear, such as an empty list or a
bare string element. The check refuses them anyway. GP4 puts input checks
on a named argument, and D-008 puts argument faults ahead of the probe.

**Out:** roles, content, and every other field inside a message stay with
the server. That includes an NA inside a string content, which the gate
declined. `lms_chat()` and `lms_chat_batch()` build their own messages from
an `input` that M013 already checks. The length rule on `input` stays its
own candidate row.

## Acceptance criteria

- [x] AC1: `lms_chat_openai()` aborts before `stop_if_no_server()` runs when
      `messages` breaks one of four rules. The error's class vector is
      `c("rlang_error", "error", "condition")`, its message names
      `messages`, and its detail names the broken rule, with one detail text
      per rule. Rule 1: `messages` is a list or a data frame. Rule 2: a data
      frame has at least one row, and any other list has at least one
      element. Rule 3: a list that is not a data frame has no names
      attribute. Rule 4: each element of such a list is a list of length one
      or more whose names are all present, not NA, and not empty. A test in
      `tests/testthat/test-arg-guards.R` mocks `is_server_running()` to
      return `FALSE` and makes any request fail the test. It runs each value
      below and asserts the detail text of each. Rule 1: `NULL`,
      `"hi"`, `c("a", "b")`, `5`, `NA`, and a function. Rule 2: a data frame
      of zero rows, and `list()`. Rule 3: a fully named list, a list with
      names that are all empty, and `list(role = "user", content = "hi")`.
      Rule 4: a string element, `c(role = "user", content = "hi")`, an
      unnamed list, a partly named list, a list with an NA name, and
      `list()`. Rule 4 also takes a bad element placed second after a good
      one.
- [x] AC2: Five `messages` values pass the check and reach the request. Two
      are data frames, one with `role` and `content` columns and one with a
      single column `x`. Three are lists of one message, whose `content` is
      one string, a list of `list(type = "text", text = ...)` parts, or the
      number `5`. A test asserts that the
      `messages` field of each sent body equals an expected value that the
      test states.
- [x] AC3: The `messages` entry on the `lms_chat_openai()` page in `man/`
      states the four rules of AC1, that a data frame with at least one row
      passes, and that the check runs before the server check. The argument
      list on the `rlmstudio-conditions` page names `messages`. `NEWS.md`
      has a bullet for the new abort.
- [x] AC4: `devtools::test()` passes with no failures, and
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T3

## Tasks

- [x] T1: Write the failing tests for AC1 and AC2 in
      `tests/testthat/test-arg-guards.R`. Use `local_no_request_allowed()`
      and `local_request_recorder()` from
      `tests/testthat/helper-mock-http.R`. Per the M026 lesson, assert the
      rule text of each detail, and plant a wrong detail once to see the
      test go red.
- [x] T2: Add `messages_fault()` and `rlm_check_messages()` to
      `R/utils-args.R`, in the form of `schema_fault()` and
      `rlm_check_schema()`. Call the check above `stop_if_no_server()` in
      `lms_chat_openai()` (`R/chat.R:347`). jsonlite writes a list with any
      names attribute, even one of empty names, as a JSON object. So
      rule 3 refuses every names attribute. Tests green, the existing
      `lms_chat()` and `lms_chat_batch()` OpenAI tests included. Per the
      M003 lesson, delete the call site in a scratch copy and see the AC1
      test go red.
- [x] T3: Write the `messages` help text (`R/chat.R:268`), add `messages`
      to the argument list at `R/conditions.R:12-13`, run
      `devtools::document()`, and add a `NEWS.md` bullet. Start the server
      and set `RLMSTUDIO_API_TOKEN` (M009 lesson). Then run
      `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: live probe on google/gemma-3-1b. A string, one unwrapped message, and a named list gave garbled server errors. A data frame and content parts worked.
- 2026-09-27: criteria audit ran in full mode and returned 9 findings. 7 were fixed in the wording, 1 became the check-depth gate question, and 1 added the conditions page to AC3.
- 2026-09-27: plan gate chose to check the list and each message over also refusing an NA in string content, because content belongs to the server. Falsified by a user whose NA content gets the misleading server error.
- 2026-09-27: plan gate chose to check the list and each message over checking only the garbled shapes, because an argument fault is knowable offline. Falsified by a working call that the check refuses.
- 2026-09-27: plan gate chose to keep data frames over refusing them, because they work today. Falsified by a data frame that sends a malformed message.
- 2026-09-27: implement started on branch m038-openai-messages-guard. No question gate, because the plan fixes the four rules and says one detail text per rule.
- 2026-09-27: T1 done. AC1 test red (the probe is reached), AC2 test green before the change. Three existing calls that sent `list()` or `"hi"` as messages now send one valid message (minor amendment).
- 2026-09-27: T2 done. `rlm_check_messages()`, `messages_fault()`, and `is_named_message()` added. The call runs after the model check. devtools::test(): 10328 passed, 0 failed. In a scratch copy, deleting the call site and giving rule 3 the rule 2 detail each turned the AC1 test red.
- 2026-09-27: T3 done. `messages` help, conditions page, and NEWS bullet written, docs regenerated. With the server on and the token set: devtools::test() 10328 passed, 0 failed. devtools::check() 0 errors, 0 warnings, 0 notes.
- 2026-09-27: claim audit: 22 claims read, 2 corrected — NEWS.md, R/chat.R, man/lms_chat_openai.Rd. An empty message aborts although the NEWS wording let it pass, and an NA cell of a data frame is left out of its message. The reader re-read both corrections once and found that both hold. devtools::test() after the fix: 10328 passed, 0 failed.
- 2026-09-27: status set to review.

## Decisions

## Review

Evidence gathered 2026-09-27 on the branch head 28a95ee, which contains `origin/main`. LM Studio server on, `RLMSTUDIO_API_TOKEN` set.

- AC1: `devtools::test()` passed 10328, failed 0, skipped 0. The test "a messages value that breaks a rule aborts before the server probe" runs all 18 values that AC1 lists. For each value it asserts the detail text of its rule, stated in the test, and asserts that the other three details are absent. It pins the class vector to `c("rlang_error", "error", "condition")`. It mocks `is_server_running()` to return `FALSE`, fails on any request, and asserts a probe count of 0. The code read shows the call at `R/chat.R:369`, above `stop_if_no_server()`. The implement work log records the test going red with the call site deleted and with a wrong rule 3 detail.
- AC2: in the same run, the test "a messages value that keeps every rule reaches the request" sends the five values that AC2 lists. It asserts one request for each. The test parses each sent body back from `httr2::req_dry_run()`. It asserts that the `messages` field equals the value that the test states.
- AC3: a read of `man/lms_chat_openai.Rd` shows the `messages` entry. It states the four rules of AC1 as a list. It states that a data frame with at least one row passes. It states that the call aborts before it checks for a running server. `man/rlmstudio-conditions.Rd` names `messages` in its argument list. `NEWS.md` has a bullet for the new abort. `devtools::document()` gave no diff.
- AC4: `devtools::test()` passed 10328, failed 0, skipped 0. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.

Consistency gate: `cairn_validate.py` exited 0. `devtools::document()` gave no diff, and its `@aliases` message at `R/conditions.R:258` is the same on `main`. README.Rmd and README.md are unchanged on the branch. The repo has no pkgdown site. The branch adds no top-level file. `NEWS.md` has the entry, with no milestone number. No principle text in DESIGN.md changed, so the impact report was skipped.

Independent review: three fresh reviewers ran. The diff reviewer reported 8 findings. The history reviewer and the prior-review reviewer reported none, and GitHub holds no review threads.
