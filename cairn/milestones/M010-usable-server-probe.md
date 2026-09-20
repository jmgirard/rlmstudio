<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section. -->
# M010: The package can tell a usable LM Studio server from an open port

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP3
- **Resolves:** —
- **Surface tier:** user-facing. It exports a function, changes two shipped vignettes, and narrows one shipped help page
- **Branch/PR:** m010-usable-server-probe, https://github.com/jmgirard/rlmstudio/pull/11

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

- [x] AC1: `lms_server_ready()` returns a length-one logical rather than
      raising, inside the time its documented `timeout` argument sets. A test
      drives five cases. The first case is a closed port. The second is an open
      port whose listener never answers, a bare `serverSocket()`. The third is
      an HTTP 401 response. The fourth is an HTTP 200 whose body is not a model
      list. The fifth is an HTTP 200 that carries a model list. The first four
      return `FALSE`. The fifth returns `TRUE`.
- [x] AC2: Tests drive all four token paths with distinct values. The four
      paths are the `token` argument, the `rlmstudio.token` option, the
      `RLMSTUDIO_API_TOKEN` environment variable, and no token at all. Each
      test asserts through `request_target()` which value reaches the
      `Authorization` header. The fourth path sends no such header. The run
      that evidences this criterion has `httpuv` installed.
- [x] AC3: The rendered `man/rlmstudio-conditions.Rd` states that the probe
      behind `rlmstudio_no_server` is a TCP connection to the host and port. It
      states that another process holding that port suppresses the condition.
      It names `lms_server_ready()` as the stronger test.
- [x] AC4: `Rscript -e 'devtools::check()'` reports 0 errors and 0 warnings on
      a machine whose LM Studio server requires authentication and whose
      calling environment sets no `RLMSTUDIO_API_TOKEN`.
- [x] AC5: `Rscript -e 'devtools::test()'` reports 0 failures, 0 errors, and 0
      warnings. `Rscript -e 'devtools::document()'` produces no diff.
- [x] AC6: `NEWS.md` carries an entry for the new function and for the narrowed
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
- [x] T6: Turn on "Require authentication" in LM Studio. Unset
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

- 2026-09-20: T6 needed no GUI change. The machine's LM Studio already requires a token, and the calling environment sets none. Pinned at the check: `api/v1/models` answered 401 with code `invalid_api_key`, and `lms_server_ready()` reported FALSE.
- 2026-09-20: `Rscript -e 'devtools::check()'` reported 0 errors, 0 warnings, and 0 notes in that state. `devtools::test()` reported 0 failures, 0 errors, 0 warnings, 310 passing. `devtools::document()` left no diff.
- 2026-09-20: candidate row added for the gap between `lms_server_start()` returning and the REST API answering.

- 2026-09-20: claim audit: 24 claims read, 3 corrected — tests/testthat/test-server-ready.R
- 2026-09-20: a fresh reader read every added line outside `cairn/`. The three wrong claims were all test comments. Everything in `NEWS.md`, `R/`, the twelve man pages, and both vignettes held.
- 2026-09-20: the largest of the three. The comment said the five-second bound proved that the `timeout` argument does the work. It does not. httr2 and curl set no default timeout, so a build with the `req_timeout()` line deleted hangs on the silent socket instead of failing. The comment now says what the bound can catch, which is a timeout set to the wrong value.
- 2026-09-20: the same reader re-read the three corrections once. Two held. The third was still wrong about which sources the last two token cases clear: they clear the source that otherwise wins, not a source below. Corrected, and the pass is closed.
- 2026-09-20: blocked: the macOS check job on PR #11 is red on the `mac.cran.dev` mirror, and the maintainer chose to fix that before merging. The fix is the `[high]` candidate row added 2026-09-20. The eleven other checks passed.
- 2026-09-20: the merge-approval marker was deleted unmerged. The approval below stands as a record, and a fresh gate writes a new marker when the merge is taken up again.
- 2026-09-20: step-7 approval: m010-usable-server-probe approved for merge
- 2026-09-20: gate triage chose to fix seven findings on the branch and file four as candidate rows. Both new tests were shown to go red on the defect they claim to catch. Re-verified on the tree that merges: check 0/0/0, test 315 passing, document no diff, validate green.
- 2026-09-20: review checkpoint. All six criteria re-executed with fresh evidence and ticked. Consistency gate green. The three review lenses are still running, so the findings and triage are not yet written.
- 2026-09-20: `cairn_validate` wants `—` in the Driving RR slot, so the three header slots keep their em-dashes. The writing lint counts them as violations. The validator is the machine reader and wins.
- 2026-09-20: resumed. M011 merged the macOS dependency fix to the default branch, so the blocker cleared.
- 2026-09-20: merged the default branch into this one at b6c8844. One conflict, in `cairn/ROADMAP.md`. Kept M011's done row. Dropped the macOS mirror candidate row that M011 resolved. Kept this branch's corrected token-table count and its three new candidate rows.
- 2026-09-20: re-verified after the merge. `devtools::document()` left no diff. `devtools::test()` reported FAIL 0, WARN 0, SKIP 0, PASS 315. `devtools::check()` reported 0 errors, 0 warnings, and 0 notes twice. The first run had the LM Studio server down. For the second run the server was up and answered 401 with code `invalid_api_key`. The calling environment set no `RLMSTUDIO_API_TOKEN` in either run.

