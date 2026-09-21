# M014: The server start call can wait until the REST API answers

- **Status:** in-progress
- **Branch:** m014-server-start-wait
- **Priority:** normal
- **Depends on:** none
- **Driving RR:** —
- **Principles touched:** GP3, GP6
- **Resolves:** —
- **Surface tier:** user-facing. It adds two arguments to an exported function and changes the moment that function returns.

## Goal

`lms_server_start()` can wait until the REST API answers. A script then does
not report a missing server on a healthy machine.

## Scope

**In:** a `wait` argument and a `host` argument on `lms_server_start()`. The
polling helper behind them. The rule that picks the host to probe. The warning
for a wait that runs out. The documentation of the call faults that already
abort `lms_server_ready()`.

**Out:** a wait on `lms_daemon_start()` or `with_lms_daemon()`, which stays a
candidate row. A `token` argument on `lms_server_start()`, which stays a
candidate row. Any change to what `lms_server_ready()` returns or aborts on.
This milestone only documents that behavior.

## Acceptance criteria

- [ ] AC1: `lms_server_start()` takes a `wait` argument, a number of seconds.
      Its default is 10. Two conditions open the wait. The CLI must report
      success, and the call must have a host to probe. The call then asks
      `lms_server_ready()` again and again until it reports `TRUE`. No new
      readiness request starts after `wait` seconds
      pass. After the first `TRUE`, the call sends no further readiness
      request. With `wait = 0`, the call sends no readiness request and
      returns the CLI exit code.
- [ ] AC2: If `wait` is not one number, the call aborts before the CLI runs.
      A `wait` of `NA`, a negative `wait`, and a `wait` that is not finite all
      abort the same way. The message names `wait` and the rule the value
      broke. The abort carries no rlmstudio condition class. It carries only
      the classes that `cli::cli_abort()` attaches. That is what D-008 settled
      for an argument fault.
- [ ] AC3: The wait picks the host it probes in this order. If the caller
      gives a `host`, that host wins. If the caller gives no `host` and gives
      a `port`, the host is `http://localhost:<port>`. If the caller gives
      neither, the call reads the port that `lms_server_status(json = TRUE)`
      reports. If that read yields a port, the host is `http://localhost:`
      plus that port. AC4 covers the case where it yields none. The probe
      passes `token = NULL`. It therefore reads the `rlmstudio.token` option
      and then the `RLMSTUDIO_API_TOKEN` environment variable. The help page
      of `lms_server_start()` states this order.
- [ ] AC4: Take a `wait` above zero. If that many seconds pass with no
      readiness request reporting `TRUE`, the call does not abort. It returns
      the CLI exit code and raises a warning. The warning names the host it
      probed. It also names the `wait` argument. A second case raises its own
      warning. That case is a call with no `host` and no `port` whose port
      read yields nothing. Such a call sends no readiness request. Its warning
      names the failed port read, the `host` argument, and the `port`
      argument. Both warnings go through `cli::cli_warn()`. The
      `rlmstudio.quiet` option does not silence either one. This trades GP3
      and GP6. Aborting cannot undo a start that already ran. A wait that ran
      out is a fault rather than progress chatter.
- [ ] AC5: The help page of `lms_server_ready()` names call faults that abort
      it rather than returning `FALSE`. It names these six. A `host` of
      `NULL`. A `host` of more than one string. A `host` that is a character
      `NA`. A `host` that curl cannot parse as a URL. A `timeout` below one
      millisecond. A `timeout` that is not one number. The page attributes the
      URL message to curl and the other messages to httr2. The `token` fault
      that the page already names stays.
- [ ] AC6: `NEWS.md` carries an entry for the new `wait` and `host` arguments.
      The entry also covers the new default behavior. The `start-server` chunk
      of `vignettes/getting-started.Rmd` shows the waiting call. So does the
      `start-server` chunk of `vignettes/headless-config.Rmd`. In each file,
      the `check-ready` chunk stays as the gate that later chunks read.
- [ ] AC7: `Rscript -e 'devtools::document()'` produces no diff.
      `Rscript -e 'devtools::test()'` is clean.
      `Rscript -e 'devtools::check()'` reports zero errors and zero warnings.

## Coverage

