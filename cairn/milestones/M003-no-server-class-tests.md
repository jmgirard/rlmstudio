# M003: Class tests for the ten server-down abort sites

- **Status:** review
- **Priority:** normal
- **Depends on:** none
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** none
- **Surface tier:** internal. The deliverable is test coverage over error behavior that already shipped, and no exported behavior changes.
- **Branch/PR:** `m003-no-server-class-tests`

## Goal

Assert the `rlmstudio_no_server` condition class at every `R/` call site that aborts on a stopped server. No site then rests on a code read alone.

## Scope

**In:** testthat tests that assert the condition class `rlmstudio_no_server`. One test covers each function that holds a `stop_if_no_server()` call site in `R/`. The exported dispatcher `lms_chat()` gets tests too. Each test mocks `is_server_running()` to return `FALSE`. The pattern is already in `tests/testthat/test-download.R:1`. This milestone changes no file under `R/`.

**Out:** a fix for any defect that the new tests expose. A site that does not abort, or that aborts without the class, goes to `/hotfix`. That path gives it a regression test and a merge gate of its own. Also out: an assertion on the abort message wording at each site. That stays with the one existing test at `tests/testthat/test-download.R:11`, because the message lives in one place at `R/serve.R:277`. Also out: a guard that keeps future call sites covered on its own. That work goes to a ROADMAP candidate row.

## Acceptance criteria

- [x] AC1: Run `grep -rn "stop_if_no_server(" R/`. It reports ten call sites. When `is_server_running()` returns `FALSE`, every function that holds one of those sites aborts with condition class `rlmstudio_no_server`. A testthat test names that class for each of those functions.
- [x] AC2: When `is_server_running()` returns `FALSE`, `lms_chat()` passes the `rlmstudio_no_server` condition class through to its caller.
- [x] AC3: The `verify` slot of `cairn/PROFILE.md` is clean. `Rscript -e 'devtools::test()'` reports 0 failures and 0 warnings. No test that this milestone adds is skipped.

## Coverage

- AC1 → T1, T2, T3, T5
- AC2 → T4, T5
- AC3 → T5

## Tasks

- [x] T1: Add class tests to `tests/testthat/test-chat.R` for four functions. They are `lms_chat_openresponses()` at `R/chat.R:112` and `lms_chat_openai()` at `R/chat.R:228`. The other two are `lms_chat_native()` at `R/chat.R:295` and `lms_chat_batch()` at `R/chat.R:365`. Each test mocks `is_server_running` to `FALSE`. Each test asserts `class = "rlmstudio_no_server"`. Assert the class alone. Do not assert the message text.
- [x] T2: Add the class test for `lms_load()` at `R/load.R:56` to `tests/testthat/test-load.R`.
- [x] T3: Add class tests for `lms_unload()` at `R/unload.R:35` and `lms_unload_all()` at `R/unload.R:103`. Put them in a new file `tests/testthat/test-unload.R`.
- [x] T4: Add three `lms_chat()` tests to `tests/testthat/test-chat.R`. Write one test per `api_type` value: `openresponses`, `openai`, and `native`. Each test asserts that the class reaches the caller through the dispatcher.
- [x] T5: Run `grep -rn "stop_if_no_server(" R/` again. Make sure that every function holding a reported line now has a class test. Run `Rscript -e 'devtools::test()'` clean. Make sure that `git diff --stat` against the branch base names no file under `R/`.

## Work log

- 2026-09-18: created by /milestone-plan. Promoted from the ROADMAP candidate row added 2026-09-17, which came from M001 review finding 11. The row said seven sites. The enumerating grep reports ten. Three of them already have tests in test-list.R and test-download.R.
- 2026-09-18: criteria audit ran in reduced mode for the internal tier, with a fresh-context [O] reader. It returned three findings. Two were fixed here. A criterion that bound the diff rather than the deliverable was dropped, and its constraint moved to Scope and T5. AC1's procedure was repaired to the paren form of the grep. The reader found that the paren-less form disagreed with the clause that subtracted the definition line. The third finding went to the gate as the dispatcher question.
- 2026-09-18: plan gate chose one dispatcher criterion plus three per-mode tasks. It rejected a criterion that named all three `api_type` values. The audit read the three-way form as a second promise, one per dispatch route, of what AC1 already covers directly. Falsified by a dispatch route that reaches the server check by a path the other three functions do not share.
- 2026-09-18: plan gate chose to route an exposed defect to /hotfix. It rejected fixing the defect inside this milestone. A behavior fix needs its own regression test and merge gate, and it ends the tests-only boundary. Falsified by a defect whose fix cannot be separated from the test that finds it.
- 2026-09-18: plan gate chose to assert the condition class alone. It rejected asserting the message text at each site as well. The message is centralized at `R/serve.R:277`, and one existing test covers it. Falsified by a site that builds its own abort message instead of calling the shared helper.

- 2026-09-18: T1 done. Four class tests added to `tests/testthat/test-chat.R`. Each test was proven able to fail: with the mock flipped to a running server, all four go red. `devtools::test(filter = "chat")` reports 0 failures, 0 warnings, 0 skips.
- 2026-09-18: T2 and T3 done. One class test added to `tests/testthat/test-load.R` for `lms_load()`, and a new file `tests/testthat/test-unload.R` holds two for `lms_unload()` and `lms_unload_all()`. All three were proven able to fail with the mock flipped to a running server. `devtools::test(filter = "load|unload")` reports 0 failures, 0 warnings, 0 skips.
- 2026-09-18: T4 done. Three `lms_chat()` dispatcher tests added to `tests/testthat/test-chat.R`, one per `api_type` value. All three were proven able to fail with the mock flipped to a running server. `devtools::test(filter = "chat")` reports 0 failures, 0 warnings, 0 skips.
- 2026-09-18: T5 done. The enumerating grep reports the same ten call sites in ten distinct functions, and every one of those functions now has a class test. `Rscript -e 'devtools::test()'` reports 0 failures, 0 warnings, 0 skips, 68 passes. `git diff --name-only main...HEAD` names no file under `R/`.
- 2026-09-18: claim audit: not owed — internal tier.
- 2026-09-18: review checkpoint. All three acceptance criteria verified with fresh evidence and ticked. Consistency gate clean. Three fresh-context reviewers are still running.
- 2026-09-18: review triage. Six findings, all from the diff-bug lens. One fixed now, one routed to a candidate row, four rejected. No finding met the return floor. Suite and check re-run clean after the fix.

