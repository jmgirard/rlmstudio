# M055: Cleanup of vignette teardown, test helpers, and the token hint

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP5
- **Resolves:** —
- **Surface tier:** user-facing — the vignettes ship, and the 401 and 403 hint is part of exported abort messages
- **Branch/PR:** m055-teardown-cleanup

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
headless-daemon candidate row. The model download in both vignettes stays,
because the download is part of what the vignettes teach. The other rows
stay candidates in the ROADMAP.

## Acceptance criteria

- [ ] AC1: A render of either vignette leaves two facts as they were before
      it. The first fact is the `running` field of `lms server status
      --json`. The second fact is whether `lms ps --json` lists
      `google/gemma-3-1b`. This holds from four starting states: the server
      stopped or running, crossed with the model loaded or not. The
      procedure is eight live renders, one per vignette and state. Each
      render runs `rmarkdown::render(output_dir = tempdir())` after
      `devtools::install()` of the branch. Each reads both facts before and
      after the render.
- [ ] AC2: The sweep `grep -nE
      'lms_(load|unload|unload_all|download|server_start|server_stop|daemon_start|daemon_stop)\('
      $(grep -l 'skip_if_no_server()' tests/testthat/*.R)` lists no call
      that runs outside an `httptest2::with_mock_dir()` block. With the
      server running and `google/gemma-3-1b` loaded before it, a
      `devtools::test(filter = "^(chat|integration)$")` run leaves the model
      loaded. `lms ps --json` is read before and after the run.
- [ ] AC3: The two live tests in `tests/testthat/test-embed.R` that ask
      `list_models()` for the loaded embedding models take the list from a
      test helper that does not catch errors. A test mocks `list_models()`
      to raise three conditions in turn: `rlmstudio_api_error` at status
      401, `rlmstudio_bad_response`, and a plain `stop()` error. For each,
      it asserts that the helper raises that same condition class and
      signals no skip condition.
- [ ] AC4: `grep -n 'rlm_token(' R/*.R` lists two call sites: the body of
      `lms_client()` and the argument check in `lms_server_start()`. For each
      hit of `grep -n 'rlm_abort_api(' R/*.R` outside a roxygen comment
      line, a test drives the wrapper that reaches it to a 401 reply twice.
      In the first run, the `rlmstudio.token` option holds a token at
      request build and is cleared before the reply. That run asserts the
      hint for a sent token, which begins "The server rejected". In the
      second run, no token source holds a token at request build, and the
      option is set before the reply. That run asserts the hint that names
      `RLMSTUDIO_API_TOKEN`.
- [ ] AC5: `devtools::test()` and `devtools::check()` run with 0 errors and
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
      renders of AC1, and read both facts before and after each render.
- [x] T3: Delete the `on.exit()` unload fallbacks at
      `tests/testthat/test-chat.R:13-18` and
      `tests/testthat/test-integration.R:15-20`. Run the AC2 sweep and the
      live test run.
- [ ] T4: Add a helper to `tests/testthat/helper-skips.R` that reads the
      loaded embedding models from `list_models()` with no `tryCatch()`.
      If the model is absent, the helper skips. Use it in the two live tests
      at `tests/testthat/test-embed.R:1116` and `:1146`. Write the AC3
      test. It catches a skip with a `skip` handler, because `expect_error()`
      lets a skip through (M019 lesson).
- [ ] T5: In `request_target()` (`tests/testthat/helper-mock-http.R:144`),
      catch the JSON parse and return the body text as a character string.
      Add an opt-in argument for headers that are not redacted, and pass
      it at each caller that reads `authorization`. Test a JSON body, a
      non-JSON body, and the header read with and without the opt-in in
      `tests/testthat/test-mock-http-helper.R`.
- [ ] T6: Add one internal helper that reports whether a built request
      carries an `Authorization` header. Each wrapper passes its result to
      `rlm_abort_api()` in place of `!is.null(rlm_token(token))`, at the
      eight sites and at `has_token` in `R/embed.R:125`. Do not read the
      header off the response, because a mocked response carries no
      request. Write the AC4 tests. The embed site computes its flag at
      request build today, so its probe passes before the change. Say so in
      the Review section.
- [ ] T7: Write the NEWS entries. Run `devtools::document()` and
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

## Decisions

## Review
