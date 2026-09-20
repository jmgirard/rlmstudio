<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M010: The package can tell a usable LM Studio server from an open port

- **Status:** in-progress
- **Priority:** high
- **Depends on:** none
- **Driving RR:** none
- **Principles touched:** GP1, GP3
- **Resolves:** none
- **Surface tier:** user-facing. It exports a function, changes two shipped vignettes, and narrows one shipped help page
- **Branch/PR:** m010-usable-server-probe

## Goal

`Rscript -e 'devtools::check()'` passes on a machine with LM Studio installed,
whatever state that server is in.

## Scope

**In:** a new exported function that reports whether a host answers as a usable
LM Studio server. New gating in both vignettes, built on that function. A
narrowed "Server not running" section on the condition help page.

**Out:** the pre-call probe inside the REST wrappers. It keeps the TCP probe it
uses today. An HTTP round trip in front of every call is a cost this milestone
does not take. The embeddings wrapper and the macOS mirror fix stay candidate
rows.

## Acceptance criteria

- [ ] AC1: `lms_server_ready()` returns a length-one logical rather than
      raising, inside the time its documented `timeout` argument sets. A test
      drives five cases. The first case is a closed port. The second is an open
      port whose listener never answers, a bare `serverSocket()`. The third is
      an HTTP 401 response. The fourth is an HTTP 200 whose body is not a model
      list. The fifth is an HTTP 200 that carries a model list. The first four
      return `FALSE`. The fifth returns `TRUE`.
- [ ] AC2: Tests drive all four token paths with distinct values. The four
      paths are the `token` argument, the `rlmstudio.token` option, the
      `RLMSTUDIO_API_TOKEN` environment variable, and no token at all. Each
      test asserts through `request_target()` which value reaches the
      `Authorization` header. The fourth path sends no such header. The run
      that evidences this criterion has `httpuv` installed.
- [ ] AC3: The rendered `man/rlmstudio-conditions.Rd` states that the probe
      behind `rlmstudio_no_server` is a TCP connection to the host and port. It
      states that another process holding that port suppresses the condition.
      It names `lms_server_ready()` as the stronger test.
- [ ] AC4: `Rscript -e 'devtools::check()'` reports 0 errors and 0 warnings on
      a machine whose LM Studio server requires authentication and whose
      calling environment sets no `RLMSTUDIO_API_TOKEN`.
- [ ] AC5: `Rscript -e 'devtools::test()'` reports 0 failures, 0 errors, and 0
      warnings. `Rscript -e 'devtools::document()'` produces no diff.
- [ ] AC6: `NEWS.md` carries an entry for the new function and for the narrowed
      condition help page.

## Coverage

- AC1 → T1, T2
- AC2 → T2, T3
- AC3 → T4
- AC4 → T5, T6
- AC5 → T6
- AC6 → T6

## Tasks

- [x] T1: Write the five failing probe tests in a new
      `tests/testthat/test-server-ready.R`. Use a bare `serverSocket()` on a
      random high port for the silent listener, per the 2026-09-17 lesson. Use
      the shared recorder in `tests/testthat/helper-mock-http.R` for the three
      HTTP cases, per D-004.
- [x] T2: Add `lms_server_ready(host, token, timeout)` to `R/serve.R`. Resolve
      the token through `rlm_token()`. Send a GET to `api/v1/models` through
      `lms_client()` (R/chat.R). Return `TRUE` only for a 200 whose parsed body
      carries a model list. Catch every error and return `FALSE`.
- [x] T3: Add the four token-path assertions through `request_target()`,
      following `tests/testthat/test-token-wrappers.R`.
- [x] T4: Write the roxygen block for `lms_server_ready()` and export it.
      Narrow the "Server not running" section in `R/conditions.R:8`. Run
      `Rscript -e 'devtools::document()'`. Discovered sub-task: add a test
      that a foreign listener on the port passes the TCP probe. The same test
      shows the readiness check reporting FALSE there.
- [x] T5: Rebuild the gating in `vignettes/getting-started.Rmd` and
      `vignettes/headless-config.Rmd`. Assign a readiness value once per
      vignette, after the server-start chunk. Gate every later REST chunk on
      it. Gate each teardown chunk on whether its own start chunk ran, never on
      readiness, so a failed probe never leaves the server up. Record the chunk
      list in the work log.
- [ ] T6: Turn on "Require authentication" in LM Studio. Unset
      `RLMSTUDIO_API_TOKEN` in the calling environment. Run
      `Rscript -e 'devtools::check()'`. Write the `NEWS.md` entry. Run
      `Rscript -e 'devtools::test()'` and `Rscript -e 'devtools::document()'`.

## Work log

