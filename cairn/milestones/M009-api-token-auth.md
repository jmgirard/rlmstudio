# M009: The package can authenticate to LM Studio

- **Status:** review
- **Branch/PR:** m009-api-token-auth / https://github.com/jmgirard/rlmstudio/pull/10
- **Priority:** high
- **Depends on:** none
- **Driving RR:** —
- **Principles touched:** IP1, GP1, GP4
- **Resolves:** none
- **Surface tier:** user-facing. Eleven exported functions gain a `token` argument, and a new help topic ships.

## Goal

Every exported function that reaches the LM Studio REST API can send an API token, so the package works against a server that requires authentication.

## Scope

**In:** A token resolver that `lms_client()` reads. It reads the explicit argument first, then the `rlmstudio.token` option, then the `RLMSTUDIO_API_TOKEN` environment variable. A `token` argument on the eleven exported functions that can reach the REST API. The header is set through `httr2::req_auth_bearer_token()`, which marks it redacted. A rejected call gains a hint that names what to set. A new `rlmstudio_token` help topic, its pkgdown row, and a `NEWS.md` entry. When `httpuv` is absent under CI, `request_target()` fails rather than skips, so the new header assertions cannot pass by not running.

**Out:** A wrapper for `/v1/embeddings`, which stays a candidate row. A tighter TCP probe that confirms the listener is LM Studio, which stays a candidate row. Token creation and token management, which happen in the LM Studio app. Every other field and endpoint the API survey lists. Those live in `cairn/references/lmstudio-api-surface.md` and in its candidate rows.

## Acceptance criteria

- [x] AC1: `lms_client()` builds a request. If a token resolves, that request carries the header `Authorization: Bearer <token>`. If no token resolves, that request carries no `Authorization` header. If the `token` argument is given, the resolver returns it over an option and a variable that are both set to other values. If no argument is given, the resolver returns the option over a variable set to another value. If only the variable is set, the resolver returns the variable. If none of the three is set, the resolver returns no token. A test drives all four states. The test pins ambient state with `withr::local_envvar()` and `withr::local_options()`. The test reads the header from `httr2::req_dry_run(redact_headers = FALSE)`.
- [x] AC2: The test's wrapper table lists eleven exported functions. They are `list_models()`, `lms_load()`, `lms_unload()`, `lms_unload_all()`, `lms_download()`, `lms_download_status()`, `lms_chat()`, `lms_chat_batch()`, `lms_chat_openresponses()`, `lms_chat_openai()`, and `lms_chat_native()`. If a listed function is called with `token = "<token>"`, every request it issues carries `Authorization: Bearer <token>`. If no token resolves, every request it issues carries no `Authorization` header. Each function is driven through the recorder in `tests/testthat/helper-mock-http.R`. The header is read off every captured request. The claim covers these eleven functions and no function added later.
- [x] AC3: A test names two renderings. The first is the printed form of a request that `lms_client()` built with a token. The second is the abort message of an `rlmstudio_api_error` raised from a failed request built that way. The token string appears in neither rendering.
- [x] AC4: A failed response with HTTP status 401 aborts with condition class `rlmstudio_api_error`. A failed response with status 403 aborts the same way. Each abort carries a `status` field equal to the response status. If the request sent no token, the message names `RLMSTUDIO_API_TOKEN`. If the request sent a token, the message states that the server rejected the token, and the message does not name the variable. A failed response with status 400 aborts with a message that does neither. All five cases are driven through the recorder.
- [x] AC5: `?rlmstudio_token` returns exactly one help topic. That topic names the argument, the option, the variable, and the order the resolver reads them in. Each of the eleven functions documents its `token` argument on its own help page. `pkgdown/_pkgdown.yml` lists the new topic. `NEWS.md` carries an entry for the change.
- [x] AC6: An LM Studio server runs with authentication enabled. When `RLMSTUDIO_API_TOKEN` supplies the token, `list_models()` and `lms_chat_native()` each succeed. When the `token` argument supplies it, each succeeds again. When no token resolves, each aborts with class `rlmstudio_api_error` and `status` 401. The no-token runs pin ambient state with `withr::local_envvar()`.

