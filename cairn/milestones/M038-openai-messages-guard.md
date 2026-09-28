# M038: The OpenAI chat function refuses a messages value it cannot send as a list of messages

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — an exported chat function starts to reject `messages` values that it sent before
- **Branch/PR:** —

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

- [ ] AC1: `lms_chat_openai()` aborts before `stop_if_no_server()` runs when
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
- [ ] AC2: Five `messages` values pass the check and reach the request. Two
      are data frames, one with `role` and `content` columns and one with a
      single column `x`. Three are lists of one message, whose `content` is
      one string, a list of `list(type = "text", text = ...)` parts, or the
      number `5`. A test asserts that the
      `messages` field of each sent body equals an expected value that the
      test states.
- [ ] AC3: The `messages` entry on the `lms_chat_openai()` page in `man/`
      states the four rules of AC1, that a data frame with at least one row
      passes, and that the check runs before the server check. The argument
      list on the `rlmstudio-conditions` page names `messages`. `NEWS.md`
      has a bullet for the new abort.
- [ ] AC4: `devtools::test()` passes with no failures, and
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T3

## Tasks

- [ ] T1: Write the failing tests for AC1 and AC2 in
      `tests/testthat/test-arg-guards.R`. Use `local_no_request_allowed()`
      and `local_request_recorder()` from
      `tests/testthat/helper-mock-http.R`. Per the M026 lesson, assert the
      rule text of each detail, and plant a wrong detail once to see the
      test go red.
- [ ] T2: Add `messages_fault()` and `rlm_check_messages()` to
      `R/utils-args.R`, in the form of `schema_fault()` and
      `rlm_check_schema()`. Call the check above `stop_if_no_server()` in
      `lms_chat_openai()` (`R/chat.R:347`). jsonlite writes a list with any
      names attribute, even one of empty names, as a JSON object. So
      rule 3 refuses every names attribute. Tests green, the existing
      `lms_chat()` and `lms_chat_batch()` OpenAI tests included. Per the
      M003 lesson, delete the call site in a scratch copy and see the AC1
      test go red.
- [ ] T3: Write the `messages` help text (`R/chat.R:268`), add `messages`
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

## Decisions

## Review