## Decisions

## Review

### Acceptance-criteria evidence

- AC1: `testthat::test_local(filter = "server-ready")` at 97b1ae3 ran ten
  tests, all green, none skipped. The five named cases are there and each
  returned the value the criterion asks for. A closed port returns `FALSE`. A
  bare `serverSocket()` listener that never answers returns `FALSE`. An HTTP
  401 returns `FALSE`. An HTTP 200 whose body is not a model list returns
  `FALSE`. An HTTP 200 carrying a model list returns `TRUE`. Nothing raised.
  Fresh timing against a silent listener on port 38291: `timeout = 0.5`
  returned `FALSE` in 0.53 s, `timeout = 2` returned `FALSE` in 2.02 s, and a
  closed port returned `FALSE` in 0.01 s.
- AC2: the same run reports `httpuv` 1.6.17 installed, so no test skipped
  under D-006. The test "each token source reaches the Authorization header"
  passed eight assertions across four cases. The four values are distinct:
  `ready-argument`, `ready-option`, `ready-envvar`, and no token. Each case
  reads the header back through `request_target()`. The argument case sends
  `Bearer ready-argument`, the option case `Bearer ready-option`, the
  environment case `Bearer ready-envvar`. The fourth case sends no
  `Authorization` header, asserted as `NULL`.
- AC3: read `man/rlmstudio-conditions.Rd` at 97b1ae3. The "Server not running"
  section names the probe as a TCP connection to the hostname and port in
  `host`. It says any process holding that port accepts the connection, so the
  condition is not raised. It names `lms_server_ready()` as the stronger test.
  All three clauses are in the rendered file, not only in the roxygen source.
- AC4: `Rscript -e 'devtools::check()'` ran at 97b1ae3 with `lms` on `PATH`,
  the LM Studio server up on port 1234 requiring a token, and no
  `RLMSTUDIO_API_TOKEN` in the calling environment. A `curl` to
  `api/v1/models` immediately before the run answered 401 with code
  `invalid_api_key`. Result: 0 errors, 0 warnings, 0 notes, status OK, 15.5 s.
  The vignette rebuild passed. The server was down after the run, because both
  vignettes run their teardown chunks whenever the CLI is present, which is the
  behavior T5 built.
- AC5: `Rscript -e 'devtools::test()'` at 97b1ae3 reported FAIL 0, WARN 0,
  SKIP 0, PASS 310. `Rscript -e 'devtools::document()'` then left the working
  tree clean apart from this milestone file.
- AC6: `NEWS.md` at 97b1ae3 carries three new bullets under the development
  heading. The first describes `lms_server_ready()`, its return values, its
  `timeout` default of 2, and its `token` argument. The second describes the
  narrowed condition help page. The third describes the vignette gating.

No driving review report, so no projection to measure against.

### Consistency gate

- `cairn_validate.py` exited 0. Sixteen checks passed and seven advisories read
  OK, the release window among them.
