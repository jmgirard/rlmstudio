# M055: Cleanup of vignette teardown, test helpers, and the token hint

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP5
- **Resolves:** —
- **Surface tier:** user-facing — the vignettes ship, and the 401 and 403 hint is part of exported abort messages
- **Branch/PR:** m055-teardown-cleanup, https://github.com/jmgirard/rlmstudio/pull/55

## Goal

Vignette builds and live test runs leave the LM Studio server and the loaded
models as they found them. The 401 and 403 hint matches the request sent.

## Scope

**In:** Five candidate rows, merged into one cleanup at the user's request.
If a vignette started the server, it stops it at the end. If it loaded the
model, it unloads it. The `Full Integration` test in `test-chat.R` and the
end-to-end test in `test-integration.R` lose the `on.exit()` unload that runs
outside the recorded replies. The two live tests in `test-embed.R` let an
error from `list_models()` fail the test. The test helper `request_target()`
returns a non-JSON body as text and redacts headers unless the caller opts
in. Each REST wrapper takes the 401 and 403 hint from the request it built,
not from a second read of the token sources. NEWS.

**Out:** The daemon state in `headless-config.Rmd`. On this Mac, the desktop
app keeps the daemon running, so no render here can show a fix. It joins the
headless-daemon candidate row. The same row holds the server and model state
after a render on a host where the desktop app is not the daemon. The model download in both vignettes stays,
because the download is part of what the vignettes teach. The other rows
stay candidates in the ROADMAP.

## Acceptance criteria

- [x] AC1: On a host where the LM Studio desktop app process is the
      daemon, a render of either vignette leaves two facts as they were
      before it. The first fact is the `running` field of `lms server status
      --json`. The second fact is whether `lms ps --json` lists
      `google/gemma-3-1b`. This holds from four starting states: the server
      stopped or running, crossed with the model loaded or not. The
      procedure is eight live renders on one such host, one per vignette and
      state. A render counts toward AC1 only if, before and after it, `lms
      daemon status --json` reports `"status": "running"` with the same
      `pid`, and `ps -p` of that pid names the LM Studio desktop app
      executable. Each render runs `rmarkdown::render(output_dir =
      tempdir())` after `devtools::install()` of the branch. Each reads both
      facts before and after the render.
- [x] AC2: The sweep `grep -nE
      'lms_(load|unload|unload_all|download|server_start|server_stop|daemon_start|daemon_stop)\('
      $(grep -l 'skip_if_no_server()' tests/testthat/*.R)` lists no call
      that runs outside an `httptest2::with_mock_dir()` block. With the
      server running and `google/gemma-3-1b` loaded before it, a
      `devtools::test(filter = "^(chat|integration)$")` run leaves the model
      loaded. `lms ps --json` is read before and after the run.
- [x] AC3: The two live tests in `tests/testthat/test-embed.R` that ask
      `list_models()` for the loaded embedding models take the list from a
      test helper that does not catch errors. A test mocks `list_models()`
      to raise three conditions in turn: `rlmstudio_api_error` at status
      401, `rlmstudio_bad_response`, and a plain `stop()` error. For each,
      it asserts that the helper raises that same condition class and
      signals no skip condition.
- [x] AC4: `grep -n 'rlm_token(' R/*.R` lists two call sites: the body of
      `lms_client()` and the argument check in `lms_server_start()`. For each
      hit of `grep -n 'rlm_abort_api(' R/*.R` outside a roxygen comment
      line, a test drives the wrapper that reaches it to a 401 reply twice.
      In the first run, the `rlmstudio.token` option holds a token at
      request build and is cleared before the reply. That run asserts the
      hint for a sent token, which begins "The server rejected". In the
      second run, no token source holds a token at request build, and the
      option is set before the reply. That run asserts the hint that names
      `RLMSTUDIO_API_TOKEN`.
- [x] AC5: `devtools::test()` and `devtools::check()` run with 0 errors and
      0 warnings. NEWS.md has an entry for the hint change and one for the
      vignette change.

## Coverage

- AC1 → T1, T2
- AC2 → T3
- AC3 → T4
- AC4 → T6
- AC5 → T5, T7

## Tasks

