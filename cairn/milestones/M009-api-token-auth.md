# M009: The package can authenticate to LM Studio

- **Status:** in-progress
- **Branch:** m009-api-token-auth
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

- [ ] AC1: `lms_client()` builds a request. If a token resolves, that request carries the header `Authorization: Bearer <token>`. If no token resolves, that request carries no `Authorization` header. If the `token` argument is given, the resolver returns it over an option and a variable that are both set to other values. If no argument is given, the resolver returns the option over a variable set to another value. If only the variable is set, the resolver returns the variable. If none of the three is set, the resolver returns no token. A test drives all four states. The test pins ambient state with `withr::local_envvar()` and `withr::local_options()`. The test reads the header from `httr2::req_dry_run(redact_headers = FALSE)`.
- [ ] AC2: The test's wrapper table lists eleven exported functions. They are `list_models()`, `lms_load()`, `lms_unload()`, `lms_unload_all()`, `lms_download()`, `lms_download_status()`, `lms_chat()`, `lms_chat_batch()`, `lms_chat_openresponses()`, `lms_chat_openai()`, and `lms_chat_native()`. If a listed function is called with `token = "<token>"`, every request it issues carries `Authorization: Bearer <token>`. If no token resolves, every request it issues carries no `Authorization` header. Each function is driven through the recorder in `tests/testthat/helper-mock-http.R`. The header is read off every captured request. The claim covers these eleven functions and no function added later.
- [ ] AC3: A test names two renderings. The first is the printed form of a request that `lms_client()` built with a token. The second is the abort message of an `rlmstudio_api_error` raised from a failed request built that way. The token string appears in neither rendering.
- [ ] AC4: A failed response with HTTP status 401 aborts with condition class `rlmstudio_api_error`. A failed response with status 403 aborts the same way. Each abort carries a `status` field equal to the response status. If the request sent no token, the message names `RLMSTUDIO_API_TOKEN`. If the request sent a token, the message states that the server rejected the token, and the message does not name the variable. A failed response with status 400 aborts with a message that does neither. All five cases are driven through the recorder.
- [ ] AC5: `?rlmstudio_token` returns exactly one help topic. That topic names the argument, the option, the variable, and the order the resolver reads them in. Each of the eleven functions documents its `token` argument on its own help page. `pkgdown/_pkgdown.yml` lists the new topic. `NEWS.md` carries an entry for the change.
- [ ] AC6: An LM Studio server runs with authentication enabled. When `RLMSTUDIO_API_TOKEN` supplies the token, `list_models()` and `lms_chat_native()` each succeed. When the `token` argument supplies it, each succeeds again. When no token resolves, each aborts with class `rlmstudio_api_error` and `status` 401. The no-token runs pin ambient state with `withr::local_envvar()`.

## Coverage

- AC1 → T1
- AC2 → T2, T3, T4
- AC3 → T1, T5
- AC4 → T6
- AC5 → T7
- AC6 → T8

## Tasks

- [x] T1: Add a `rlm_token()` resolver and a `token` argument to `lms_client()` (`R/chat.R:469`). Set the header with `httr2::req_auth_bearer_token()`. Test the four resolution states and the two header states. Use a dummy token string, because `redact_headers = FALSE` puts the literal value into failure output.
- [ ] T2: Add a `token` argument to the eight direct callers of `lms_client()`. They are at `R/chat.R:131`, `R/chat.R:240`, `R/chat.R:305`, `R/list.R:56`, `R/load.R:118`, `R/unload.R:48`, `R/download.R:58`, and `R/download.R:132`. Forward the argument explicitly from the three delegators, `lms_chat()`, `lms_chat_batch()`, and `lms_unload_all()`. Do not let a token ride `...`, because dots go into the request body (GP4). A token there is sent as a body field.
- [ ] T3: Extend `request_target()` to return the request headers unredacted. When `httpuv` is absent and `CI` is set, make the helper raise rather than skip. CI installs `httpuv`, so neither branch arises there on its own. Split the skip decision into a testable predicate rather than mocking `skip_if_not_installed()`. Test both branches.
- [ ] T4: Assert the header on every request that each of the eleven functions issues, through the recorder. Two traps apply. `lms_load()` without `force = TRUE` sends two requests (M008). A test that mocks a delegate still passes with the delegating call site deleted (M003). For `lms_chat()`, `lms_chat_batch()`, and `lms_unload_all()`, delete the forwarding line in a scratch copy and make sure that the test goes red.
- [ ] T5: Test that `print()` of a token-carrying request does not contain the token string. Test that the abort message of a failure raised from such a request does not contain it either.
- [ ] T6: Give `rlm_abort_api()` (`R/utils-api-error.R:80`) a third argument carrying the token that was used. Pass it from the eight abort sites. Add the status-conditional hint. Test 401 and 403 with a token and without one, and test 400 as the silent control.
- [ ] T7: Write the `rlmstudio_token` doc-only topic with `@name` and `@aliases`. M007 found that a doc-only topic is reachable only under its `@name`. Add `@param token` to the eleven help pages. Add the pkgdown row beside `rlmstudio-conditions`. Write the `NEWS.md` entry. Run `devtools::document()`.
- [ ] T8: Run the six AC6 cases against a live LM Studio with authentication enabled. Record the commands and their output in the Review section.

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

## Decisions

## Review