## Coverage

- AC1 → T1
- AC2 → T2, T3, T4
- AC3 → T1, T5
- AC4 → T6
- AC5 → T7
- AC6 → T8

## Tasks

- [x] T1: Add a `rlm_token()` resolver and a `token` argument to `lms_client()` (`R/chat.R:469`). Set the header with `httr2::req_auth_bearer_token()`. Test the four resolution states and the two header states. Use a dummy token string, because `redact_headers = FALSE` puts the literal value into failure output.
- [x] T2: Add a `token` argument to the eight direct callers of `lms_client()`. They are at `R/chat.R:131`, `R/chat.R:240`, `R/chat.R:305`, `R/list.R:56`, `R/load.R:118`, `R/unload.R:48`, `R/download.R:58`, and `R/download.R:132`. Forward the argument explicitly from the three delegators, `lms_chat()`, `lms_chat_batch()`, and `lms_unload_all()`. Do not let a token ride `...`, because dots go into the request body (GP4). A token there is sent as a body field.
- [x] T3: Extend `request_target()` to return the request headers unredacted. When `httpuv` is absent and `CI` is set, make the helper raise rather than skip. CI installs `httpuv`, so neither branch arises there on its own. Split the skip decision into a testable predicate rather than mocking `skip_if_not_installed()`. Test both branches.
- [x] T4: Assert the header on every request that each of the eleven functions issues, through the recorder. Two traps apply. `lms_load()` without `force = TRUE` sends two requests (M008). A test that mocks a delegate still passes with the delegating call site deleted (M003). For `lms_chat()`, `lms_chat_batch()`, and `lms_unload_all()`, delete the forwarding line in a scratch copy and make sure that the test goes red.
- [x] T5: Test that `print()` of a token-carrying request does not contain the token string. Test that the abort message of a failure raised from such a request does not contain it either.
- [x] T6: Give `rlm_abort_api()` (`R/utils-api-error.R:80`) a third argument carrying the token that was used. Pass it from the eight abort sites. Add the status-conditional hint. Test 401 and 403 with a token and without one, and test 400 as the silent control.
- [x] T7: Write the `rlmstudio_token` doc-only topic with `@name` and `@aliases`. M007 found that a doc-only topic is reachable only under its `@name`. Add `@param token` to the eleven help pages. Add the pkgdown row beside `rlmstudio-conditions`. Write the `NEWS.md` entry. Run `devtools::document()`.
- [x] T8: Run the six AC6 cases against a live LM Studio with authentication enabled. Record the commands and their output in the Review section.

## Work log