- [x] T1: In both vignettes, add hidden chunks (`include = FALSE`). One
      reads the `running` field of `lms_server_status(json = TRUE)` before
      the start chunk. One reads whether `list_models(loaded = TRUE)` lists
      the model, after the readiness check. If the server was stopped
      before, the stop chunks run. If the model was not loaded before, the
      unload chunks run. In `headless-config.Rmd`, if the server was
      stopped before, the `with-daemon` chunk runs. If that chunk loaded
      the model, it unloads it.
- [x] T2: Install the branch with `devtools::install()`. Run the eight
      renders of AC1. Before and after each render, read both facts, the
      daemon status, and the `ps -p` name of the daemon pid.
- [x] T3: Delete the `on.exit()` unload fallbacks at
      `tests/testthat/test-chat.R:13-18` and
      `tests/testthat/test-integration.R:15-20`. Run the AC2 sweep and the
      live test run.
- [x] T4: Add a helper to `tests/testthat/helper-skips.R` that reads the
      loaded embedding models from `list_models()` with no `tryCatch()`.
      If the model is absent, the helper skips. Use it in the two live tests
      at `tests/testthat/test-embed.R:1116` and `:1146`. Write the AC3
      test. It catches a skip with a `skip` handler, because `expect_error()`
      lets a skip through (M019 lesson).
- [x] T5: In `request_target()` (`tests/testthat/helper-mock-http.R:144`),
      catch the JSON parse and return the body text as a character string.
      Add an opt-in argument for headers that are not redacted, and pass
      it at each caller that reads `authorization`. Test a JSON body, a
      non-JSON body, and the header read with and without the opt-in in
      `tests/testthat/test-mock-http-helper.R`.
- [x] T6: Add one internal helper that reports whether a built request
      carries an `Authorization` header. Each wrapper passes its result to
      `rlm_abort_api()` in place of `!is.null(rlm_token(token))`, at the
      eight sites and at `has_token` in `R/embed.R:125`. Do not read the
      header off the response, because a mocked response carries no
      request. Write the AC4 tests. The embed site computes its flag at
      request build today, so its probe passes before the change. Say so in
      the Review section.
- [x] T7: Write the NEWS entries. Run `devtools::document()` and
      `devtools::test()`. The check renders both vignettes live, so read the
      two AC1 facts before and after `devtools::check()`.

## Work log