- 2026-09-20: created by /milestone-plan.
- 2026-09-20: the criteria audit ran in full mode and returned nine findings. Eight had one right answer and were fixed before the criteria were written. The ninth went to the gate as the proof question.
- 2026-09-20: plan gate chose a new exported probe over an HTTP upgrade to the existing TCP probe. Every REST wrapper calls that probe first and then gains a round trip. A server that requires a token also reads as not running. Falsified by a measurement that puts the extra request near zero next to the call after it.
- 2026-09-20: plan gate chose a staged audit run over a grep of the vignette chunk headers as the proof of the vignette fix. The grep promises a property of its own output. It also cannot reach the assignment that it quantifies over. Falsified by the maintainer being unable to put LM Studio into the failing state.
- 2026-09-20: plan gate chose this scope over the embeddings wrapper and over the macOS mirror fix. A fragile package audit taxes the review gate of every later milestone. Falsified by the audit passing today in the token-requiring state.
- 2026-09-20: implement gate settled three items. If its body carries a `models` JSON array, a 200 reads as ready. An empty array counts. The `timeout` default is 2 seconds. The new function joins the shared token-wrapper table. That table grows from eleven names to twelve.
- 2026-09-20: T1 wrote eight tests in `tests/testthat/test-server-ready.R`. They cover the five planned cases, an empty model list, a JSON object under the `models` key, and the request target. All eight failed before T2 on `could not find function`.
- 2026-09-20: T2 added `lms_server_ready(host, timeout, token)` to `R/serve.R`. The token resolves through `lms_client()`. That function calls `rlm_token()`. A malformed `token` therefore aborts and does not read as not ready. Timeout discrimination measured on a silent listener: 0.5 returned FALSE in 0.53 s, 2 returned FALSE in 2.02 s.
- 2026-09-20: T3 drove the four token sources with four distinct values, each case unsetting the sources below it. The argument, the option, and the environment variable each reach the header. The no-token case sends no header. `lms_server_ready` also joined the shared wrapper table, taking it to twelve names. Discrimination: dropping the `token` argument from the `lms_client()` call turned the argument case red and left the rest green.
- 2026-09-20: T4 narrowed the "Server not running" section. The rendered section names the TCP connection as the probe. It says a foreign process on the port suppresses the condition. It points at `lms_server_ready()`. The inherited section propagated to all eleven consumer pages.
- 2026-09-20: the two claims on that page were derived from runs, not composed. A local httpuv server answering 404 made `list_models()` raise `rlmstudio_api_error`. The same server answering 200 with an HTML body made it raise a raw `jsonlite` lexical error. `lms_server_ready()` reported FALSE against the second one.
- 2026-09-20: minor amendment. T4 gained a discovered sub-task: one test showing a foreign listener passing `is_server_running()` and `stop_if_no_server()` while `lms_server_ready()` reports FALSE. No new dependency, so the httpuv runs above stayed out of the suite.
- 2026-09-20: T4's roxygen block and export landed in the T2 commit. The function and its documentation are one edit. T4 keeps the conditions help-page narrowing. Minor reorder, no scope change.

- 2026-09-20: T5 chunk list. `getting-started.Rmd` assigns `lms_ready` in `check-ready`, gated on `lms_installed`. Gated on `lms_ready`: `download`, `wait`, `load`, `simple-chat`, `unload`. Gated on `lms_installed`: `setup`, `check-status`, `start-server`, `stop-server`. The old `teardown` chunk split into `unload` and `stop-server`.
- 2026-09-20: T5 chunk list. `headless-config.Rmd` assigns `lms_ready` in `check-ready`, gated on `lms_installed`. Gated on `lms_ready`: `download`, `wait`, `list`, `load`, `chat`, `unload`, `with-daemon`. Gated on `lms_installed`: `setup`, `check-status`, `start-daemon`, `start-server`, `stop-stack`. The old `teardown` chunk split into `unload` and `stop-stack`.
- 2026-09-20: `model` moved to the setup chunk of both vignettes. It was assigned inside a chunk that readiness now gates, and the teardown chunk reads it.
- 2026-09-20: T5 discrimination. The local server already requires a token and the calling environment sets none. `lms_server_ready()` therefore reported FALSE. Both vignettes built with every REST chunk skipped. A scratch copy with the assignment forced to TRUE died at the `download` chunk on `rlmstudio_api_error`. The gate controls the chunks in both directions.
- 2026-09-20: `lms_server_start()` returns before the REST API answers. A probe run right after it can report FALSE on a healthy machine. That cost was not reached here, because the token requirement holds the answer FALSE either way. It is a candidate row, not a fix in this milestone.

## Decisions

## Review