- The diff changes no `DESIGN.md` principle, so `cairn_impact.py` was skipped.
- Toolchain checks from the `r-package` profile: `devtools::document()` left no
  diff. `NAMESPACE` and `man/` regenerate clean, so nothing was hand-edited.
  `README.Rmd` and `README.md` are untouched by this branch and were last
  committed in the same commit. `pkgdown::check_pkgdown()` reported no problems.
  `NEWS.md` carries the entry. The branch adds no top-level file, so no new
  `.Rbuildignore` entry is owed. `devtools::check()` was clean, recorded under
  AC4.

### Independent review

Three fresh-context lenses ran against the branch diff. Surface tier is
user-facing, so all three were spawned.

The blame-history lens found no case where the branch undoes a deliberate past
commit, revives a fixed bug, or contradicts a recorded decision. It reported one
actionable item, listed as F13 below. The prior-review lens found no prior-review
evidence to regress: the archived review findings that touch these files come
from M001, M007, and M009, and each still holds. Its probe for inline pull
request comments returned an empty list, so the thread walk was skipped.

The diff-bug lens reported twelve findings, ranked. Each one below carries the
session's own verification and its disposition.

- F1 (test discrimination): deleting the `resp_status(resp) != 200L` check
  leaves the whole suite green. The 401 case sends `{"error": "unauthorized"}`,
  which carries no `models` key. It therefore returns `FALSE` through the body
  predicate alone, with or without the status check. Verified by reading the
  fixture against the predicate. The live behavior is correct today, because
  the status check is present. Disposition: fix now.
- F2 (contract): `is.list(models) && is.null(names(models))` accepts any JSON
  array. Measured: `{"models": ["a","b"]}` and `{"models": [1,2,3]}` both read
  `TRUE`. Both `{"models": {}}` and `{"models": {"a": 1}}` read `FALSE`, the
  empty object included. A foreign server whose body holds any `models` array reads
  as ready, which is the case the milestone exists to catch. Disposition: fix
  now.
- F3 (contract): three input faults abort from outside the `tryCatch`, and the
  help page names only `token` as an aborting case. Four measured aborts.
  `lms_server_ready("localhost:1234")` aborts on "Failed to parse URL".
  `timeout = 0` aborts on "`seconds` must be >1 ms." and `timeout = NA` aborts
  on "`seconds` must be a number". `host = NULL` aborts on "`url` must be a
  single string". The schemeless host matters most here. The port check this
  function replaces, `is_server_running()`, normalizes a schemeless host and
  returns `FALSE`. Disposition: user's call at the gate.
- F4 (vignette): `with-daemon` at `vignettes/headless-config.Rmd:153` is gated
  on `lms_ready`, measured at line 65. The `stop-stack` chunk at line 141 has
  since stopped the server and the daemon. The chunk restarts the server and
  calls `lms_load()` immediately, with no re-check. Verified from the chunk
  order. This is the gap the branch's own candidate row names, so on a machine
  where readiness read `TRUE` the vignette build can still fail. Disposition:
  fix now.
- F5 (vignette): the teardown chunks are gated on `lms_installed` alone, so a
  build tears down a server the vignette did not start. The AC4 run shows this
  happening. The old single `teardown` chunk carried the same gate, so the diff
  did not introduce the behavior. The new prose is what is new, and it omits
  the case. Disposition: correct the prose now, candidate row for the behavior.
- F6 (docs): the narrowed help page says the condition is raised "when that
  connection is refused". `is_server_running()` returns `FALSE` for an
  unparsable URL, an empty hostname, and any `socketConnection()` error,
  including its 0.5 second connect timeout. Verified by reading
  `R/serve.R:237-262`. A defect inside an intentional change is still a defect.
  Disposition: fix now.
- F7 (vignette): `vignettes/getting-started.Rmd` hardcodes `#> [1] TRUE` inside
  the `check-ready` chunk, which evaluates and echoes its own real output. On a
  token-requiring server the rendered page shows both `TRUE` and `FALSE`. The
  matching chunk in `headless-config.Rmd` omits the comment. Disposition: fix
  now.
- F8 (tests): `free_port()` is defined in both `test-server-ready.R` and
  `test-serve.R` with different bodies, and `open_listener()` is a near-copy of
  `local_listener()`. The repo's convention puts shared test helpers in
  `helper-*.R`. Disposition: candidate row.
- F9 (tests): `free_port()` binds a port, closes it, then assumes nothing takes
  it, and both helpers draw from the session RNG through `sample()`.
  Disposition: candidate row.