- 2026-09-19: created by /milestone-plan.
- 2026-09-19: plan gate chose a `token` argument on the eleven exported functions over reading the environment alone. The reason is that `...` goes into the request body, which leaves an internal-only argument unreachable by a user. Falsified by evidence that no user needs a per-call or per-host token.
- 2026-09-19: plan gate chose pinning the rejected-call hint wording in a test over testing only the class and the status, because an untested message can drift. Falsified by a test that breaks under a rewording that changes no behavior.
- 2026-09-19: plan gate chose folding the `request_target()` CI-skip fix into this milestone over leaving it a candidate row. The reason is that every new header assertion reads through that helper, and otherwise passes by not running. Falsified by evidence that every CI image carries `httpuv`.
- 2026-09-19: plan chose `httr2::req_auth_bearer_token()` over `httr2::req_headers()`. A session run showed that it renders as `<REDACTED>` under `print(req)`, and that it yields the literal value only under `redact_headers = FALSE`. Falsified by httr2 dropping that redaction.
- 2026-09-19: plan chose `RLMSTUDIO_API_TOKEN` over the `LM_API_TOKEN` name that the LM Studio curl examples use, because the package already reads `RLMSTUDIO_LMS_PATH` and `RLMSTUDIO_ALLOW_INSTALL`. Falsified by LM Studio standardizing a client-side variable name.
- 2026-09-19: criteria audit ran in full mode, in a fresh-context [O] reader, over two rounds. Round one returned six findings. Four were fixed at the plan, and two went to the question gate. Round two ruled the `request_target()` criterion instrument-bound and moved it to T3. It also required AC6 to name its wrappers and its token sources. For the case where a token was sent, it required AC4 to fix the hint behavior.
- 2026-09-20: /milestone-implement started. Branch m009-api-token-auth cut from main.
- 2026-09-20: gate chose placing `token` after `...` as a named-only argument over placing it beside `host`. Several functions carry named arguments after `host`, and inserting there shifts their positions. Falsified by evidence that no caller passes those arguments by position.
- 2026-09-20: gate chose passing a true/false flag to `rlm_abort_api()` over passing the token string. The secret then never enters the function that builds the user-facing message. This narrows T6, which had said the helper carries the token. Falsified by a hint that needs the token value itself.
- 2026-09-20: gate chose the longer rejected-call hint wording. With no token sent, the hint is `Set the RLMSTUDIO_API_TOKEN environment variable or pass the token argument to send an API token`. With a token sent, it is `The server rejected the API token that was sent`. Status 400 gets no hint. Falsified by a user report that the wording is unclear.
- 2026-09-20: T1 done. `rlm_token()` added in `R/utils-token.R`, and a `token` argument added to `lms_client()`. The header is set with `httr2::req_auth_bearer_token()`. Eight tests in `tests/testthat/test-token.R`. Dropping the bearer call turns three of them red. Suite 161 pass, 0 fail.
- 2026-09-20: T2 done. Nine of the eleven exported functions take `token` as a named-only argument after `...`. `list_models()` and `lms_download_status()` have no dots and take it last. `lms_unload_all()` forwards to both `list_models()` and `lms_unload()`. When `force` is FALSE, `lms_load()` forwards to the `list_models()` call it makes. Suite 161 pass, 0 fail.
- 2026-09-20: T3 done. `request_target()` now returns a `headers` field, read with `redact_headers = FALSE`. The skip decision moved into `httpuv_absence_action()`, which returns "run", "fail", or "skip" from two arguments. A missing `httpuv` under CI now raises. Eight tests in `tests/testthat/test-mock-http-helper.R`. Suite 169 pass, 0 fail.
- 2026-09-20: T4 done. `tests/testthat/test-token-wrappers.R` drives all eleven functions through the recorder and reads the header off every request each one sends. No delegate is mocked, so `lms_unload_all()` and `lms_load()` capture the `list_models()` request too. A fourth test drives `lms_chat()` on all three of its routes. Every one of the fifteen `token = token` forwarding sites, blanked one at a time, turns at least one test red. Suite 220 pass, 0 fail.
- 2026-09-20: T5 done. Two tests in `test-token.R`. The print test asserts that the header is present and redacted, so the negative cannot pass on a request that carries no header. The abort test asserts the condition class and the 401 status before it reads the message. A token sent under a header name httr2 does not redact turns six tests red. A leak appended to the abort message turns one red. Suite 226 pass, 0 fail.
- 2026-09-20: T6 done. `rlm_abort_api()` takes a `token_sent` flag, and the hint text lives in `api_error_hint()`. All eight abort sites report the flag. Eleven tests in `tests/testthat/test-token-rejected.R` cover 401 and 403 with and without a token, 400 as the silent control, and a token resolved from the environment. Four planted defects each turn a test red: no hint, a hint on every status, swapped branches, and a call site that stops reporting the flag. Suite 250 pass, 0 fail.
- 2026-09-20: T5 and T6 narrowed the token-hiding assertions to `conditionMessage()` after the printed backtrace was found to echo the caller's own literal. See the Decisions section.
- 2026-09-20: T7 done. The pkgdown reference index gains an Authentication section holding `rlmstudio_token`. `NEWS.md` gains three bullets. A new test asserts that `token` sits after the dots on the nine functions that take dots. It sits last on the two that do not. That test is what the NEWS claim about argument position rests on. `pkgdown::check_pkgdown()` reports no problems. Eleven man pages carry a `token` item. Suite 272 pass, 0 fail.
- 2026-09-20: minor reorder. The `rlmstudio_token` topic and the eleven `@param token` lines moved from T7 into T2, because `devtools::document()` reports an unresolved link until the topic exists. T7 keeps the pkgdown row and the NEWS entry.
- 2026-09-20: claim audit: 58 claims read, 0 corrected — NEWS.md, R/token.R, R/utils-api-error.R, R/chat.R, R/download.R, R/list.R, R/load.R, R/unload.R, pkgdown/_pkgdown.yml, tests/testthat/helper-mock-http.R, tests/testthat/test-token.R, tests/testthat/test-token-wrappers.R, tests/testthat/test-token-rejected.R, tests/testthat/test-mock-http-helper.R.
- 2026-09-20: the claim audit raised two prose items that were accurate but weak. The `api_error_hint()` comment named a test that did not exist, so the test was written. The httpuv comment said CI installs httpuv. That holds through Suggests on the two R CMD check workflows, and only through devtools on the headless one. The comment now says so. Suite 274 pass, 0 fail. `devtools::check()` reports 0 errors, 0 warnings, 0 notes.
- 2026-09-20: T8 done. All six AC6 cases pass against a live LM Studio server with authentication on. Before the run, the server was seen to reject an unauthenticated call with 401 and to accept a bearer token with 200. `list_models()` and `lms_chat_native()` each succeeded with the token in `RLMSTUDIO_API_TOKEN`. Each succeeded again with the token passed as the argument. When no token resolved, each aborted with class `rlmstudio_api_error` and status 401. The no-token cases pinned ambient state with `withr`. The same run's successful cases show the server was answering, so the two 401 results are not a server-down artifact.
- 2026-09-20: minor deviation on T8. The task said to record the run in the Review section. That section belongs to `/milestone-review` alone, so the outcome is recorded here instead. Review produces its own fresh evidence for AC6 in any case.
- 2026-09-20: the live run needed two changes to the machine. The local server was started on port 1234. The only model on disk was an embedding model, and `lms_chat_native()` needs an LLM, so `google/gemma-3-1b` was downloaded. The user chose that model at a gate.
- 2026-09-20: `devtools::check()` now fails on this machine. Both vignettes start the server and make live API calls while they build. With authentication on, those calls get 401. The package reads `RLMSTUDIO_API_TOKEN` on its own, so the vignettes build when that variable is set. The user chose to re-supply the token and run the check with it set. That run reports 0 errors, 0 warnings, 0 notes, and both vignettes re-built against the authenticated server. The token file was deleted after the run.
- 2026-09-20: blocked on T8. The six live cases need an LM Studio server with authentication enabled. Nothing answers on `http://localhost:1234` in this session, and `lms` is not on the PATH. Turning on authentication and issuing a token are both actions in the LM Studio app. The user chose to mark the milestone blocked rather than start a server now.
- 2026-09-20: /milestone-review started. The default branch had not moved since the branch was cut, so nothing was merged in before evidence was gathered. No PR existed.
- 2026-09-20: all six criteria verified with fresh evidence and ticked against it. Suite 281 pass, 0 fail, 0 skip. `devtools::check()` reports Status OK against an authenticated server.
- 2026-09-20: consistency gate green. `cairn_validate` passes every check with no advisory. `document()` produces no diff and `check_pkgdown()` reports no problems.
- 2026-09-20: three fresh-context reviewers returned eight findings between them. Five were fixed on the branch, two became candidate rows, and one was rejected as the criterion working as planned. No finding met the return floor.
- 2026-09-20: D-006 recorded. It narrows D-005 on the httpuv skip, which the history lens and the prior-review lens both flagged as stale.
- 2026-09-20: step-7 approval: m009-api-token-auth approved for merge.
- 2026-09-20: PR #10 opened. Every check passes except `macos-latest (release)`, which fails in `setup-r-dependencies` before the package is built. pak carries `mac.cran.dev` as a secondary source for macOS binaries. That mirror answers 404 for `knitr_1.52` and `xfun_0.61`. pak writes the error page to disk as the archive. Two runs failed the same way. The repo's workflow configures no mirror, so nothing on this branch can fix it.
- 2026-09-20: the user chose to wait for the mirror to sync rather than merge past the red check or change CI. The merge marker was removed, so a later merge needs a fresh approval. Nothing merged.
- 2026-09-20: /milestone-review resumed on PR #10, which is open. The default branch had not moved, so the recorded evidence still matches the tree and step 3 was not re-run. `mac.cran.dev` still answers 404 for both files, and CI is unchanged. The PR conversation read came back empty, so the blocking rule did not fire.
- 2026-09-20: step-7 approval: m009-api-token-auth approved for merge.
- 2026-09-20: override: merged PR #10 with `macos-latest (release)` red. The job fails in `setup-r-dependencies` and never builds the package. Windows and all three Ubuntu versions are green, and `devtools::check()` on a macOS machine reports 0 errors, 0 warnings, and 0 notes. The user chose the override at the gate, seeing that.