- AC1 → T3, T4
- AC2 → T2, T4
- AC3 → T1, T4, T5
- AC4 → T4, T5
- AC5 → T5
- AC6 → T6
- AC7 → T6

## Tasks

- [x] T1: Run `lms server status --json` against a live LM Studio. Record the
      field path that holds the port in the work log. Add
      `server_status_port()` to `R/serve.R`. It reads that path out of
      `lms_server_status(json = TRUE)`. If the read yields no usable port, it
      returns `NULL`. Test it against a stubbed `lms_server_status()`. Include
      a shape that carries no port.
- [x] T2: Add `rlm_check_wait()` to `R/utils-args.R`, beside `rlm_check_id()`
      at `R/utils-args.R:12`. Test every rejected value that AC2 names. Test
      that the abort carries no rlmstudio class.
- [x] T3: Add `wait_for_server()` to `R/serve.R`. It polls
      `lms_server_ready()` and sleeps between tries. It stops at the first
      `TRUE`. After the budget, it starts no new request. Its tests stub
      `lms_server_ready()` and `base::Sys.sleep()`, so no test sleeps.
- [ ] T4: Wire `wait` and `host` into `lms_server_start()` at `R/serve.R:46`.
      Check `wait` before `processx::run()` runs. Pick the host as AC3 states.
      Warn as AC4 states. Test `wait = 0`, a stub that answers on the third
      try, the give-up warning, and the unknown-port warning.
- [ ] T5: Write the roxygen for `wait`, for `host`, and for the host order.
      Add the six call faults to the `lms_server_ready()` page. Write a test
      per fault that asserts the message text. Run `devtools::document()`.
- [ ] T6: Write the `NEWS.md` entry. Update the `start-server` chunk and the
      prose above it in both vignettes. If `README.Rmd` changes, run
      `devtools::build_readme()`. Run `devtools::test()` and
      `devtools::check()`.

## Work log

- 2026-09-20: created by /milestone-plan.
- 2026-09-20: criteria audit ran in full mode, in two passes. Each pass ran in a fresh reader that authored none of the text. Pass one returned eleven findings and pass two returned eight. All nineteen were fixed before this file was written.
- 2026-09-20: plan gate chose a `wait` argument on `lms_server_start()` over a new exported `lms_server_wait()`. Reason: the race belongs to the call that starts the server. Falsified by a user who needs to wait on a server that R did not start.
- 2026-09-20: plan gate chose reading the port from `lms_server_status(json = TRUE)` over two alternatives. They were probing port 1234, and skipping the wait for a call that gives no port. Reason: the default call is the one that hits the race. Falsified by a CLI status output that carries no port, or whose shape moves across LM Studio versions.
- 2026-09-20: plan gate chose a warning over an abort at the end of a wait that ran out. Reason: a slow start on a healthy machine must not fail a script. Falsified by a user whose script runs past the warning and fails later in a way that hides the cause.
- 2026-09-20: plan gate chose a default `wait` of 10 seconds over a default of 0. Reason: a script that never names the argument is the one that hits the race. Falsified by a caller that relies on the start call returning at once.
- 2026-09-20: implement gate settled three choices. The port read ignores the running flag. The poll pause is 0.25 seconds and each readiness request waits 1 second. Neither warning carries a catchable class.
- 2026-09-20: T1 done. `lms server status --json` prints one flat JSON object. It reads `{"running":false,"port":1234}`. Recorded against LM Studio CLI commit 69d945a. The port sits at the top level. `server_status_port()` reads `status[["port"]]`. The CLI reports the last used port while the server is stopped. Eleven tests in `tests/testthat/test-serve.R`. Three planted defects turned six of them red first.
- 2026-09-20: T2 done. `rlm_check_wait()` and `wait_fault()` in `R/utils-args.R`. A bare `NA` is a logical, so the missing value check runs ahead of the type check. A caller who wrote `wait = NA` reads about the missing value. Eighteen tests in `tests/testthat/test-utils-args.R`. A planted condition class turned the unclassed test red first.
- 2026-09-20: T3 done. `wait_for_server()` in `R/serve.R`. Its tests replace `base::Sys.time()` and `base::Sys.sleep()` with one fake clock that only a sleep moves forward. No test sleeps and the budget arithmetic is exact. The last sleep is trimmed to what the budget has left. Six tests. Two planted defects turned three of them red first.

## Decisions

## Review