- 2026-09-29: created by /milestone-plan.
- 2026-09-29: criteria audit (full mode) by a fresh reader returned 15 findings. All had one clear fix and were fixed at the gate. The `request_target()` criterion moved to T5, because it bound a test instrument.
- 2026-09-29: plan gate chose to fail a live embedding test on a model-list error over a skip that quotes the error. A skip keeps the suite green on a misconfigured machine. Falsified by a routine check setup whose server rejects the token on purpose.
- 2026-09-29: plan gate chose both parts of the `request_target()` row over the parse guard alone. The header part is small and closes the row. Falsified by an opt-in that callers other than the header readers need.
- 2026-09-29: plan chose a hint flag read off the built request over one token read passed to `lms_client()`. A `NULL` result is read again inside `lms_client()`, so the race stays. Falsified by an httr2 release that drops the header name from the request object.
- 2026-09-29: implement started on branch m055-teardown-cleanup. Question gate skipped, because the plan left no choice open.
- 2026-09-29: T1 done. Both vignettes read `server_was_running` and `model_was_loaded` in hidden chunks, and the unload, stop, and `with-daemon` chunks run only on those flags. The `with-daemon` block reads its own `loaded_here` flag in visible code, because its unload runs inside `with_lms_daemon()`. No R code changed, so no test run.
- 2026-09-29: T2 done. After `devtools::install()` of b14cffd, the eight renders all exited 0, and each left `running` and the `lms ps` listing of `google/gemma-3-1b` as they were before it. Control: the main vignette `getting-started.Rmd`, rendered from running with the model loaded, left the server stopped and the model unloaded. A kept render of `headless-config.Rmd` from stopped with no model showed `lms_ready` TRUE and the load, unload, and stop output, so the chunks ran live.
- 2026-09-29: T3 done. The AC2 sweep over four files lists five calls, all inside `with_mock_dir()` blocks. With the token set, the server running, and `google/gemma-3-1b` loaded, `devtools::test(filter = "^(chat|integration)$")` passed 1584 and left the model loaded. Control: main's `test-integration.R`, run live the same way, unloaded it. Full `devtools::test()` with T3 to T5 in the tree: 0 failures, 0 skips, 14646 passes, and the model stayed loaded.
- 2026-09-29: T4 done. `loaded_embedding_models()` in `helper-skips.R` serves both live tests, and `test-skip-helpers.R` holds the AC3 test plus a skip and a return control. Planted defect: the old `tryCatch()` put back in the helper turned the AC3 assertions red.
- 2026-09-29: T5 done. `request_target()` takes `redact_headers = TRUE`, httr2's own name, and returns a body that fails `jsonlite::validate()` as its text, so a URL-like text is never fetched. Twelve header reads in five files pass `redact_headers = FALSE`. A redacted header is an httr2 `httr2_redacted_sentinel` object, not a string. Against main's helper, the new tests in `test-mock-http-helper.R` gave 5 failures.
- 2026-09-29: correction to the T5 line: eleven header reads pass `redact_headers = FALSE`, not twelve. Ten are single-line calls, and one call spans lines.
- 2026-09-29: T6 done. `request_sends_token()` in `R/utils-token.R` reads the header name off the built request. The eight sites and the embed flag use it. `grep -n 'rlm_token(' R/*.R` lists `R/chat.R:2013` (`lms_client()`) and `R/serve.R:136`. `test-token-hint.R` drives each of the nine `rlm_abort_api()` sites to 401 twice and checks the table against the grep. Control: against main's `R/`, 32 assertions failed, 2 per run at each of the eight non-embed sites. The embed site passed before the change, because it read its flag at request build. The Review section is review's to write, so review carries that fact. Full `devtools::test()`: 0 failures, 0 skips, 14777 passes. `document()` changed nothing.
- 2026-09-29: T7 done. NEWS.md has one entry for the hint and one for the vignettes. With the token set, `devtools::document()` then `devtools::check()`: 0 errors, 0 warnings, 0 notes. Before and after the check, the server was running and `google/gemma-3-1b` was loaded.
- 2026-09-29: claim audit: 68 claims read, 4 corrected — NEWS.md, vignettes/getting-started.Rmd, vignettes/headless-config.Rmd. The NEWS vignette entry overstated what a build restores, named one vignette where both unloaded, and said the daemon stops where the call can leave it running. One vignette sentence overstated the same restore. The reader also flagged two unchanged sentences, one per vignette, that the new gates made false, and they were rewritten. Its one re-read found the corrected text true. The edits are prose only, so the T2 renders and the T7 check still apply.
- 2026-09-29: implement done, status review.
- 2026-09-29: review gate: the user chose to narrow AC1 and re-review. Fix-now findings O5, O7, O10, and O11 landed on the branch. O1 and O3 extend the headless-daemon candidate row, and O2, O4 with O8, and O9 are new candidate rows.
- 2026-09-29: amendment return: AC1 — "If the LM Studio desktop app keeps the daemon running, a render of either vignette leaves two facts as they were."
- 2026-09-29: implement resumed for the AC1 amendment alone. Branch synced, main had not moved.
- 2026-09-29: re-audit: AC1 (full) — one clear fix: `"isDaemon": false` was an unproven proxy for the desktop app, so the host check became the same `pid` before and after plus a `ps -p` name. One open point: the Goal promises more than AC1, disposed at the mini gate by a Scope Out sentence. Also noted: D-002 makes all three platforms release commitments, so a confirmed headless defect still bears on a release.
- 2026-09-29: mini gate: the user accepted the fixed AC1 and the Scope Out sentence.
- 2026-09-29: re-audit: AC1 (full) — two narrowing fixes: the daemon check decides which renders count instead of reading as a third fact to keep, and the procedure names one such host. The Scope sentence also covers `getting-started.Rmd`, kept to match the AC1 condition. The user accepted both fixes at a second gate, so AC1 wording is now closed to further readers.
- 2026-09-29: T2 reopened, because its procedure gains the daemon read.
- 2026-09-29: T2 done again. After `devtools::install()` of 35aec07, the eight renders all exited 0. Each left `running` and the `google/gemma-3-1b` instance count (1 or 0) as they were. Before and after each, `lms daemon status --json` read `running` with pid 81115, and `ps -p` named `/Applications/LM Studio.app/Contents/MacOS/LM Studio`. Liveness: the kept HTML of both renders from a stopped server with no model shows the live unload output, and `getting-started` shows the live stop.
- 2026-09-29: claim audit: 11 claims read, 0 corrected — R/utils-token.R, tests/testthat/test-token-hint.R, vignettes/getting-started.Rmd. The reader covered the 32 lines that the review fixes added after the first audit (`git diff 9a88b28..HEAD`).
- 2026-09-29: with the token set, full `devtools::test()` at 35aec07 plus this record: 0 failures, 0 errors, 0 warnings, 0 skips, 14777 passes. No R code changed in this session.
- 2026-09-29: implement done after the amendment, status review.
- 2026-09-29: second review pass: fresh evidence for AC1 to AC5, three fresh reviewers, and five fix-now findings fixed in 76cb2fd at the user's choice.
- 2026-09-29: step-7 approval: m055-teardown-cleanup approved for merge
- 2026-09-29: resume at step 8: the PR #55 `test-coverage` job failed in the site-count test of `test-token-hint.R`, and one `test-headless` job failed on an r2u mirror timeout and was rerun. The count fix is test-only, so the approval stands.