## Decisions

- 2026-09-20: the token-hiding tests read `conditionMessage()`, not the printed condition. Printing an rlang error also prints a backtrace, and the backtrace echoes the caller's own source line. A user who writes the token as a literal argument sees it there, and the package neither composes that line nor can suppress it. The package composes the message, so the message is what the tests assert. AC3 names the abort message, which is what `conditionMessage()` returns. Falsified by a way for a package to strip a caller's own literal from an rlang backtrace.

## Review

Verified 2026-09-20 on branch m009-api-token-auth. Full suite 281 pass, 0 fail, 0 skip. No driving RR, so no projection to compare against.

### Acceptance criteria

AC1: `tests/testthat/test-token.R` drives `rlm_token()` through all four resolution states and `lms_client()` through both header states. Every test pins ambient state with `withr::local_envvar()` and `withr::local_options()`. The header is read through `httr2::req_dry_run(redact_headers = FALSE)`. The file reports 22 passing expectations and 0 failures.

AC2: `tests/testthat/test-token-wrappers.R` holds a table of exactly the eleven named functions. A test asserts that set against a written-out list with `expect_setequal()`. Each function is driven through the recorder in `helper-mock-http.R`. The table states how many requests each one must issue. The header is read off every captured request. With a token, every request carries `Bearer wrapper-token`. With no token resolving, no request carries the header. A further test drives `lms_chat()` on all three of its routes. Nothing mocks a delegate, so the second request that `lms_load()` and `lms_unload_all()` each issue is captured too. The file reports 73 passing expectations and 0 failures.