## Decisions

## Review

- 2026-09-18 AC1: the enumerating grep reports ten call sites in ten distinct functions. They are `lms_load`, `lms_chat_openresponses`, `lms_chat_openai`, `lms_chat_native`, `lms_chat_batch`, `lms_unload`, `lms_unload_all`, `list_models`, `lms_download`, and `lms_download_status`. Each of the ten has a test that mocks `is_server_running` to `FALSE` and asserts `class = "rlmstudio_no_server"`. Those tests sit in `test-load.R`, `test-chat.R`, `test-unload.R`, `test-list.R`, and `test-download.R`. All ten pass in the run recorded under AC3.
- 2026-09-18 AC2: `tests/testthat/test-chat.R:151`, `:163`, and `:171` call `lms_chat()` with `api_type` set to `openresponses`, `openai`, and `native`. Each mocks `is_server_running` to `FALSE` and asserts that the caller receives class `rlmstudio_no_server`. All three pass in the run recorded under AC3.
- 2026-09-18 AC3: `Rscript -e 'devtools::test()'` reports 0 failures, 0 warnings, 0 skips, 68 passes. The skip count of 0 means that no test this milestone added is skipped. `Rscript -e 'devtools::document()'` produced no diff, which is the other half of the `verify` slot.
- 2026-09-18 consistency gate: `cairn_validate.py` passes with exit 0, all checks green and every advisory OK. No `DESIGN.md` principle changed, so `cairn_impact.py` was not owed. Toolchain slot: `document()` produced no diff. No generated file was hand-edited. `README.md` is in sync and this branch does not touch it. The repo has no `_pkgdown.yml`. The branch makes no user-visible change, so no `NEWS.md` entry is owed. The branch adds no top-level file, so no `.Rbuildignore` entry is owed. `Rscript -e 'devtools::check()'` reports 0 errors, 0 warnings, and 0 notes.

### Independent review

Three fresh-context reviewers ran in parallel. The blame-history lens reported no finding against the change. The prior-review lens reported no prior-review evidence on the touched files, so it contributed no findings. The probe `gh api repos/jmgirard/rlmstudio/pulls/comments?per_page=1` returned an empty list, so no pull-request thread walk was warranted. The diff-bug lens reported six findings, ranked below as it ranked them.

- Finding 1 (diff-bug): three of the ten tests survive deletion of the call site they pin. `lms_load()` and `lms_unload_all()` both delegate to `list_models()`, and `lms_chat_batch()` delegates to `lms_chat()`. Each delegate runs its own server check, so the abort still carried the class with the site removed. This does not falsify AC1, but it misses the Goal for three sites. **Disposition: fixed now.** The `lms_load()` test now passes `force = TRUE`, which skips the `list_models()` branch. The `lms_unload_all()` test now also mocks `list_models`. The `lms_chat_batch()` test now also mocks `lms_chat`. Each fix was proven able to fail. A scratch copy of the package had `R/load.R:56`, `R/unload.R:103`, and `R/chat.R:365` deleted. Against that copy, each of the three tests goes red, one failure per file.
- Finding 2 (diff-bug): on a machine with no LM Studio server, the new tests pass identically with the mock line deleted. A green run alone therefore does not prove the mock is wired. **Disposition: rejected.** The reviewer states this is the established pattern at `tests/testthat/test-download.R:1` and not a regression. The flipped-mock evidence in the work log, and the mutant runs under finding 1, both show the bindings are live.
- Finding 3 (diff-bug): `tests/testthat/test-unload.R` is a new file for two exported functions and covers only the server-down branch. The non-2xx response branches and the "no models loaded" path stay untested. **Disposition: follow-up.** The gap is outside this milestone's scope. A candidate row is written in the post-merge hygiene pass.
- Finding 4 (diff-bug): the three `lms_chat()` dispatcher tests add little beyond the direct tests, because `lms_chat()` holds no server check of its own. **Disposition: rejected.** T4 and AC2 called for one test per `api_type` value, and the plan gate recorded that choice. This is an intentional change the plan called for, not a defect in how it was carried out.
- Finding 5 (diff-bug): T5 names `git diff --stat` against the branch base, and the work log records `git diff --name-only main...HEAD`. **Disposition: rejected.** The two forms are equivalent here, the work log is append-only history, and the constraint itself holds. The review re-ran the check: `git diff --name-only main...HEAD` names no file under `R/`.
- Finding 6 (diff-bug): the new tests call `local_mocked_bindings()` bare while `tests/testthat/test-list.R:2` uses the `testthat::` prefix. **Disposition: rejected.** A pure style point on an already mixed repo, and the new code matches its nearest neighbors.

No finding demonstrated an acceptance criterion failing. None is a defect in what the package does for its users. No finding met the return floor.

- 2026-09-18 re-verification after the finding 1 fix: `Rscript -e 'devtools::test()'` reports 0 failures, 0 warnings, 0 skips, 68 passes. `Rscript -e 'devtools::check()'` reports 0 errors, 0 warnings, and 0 notes.
