# M003: Class tests for the ten server-down abort sites

- **Status:** planned
- **Priority:** normal
- **Depends on:** none
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** none
- **Surface tier:** internal. The deliverable is test coverage over error behavior that already shipped, and no exported behavior changes.
- **Branch/PR:** none

## Goal

Assert the `rlmstudio_no_server` condition class at every `R/` call site that aborts on a stopped server. No site then rests on a code read alone.

## Scope

**In:** testthat tests that assert the condition class `rlmstudio_no_server`. One test covers each function that holds a `stop_if_no_server()` call site in `R/`. The exported dispatcher `lms_chat()` gets tests too. Each test mocks `is_server_running()` to return `FALSE`. The pattern is already in `tests/testthat/test-download.R:1`. This milestone changes no file under `R/`.

**Out:** a fix for any defect that the new tests expose. A site that does not abort, or that aborts without the class, goes to `/hotfix`. That path gives it a regression test and a merge gate of its own. Also out: an assertion on the abort message wording at each site. That stays with the one existing test at `tests/testthat/test-download.R:11`, because the message lives in one place at `R/serve.R:277`. Also out: a guard that keeps future call sites covered on its own. That work goes to a ROADMAP candidate row.

## Acceptance criteria

- [ ] AC1: Run `grep -rn "stop_if_no_server(" R/`. It reports ten call sites. When `is_server_running()` returns `FALSE`, every function that holds one of those sites aborts with condition class `rlmstudio_no_server`. A testthat test names that class for each of those functions.
- [ ] AC2: When `is_server_running()` returns `FALSE`, `lms_chat()` passes the `rlmstudio_no_server` condition class through to its caller.
- [ ] AC3: The `verify` slot of `cairn/PROFILE.md` is clean. `Rscript -e 'devtools::test()'` reports 0 failures and 0 warnings. No test that this milestone adds is skipped.

## Coverage

- AC1 → T1, T2, T3, T5
- AC2 → T4, T5
- AC3 → T5

## Tasks

- [ ] T1: Add class tests to `tests/testthat/test-chat.R` for four functions. They are `lms_chat_openresponses()` at `R/chat.R:112` and `lms_chat_openai()` at `R/chat.R:228`. The other two are `lms_chat_native()` at `R/chat.R:295` and `lms_chat_batch()` at `R/chat.R:365`. Each test mocks `is_server_running` to `FALSE`. Each test asserts `class = "rlmstudio_no_server"`. Assert the class alone. Do not assert the message text.
- [ ] T2: Add the class test for `lms_load()` at `R/load.R:56` to `tests/testthat/test-load.R`.
- [ ] T3: Add class tests for `lms_unload()` at `R/unload.R:35` and `lms_unload_all()` at `R/unload.R:103`. Put them in a new file `tests/testthat/test-unload.R`.
- [ ] T4: Add three `lms_chat()` tests to `tests/testthat/test-chat.R`. Write one test per `api_type` value: `openresponses`, `openai`, and `native`. Each test asserts that the class reaches the caller through the dispatcher.
- [ ] T5: Run `grep -rn "stop_if_no_server(" R/` again. Make sure that every function holding a reported line now has a class test. Run `Rscript -e 'devtools::test()'` clean. Make sure that `git diff --stat` against the branch base names no file under `R/`.

## Work log

- 2026-09-18: created by /milestone-plan. Promoted from the ROADMAP candidate row added 2026-09-17, which came from M001 review finding 11. The row said seven sites. The enumerating grep reports ten. Three of them already have tests in test-list.R and test-download.R.
- 2026-09-18: criteria audit ran in reduced mode for the internal tier, with a fresh-context [O] reader. It returned three findings. Two were fixed here. A criterion that bound the diff rather than the deliverable was dropped, and its constraint moved to Scope and T5. AC1's procedure was repaired to the paren form of the grep. The reader found that the paren-less form disagreed with the clause that subtracted the definition line. The third finding went to the gate as the dispatcher question.
- 2026-09-18: plan gate chose one dispatcher criterion plus three per-mode tasks. It rejected a criterion that named all three `api_type` values. The audit read the three-way form as a second promise, one per dispatch route, of what AC1 already covers directly. Falsified by a dispatch route that reaches the server check by a path the other three functions do not share.
- 2026-09-18: plan gate chose to route an exposed defect to /hotfix. It rejected fixing the defect inside this milestone. A behavior fix needs its own regression test and merge gate, and it ends the tests-only boundary. Falsified by a defect whose fix cannot be separated from the test that finds it.
- 2026-09-18: plan gate chose to assert the condition class alone. It rejected asserting the message text at each site as well. The message is centralized at `R/serve.R:277`, and one existing test covers it. Falsified by a site that builds its own abort message instead of calling the shared helper.

## Decisions

## Review