AC3: two tests in `test-token.R` name the two renderings. The print test asserts that the rendered request contains `Authorization` and `REDACTED` before it asserts that the token string is absent. The negative therefore cannot pass against a request that carries no header at all. The abort test asserts condition class `rlmstudio_api_error` and status 401 before it reads the message, so the negative cannot pass against some other error. It then asserts that the message holds `API List Failed` and not the token. Both pass.

AC4: `tests/testthat/test-token-rejected.R` drives 401 and 403 with no token and with a token, and 400 as the silent control. Every case runs through the recorder. Each one asserts class `rlmstudio_api_error` and the `status` field against the response status. The no-token cases match `RLMSTUDIO_API_TOKEN` in the message. The token cases match the rejection wording, and assert that neither the variable name nor the token value appears. The 400 case asserts that the abort rendered before it asserts both hints absent. A further test resolves the token from the environment and still reaches the rejected branch. The file reports 25 passing expectations and 0 failures.

AC5: the package was installed into a temporary library, and `help("rlmstudio_token")` returned exactly one topic there. No alias is duplicated anywhere in `man/`. The topic names the `token` argument, the `rlmstudio.token` option, and the `RLMSTUDIO_API_TOKEN` variable, as a numbered list in the order the resolver reads them. Eleven man pages carry a `token` item, and they are the eleven functions AC2 names. `pkgdown/_pkgdown.yml` lists the topic under an Authentication section. `pkgdown::check_pkgdown()` reports no problems. `NEWS.md` carries the entry.