## Decisions

## Review

Branch head 9a88b28, synced with main (main had not moved). Evidence gathered 2026-09-29.

- AC1: After `devtools::install()` of 9a88b28, the eight renders (two vignettes, four starting states) all exited 0. Each left `running` and the count of `google/gemma-3-1b` instances in `lms ps --json` as they were before it (1 or 0 each time). A first harness run was void. Its `lms load` added a second instance, so no "not loaded" state existed. The rerun unloaded every instance first. Liveness control: I rendered both vignettes from a stopped server with no model and kept the HTML. Both files show the unload and stop output, so the live chunks ran.
- AC2: The sweep reads four files and lists five calls: `test-integration.R:15` and `:25`, `test-chat.R:13`, `:14`, and `:35`. All five sit inside `httptest2::with_mock_dir()` blocks. With the token set, the server running, and `google/gemma-3-1b` loaded, `devtools::test(filter = "^(chat|integration)$")` gave 0 failures, 0 skips, and 1584 passes. `lms ps --json` listed the model before and after the run. The one "unloaded" line in the output took 4 ms, which is a replayed mock reply.
- AC3: `test-embed.R:1116` and `:1140` take the list from `loaded_embedding_models()` in `helper-skips.R`, which has no `tryCatch()`. `test-skip-helpers.R` mocks `list_models()` to raise `rlmstudio_api_error` at 401, `rlmstudio_bad_response`, and a `stop()` error. For each, it asserts the same class and no skip. With the real helper, the file gave 10 passes and 0 failures. Planted defect: a helper with the old `tryCatch()` fallback, run with helper loading off, gave 7 failures.
- AC4: `grep -n 'rlm_token(' R/*.R` lists two sites, `R/chat.R:2013` in `lms_client()` and `R/serve.R:136` in `lms_server_start()`. The `rlm_abort_api(` grep lists nine sites outside roxygen lines, in `chat.R` (3), `download.R` (2), `load.R`, `list.R`, `embed.R`, and `unload.R`. `test-token-hint.R` holds one table entry per site and asserts that the table size equals the grep count. It drives each site to a 401 twice, once per AC4 run, and asserts the matching hint. On the branch, the file gave 131 passes and 0 failures. Control: the same tests against main's `R/` plus the new helper gave 32 failures, 16 per run. That is two per run at each of the eight non-embed sites. The embed site passes against main too, because main already computed its flag at request build and not after the reply.
- AC5: With the token set, `devtools::test()` gave 0 failures, 0 errors, 0 warnings, 0 skips, and 14777 passes. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and the server and model state was the same before and after it. NEWS.md has one entry for the hint change and one for the vignette teardown.

Consistency gate: `cairn_validate.py` exited 0 with all checks passed. `devtools::document()` left `NAMESPACE` and `man/` unchanged. The branch does not touch `README.Rmd`, and the repo has no `_pkgdown.yml`. The branch adds no top-level file. NEWS.md has both entries, with no milestone numbers. The branch changes no DESIGN principle, so `cairn_impact` did not run.

Independent review: three fresh reviewers ran. [O] is the diff reviewer, [B] the blame-history reviewer, and [P] the prior-review reviewer. The PR-comment probe found no review comments. Findings, most severe first, with the disposition the user accepted at the gate:

- O1 (medium): On a real headless host, the `stop-stack` chunk of `headless-config.Rmd` stops the daemon, and the models go with it. A model loaded before the build is then gone after it, so AC1 fails there. The AC1 procedure ran on macOS, where the desktop app keeps the daemon running. Disposition: amendment return on AC1, and the case joins the headless-daemon candidate row.
- O2 (low-medium): `lms_server_status(json = TRUE)` parses stdout joined with stderr. If stderr holds a notice, the parse fails, the vignette reads the server as stopped, and the build stops a server that ran before it. Disposition: follow-up, a new candidate row.
- O3 (low): `headless-config.Rmd` reads the server state after `lms_daemon_start()`. If a daemon start also starts the server, the build leaves both running. Not confirmed. Disposition: follow-up, into the headless-daemon row.
- O4 (low), with B3: `request_sends_token()` reads the httr2 field `req$headers`, and DESCRIPTION has no httr2 floor. httr2 exports `req_get_headers()`. Disposition: follow-up, a new candidate row, because a version floor is a dependency change.
- O5 (low): `test-token-hint.R` asserts the header with `request_sends_token()`, the function under test. Disposition: fix now, with an independent read through `request_target(redact_headers = FALSE)`.
- O6 (low): the site-table test compares counts only. Disposition: reject. A removed site fails its own table entry, because its call no longer raises its label.
- O7 (low): the `request_sends_token()` comment says each wrapper reads the request it built, but `lms_embed()` reads the client. Disposition: fix now, a comment edit.
- O8 (low): `test-mock-http-helper.R` expects the httr2 1.3 class `httr2_redacted_sentinel`, with no version pin. Disposition: follow-up, in the O4 row.
- O9 (low): the live test at `test-list-instances.R:410` still turns a refused model list into a skip, the pattern this milestone removed from the embedding tests. Disposition: follow-up, a new candidate row.
- O10 (low): `getting-started.Rmd:157` says the build leaves the state as it found it. That holds only for a build that finishes. Disposition: fix now, a prose edit.
- O11 (cosmetic): four assertions in `test-token-hint.R` have no `info = site$label`. Disposition: fix now.
- O12 (process): the Review section was empty and the criteria unticked at handoff. Disposition: noted, this section closes it.
- B1 (low): the live embedding tests now fail where they skipped before, with no D-entry. Disposition: noted, the plan-gate work-log line records the choice.
- B2 (low): a failed re-record of a fixture no longer unloads the model. Disposition: reject. A re-record is a manual step, and the unload inside the mock block remains.
- B4, with P1 (low): `request_target()` now redacts by default, which reverses the M009 default. Disposition: reject, T5 called for it.
- B6 (low): if the server ran before the build, the `with-daemon` chunk does not run. Disposition: reject, T1 called for it.
- B7 (low): `headless-config.Rmd` still stops a daemon that ran before the build. Disposition: reject, pre-existing and already in the headless-daemon row.
- B8 (low): the M009 lesson in `LESSONS.md` says a check can leave the server off, which this milestone makes false. Disposition: fix at hygiene.
- P2 (low): `request_body_text()` dry-runs with `redact_headers = FALSE`. Disposition: reject. The dry run is quiet and returns only the body.
- P3 (low): the `model-before` chunk calls `list_models()` and can fail on a server that rejects the token. Disposition: reject. If `lms_ready` is FALSE, the chunk does not run, and `lms_server_ready()` reports FALSE for a rejected token.
- B5, B9, P4: no finding.

Gate outcome, 2026-09-29: the user chose to narrow AC1 and re-review, not to merge. The four fix-now items landed on the branch. For O5, each run now reads the `authorization` header through `request_target(redact_headers = FALSE)`. For O11, `expect_s3_class()` takes no `info` argument, so those two assertions became `expect_true(inherits(...), info = site$label)`. For O7, the new comment says that no later step in `lms_embed()` changes the `Authorization` header. A read of `embed_request()` backs that: its one later header write is the content type from `rlm_req_body()`. After the fixes, `devtools::test()` gave 0 failures, 0 skips, and 14777 passes, and `devtools::document()` gave no diff. The AC1 box is cleared again, because its text changes before the next review.

### Second pass

Branch head 7206ce5, after the AC1 amendment. Main had not moved. Evidence gathered 2026-09-29.