- F10 (tests): the `req_error(is_error = \(resp) FALSE)` override changes
  nothing any current test can see. The fix for F1 gives it work to do.
  Disposition: absorbed into F1.
- F11 (tracking): `cairn/DESIGN.md:39` still lists the daemon-and-server family
  without `lms_server_ready`. Line 52 states without exception that a function
  aborts for a server that is not running. Verified by reading the file.
  Disposition: fix now.
- F12 (tracking): a comma splice in the candidate row at `cairn/ROADMAP.md`.
  Disposition: fix now.
- F13 (tracking, from the blame lens): the candidate row about a guard for the
  token wrapper table still says the table holds eleven names. This branch made
  it twelve. The row's warning still stands. Only its count is stale.
  Disposition: fix now.

No finding demonstrates an acceptance criterion failing inside the domain of
the procedure that criterion names. No finding triggers the return floor on its
own. F2 and F4 are the two that bear on what the function does for its users.
The gate decides them.

### Gate-directed fixes

The maintainer chose to fix seven findings on the branch and to file the rest.
What landed:

- F1 and F2: the body test moved into a new `is_model_list()` helper in
  `R/serve.R`. It still requires a nameless list, and it now requires every
  entry to be a named list, which is what a JSON object parses to. A new test
  sends a valid model list under status 401 and 500, so the status check is now
  the only thing returning `FALSE` there. A second new test sends
  `{"models": ["a", "b"]}` and `{"models": [1, 2, 3]}` under status 200. A
  third sends a list of two models.
- F4: `with-daemon` in `vignettes/headless-config.Rmd` is now gated on
  `lms_installed` and asks `lms_server_ready()` again inside the block, after
  it starts its own server. Prose above it says why.
- F6: the condition help page now ties the condition to a connection that
  cannot be opened. It names the four ways that happens.
- F7: the hardcoded `#> [1] TRUE` is gone from the `check-ready` chunk of
  `vignettes/getting-started.Rmd`.
- F11: `cairn/DESIGN.md` lists `lms_server_ready` in the daemon-and-server
  family, and the abort convention now names it as the one exception.
- F12 and F13: both candidate rows corrected in `cairn/ROADMAP.md`.
- F3, F5, F8 and F9 became candidate rows.

Check discrimination on the two new tests, by planting the defect each claims
to catch. Delete the `resp_status(resp) != 200L` check, and the test named "a
failed status is not ready even when the body looks right" goes red. The rest
stay green. Replace the per-entry check with `TRUE`, and the test named "an
array that is not an array of models" goes red. The rest stay green again. The
restored tree runs green.

An Air pass over `R/` and `tests/` also reformatted `R/utils-token.R`,
`tests/testthat/test-mock-http-helper.R`, and untouched regions of
`tests/testthat/test-token-wrappers.R`. None of that belongs to this
milestone, so all three were reverted.

### Re-verification after the fixes

Run against the exact tree that merges, with `lms` on `PATH`, the server up and
answering 401, and no `RLMSTUDIO_API_TOKEN` in the environment.

- AC1 and AC2: `devtools::test()` reports FAIL 0, WARN 0, SKIP 0, PASS 315. The
  count rose from 310 by the five new assertions.
- AC3: the rendered `man/rlmstudio-conditions.Rd` keeps all three clauses the
  criterion names, with the refused-connection sentence widened.
- AC4: `devtools::check()` reports 0 errors, 0 warnings, 0 notes, status OK.
- AC5: `devtools::document()` leaves no diff.
- AC6: `NEWS.md` is unchanged by the fixes and still carries the three entries.
- Consistency gate: `cairn_validate.py` exits 0 and
  `pkgdown::check_pkgdown()` reports no problems.

### CI on PR #11

Eleven checks passed. One failed: `macos-latest (release)`. The failure is in
`r-lib/actions/setup-r-dependencies`, inside the `pak` subprocess, before the
package is built. The log shows `mac.cran.dev` listed as the second source for
every macOS binary.

The same job is already red on `main`. Run 35522619704 on `main` failed on
macOS alone while Ubuntu release, Ubuntu devel, Ubuntu oldrel-1, and Windows
release all passed. The three `main` runs before it passed on every platform.
This branch did not cause the failure, and the ROADMAP already carries a
candidate row for the mirror.