AC6: an LM Studio server ran on `http://localhost:1234` with authentication on. An unauthenticated probe answered 401 before the run. All six cases passed. With `RLMSTUDIO_API_TOKEN` set, `list_models()` returned a model table and `lms_chat_native()` returned a completion. With the variable and the option both cleared and the token passed as the argument, each succeeded again. With no token resolving, each aborted with class `rlmstudio_api_error` and status 401. The no-token cases pinned ambient state with `withr`. The four successes and the two rejections came from one run against one server. The two 401 results are therefore not an artifact of a stopped server. The token was read from a file outside the repository and never entered a command or any output.

### Consistency gate

`cairn_validate.py` passes all sixteen checks, with no advisory raised. No principle changed, so the impact report was not run. Toolchain checks: `devtools::document()` produces no diff, and `pkgdown::check_pkgdown()` reports no problems. `README.md` and `README.Rmd` are at the same commit. The branch adds no top-level file, and `NEWS.md` carries the entry. `devtools::check()` reports Status OK, with 0 errors, 0 warnings, and 0 notes, against the authenticated server.

An earlier `devtools::check()` run on this branch failed. Both vignettes call the API while they build, and with no token set the server answered 401. That is the standing gap a candidate row already records. The run above had the token set.

### PR conversation

conversation: PR #10, empty. No reviews, no comments, and no unresolved threads, read 2026-09-20.

### Findings and disposition

Three fresh-context reviewers ran in parallel, each over its own evidence. The three bases were the branch diff, the history of the lines it touches, and the repo's prior review record. The history lens and the prior-review lens each found no defect. The prior-review lens found no prior-review evidence on the touched files, and the probe for GitHub review threads returned nothing.

1. Fixed. `rlm_token()` silently discarded a `token` argument that was not one character string, and fell through to the option and the variable. Reproduced: with `RLMSTUDIO_API_TOKEN` set to a value, `rlm_token(c("a","b"))`, `rlm_token(123)`, and `rlm_token(NA_character_)` each returned that value. A caller who passed a token got a different one, or none, plus a hint telling them to pass the argument they had passed. The resolver now aborts on any shape other than one character string or `NULL`. `NULL` and the empty string stay legal. Six new expectations cover it. Removing the guard turns five of them red.
2. Fixed. The help topic and the changelog claimed that the message of a failed call never carries the token. The message repeats the text the server sent, so a server that echoes the token back puts it there. Both now say that the package never adds it, and name the two things outside the package's control.
3. Fixed. D-005 recorded that a machine without `httpuv` sees skips rather than failures. This branch narrows that to off-CI only. Recorded as D-006, which narrows D-005.
4. Fixed. The new `lms_unload()` signature ran to 82 characters, over the formatter's 80. Triage ordinarily rejects what a formatter catches. The branch introduced this line, so it is wrapped here rather than left to produce a diff later.
5. Follow-up. The eight abort sites re-resolve the token to decide the hint, instead of reading the flag off the request. Ambient state changing between the two reads gives the wrong hint. Candidate row added.
6. Follow-up. `request_target()` now returns headers with redaction off for every caller, and the older callers do not pin the variable. Nothing prints them today. Candidate row added.
7. Fixed. The `@return` line on `api_error_hint()` said "one character string" for both branches. The no-token branch carries cli markup. The line now says so.
8. Rejected, with a follow-up. The wrapper-table test compares a written list to itself, so it is not a completeness guard. AC2 scopes the claim to these eleven functions on purpose, so this is the criterion working as planned, not a defect. A candidate row records the guard that closes the gap.

No finding demonstrates an acceptance criterion failing inside the domain of the procedure that criterion names, so none returns the milestone. Finding 1 is the candidate for a defect that matters to what the package does for its users. It is fixed on the branch rather than deferred.