- AC1 (amended text): After `devtools::install()` of 7206ce5, the eight renders (two vignettes, four starting states) all exited 0, each through `rmarkdown::render(output_dir = tempdir())`. Each left `running` and the count of `google/gemma-3-1b` instances in `lms ps --json` as they were before it (1 or 0 each time). Before and after every render, `lms daemon status --json` read `running` with pid 81115, and `ps -p 81115` named `/Applications/LM Studio.app/Contents/MacOS/LM Studio`, so all eight renders count. Liveness control: the kept HTML of the two renders from a stopped server with no model shows timed live unload lines and the stop line. The kept HTML of `headless-config.Rmd` from a running server with the model loaded shows none, so the gates skipped the teardown there.
- AC2: The sweep reads four files (`test-chat.R`, `test-list-instances.R`, `test-integration.R`, `test-embed.R`) and lists five calls: `test-integration.R:15` and `:25`, `test-chat.R:13`, `:14`, and `:35`. The mock blocks open at `test-chat.R:12` and `test-integration.R:14` and close at `:36` and `:26`, so all five sit inside them. With the token set, the server running, and `google/gemma-3-1b` loaded, `devtools::test(filter = "^(chat|integration)$")` gave 0 failures, 0 errors, 0 skips, and 1584 passes. `lms ps --json` listed `google/gemma-3-1b` before and after the run.
- AC3: `test-embed.R:1116` and `:1140` take the list from `loaded_embedding_models()` in `helper-skips.R:17`, which calls `list_models()` with no `tryCatch()`. `test-skip-helpers.R` mocks `list_models()` to raise `rlmstudio_api_error` at 401, `rlmstudio_bad_response`, and a `stop()` error. For each, it asserts the same class and no skip, and it asserts status 401 on the first. On the branch, the file gave 10 passes and 0 failures. Planted defect: a helper whose `tryCatch()` turns a list error into a skip, run with helper loading off, gave 7 failures and 3 passes. The 7 are the three class checks, the three no-skip checks, and the status check.
- AC4: `grep -n 'rlm_token(' R/*.R` lists `R/chat.R:2013` in `lms_client()` and `R/serve.R:136` in `lms_server_start()`. The `rlm_abort_api(` grep, roxygen lines left out, lists nine sites. They are `chat.R:235`, `:546`, `:1214`, `download.R:99`, `:231`, `embed.R:291`, `list.R:425`, `load.R:145`, and `unload.R:68`. `test-token-hint.R` drives each to a 401 in both AC4 runs. On the branch, it gave 131 passes and 0 failures. Control: main's `R/` with the branch `tests/` gave 32 failures, 4 at each of the eight non-embed site labels and none at "Embeddings Failed". It also gave 1 error, because `request_sends_token()` does not exist on main.
- AC5: With the token set, `devtools::test()` gave 0 failures, 0 errors, 0 warnings, 0 skips, and 14777 passes. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. The server ran and `google/gemma-3-1b` was loaded before the test run, between the runs, and after the check. NEWS.md has one entry for the hint change and one for the vignette teardown.

Consistency gate (second pass): `cairn_validate.py` passed every check. `devtools::document()` left `NAMESPACE` and `man/` unchanged. The branch does not touch `README.Rmd` or `DESIGN.md`, and the repo has no `_pkgdown.yml`. The branch adds no top-level file, and NEWS.md names no milestone.

Independent review (second pass): three fresh reviewers ran on the full diff at 7206ce5. The ids take an `S-` prefix to keep them apart from the first pass. The PR-comment probe returned no comments. No finding shows an acceptance criterion failing. Findings, most severe first, with the proposed disposition:

- S-O1, with S-B5 (medium-low): the NEWS vignette entry has no host condition. On a headless host with the server stopped and the model loaded, `stop-stack` runs `lms_daemon_stop()`, and the model goes with the daemon. The entry implies that the build now keeps the model. Proposed: fix now, a NEWS prose edit.
- S-O2 (medium-low): `headless-config.Rmd:150-152` and `:177` say that the build unloads the model only if it was not loaded before, and only if the block loaded it. That is true of the `lms_unload()` calls. On a headless host, the `lms_daemon_stop()` in `stop-stack` and the `on.exit()` stop in `with_lms_daemon()` (`R/daemon.R:201`) also unload the models. Proposed: fix now, a vignette prose edit.
- S-O3 (low): `getting-started.Rmd:157` says that a finished build leaves the server and model state as it found them, with no host condition. No render on a headless host backs that. Proposed: fix now, a vignette prose edit.
- S-O4 (low): the O5 fix calls `request_target()` inside the site loops of `test-token-hint.R`. `request_target()` calls `require_httpuv()`, which skips when httpuv is absent and CI is unset. The skip then ends the whole block, so no site's hint check runs. Proposed: fix now, with the header reads in their own blocks.
- S-P2 (low): the site-count test in `test-token-hint.R` leaves out roxygen lines but counts a plain `#` comment that names `rlm_abort_api(`, and it counts two calls on one line as one. Proposed: fix now, with comment lines left out and every call on a line counted.
- S-O5 (process): the Goal has no host condition. The mini gate settled that with the Scope Out sentence. Proposed: noted, because the S-O1 to S-O3 fixes close what users read.
- S-B1 (low): `request_target()` now returns a body that is not JSON as text, where the parse error once caught a malformed body. Proposed: reject, because T5 called for it, and a test that reads a body field still errors on text.
- S-B2 (low): the removed `on.exit()` unload leaves a model loaded after a failed live re-record. Proposed: reject, the first-pass B2 reason.
- S-B3 (low): the "When this vignette is built" paragraphs put build text in user docs. Proposed: reject, because T1 called for the gates and the paragraphs explain them.
- S-B4, with S-P3 (low): the embed site in the hint table cannot fail against a revert. Proposed: noted, T6 and the AC4 control already record it.
- S-B6 (low): the `model-before` chunks call `list_models()` after the readiness check. Proposed: reject, the first-pass P3 reason.
- S-B7 (low): `request_sends_token()` reads `req$headers`, and DESCRIPTION has no httr2 floor. Proposed: noted, the O4 candidate row holds it.
- S-O6 (cosmetic): the `with-daemon` example carries build bookkeeping. Proposed: reject, T1 called for it.
- S-P1 (low): the M009 lesson in `LESSONS.md` is stale. Proposed: fix at hygiene, as the first-pass B8.
- S-P4 (low): `request_target()` now redacts by default. Proposed: reject, the first-pass B4 reason.

Gate outcome (second pass), 2026-09-29: the user chose to fix first and be asked again. Every proposed disposition above stands. The fix-now edits:

- S-O1: the NEWS vignette entry now says that the rules keep the state where the desktop app runs the daemon. On a host without it, the daemon stop in `headless-config.Rmd` can also unload a model that was loaded before the build.
- S-O2: `headless-config.Rmd` says the same in its teardown section. The `with-daemon` text now says that the block calls `lms_unload()` only if it loaded the model, and that the daemon stop on exit can unload a model loaded before it.
- S-O3: the `getting-started.Rmd` sentence now opens with the desktop-app host condition.
- S-O4: the header reads moved out of the two hint loops into their own block. Control: with `require_httpuv()` replaced by a skip, the new file still ran 54 hint checks in each hint block, and only the header block skipped. The old file stopped each hint block after the first site, with 3 passes.
- S-P2: `count_abort_calls()` leaves out every comment line and counts each call on a line. A new block checks a code line (1), a roxygen line (0), a plain comment (0), and a line with two calls (2). The site count on `R/` is still 9.

After the fixes, `devtools::test()` gave 0 failures, 0 skips, and 14781 passes, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. The server and model state was the same before the test run and after the check. `devtools::document()` gave no diff. The vignette edits are prose only, so the AC1 renders still apply.

CI fix after approval, 2026-09-29: on PR #55, `test-coverage` failed twice at `test-token-hint.R:107-108` with a site count of 0. Under covr, `test_path("..", "..", "R")` is the installed package's `R/` folder, which exists but holds no `.R` file, so the `dir.exists()` guard let the count run over nothing. The test now skips when that folder lists no `.R` file and keeps the `hits > 0` check. In a copy of the tests under a folder whose `R/` held only `rlmstudio`, `.rdb`, and `.rdx` files, the old file gave the same 2 failures and the new file skipped. From sources, the test counts 9 sites and passes. With the token set, `devtools::test()` gave 0 failures, 0 skips, and 14781 passes. A `test-headless` job failed at `apt-get` when the r2u mirror timed out. The push run of the same commit passed, so the job was rerun.
