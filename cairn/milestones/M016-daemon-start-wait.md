# M016: The daemon start call can wait until the daemon reports running

- **Status:** planned
- **Priority:** normal
- **Depends on:** none
- **Driving RR:** —
- **Principles touched:** GP3, GP5, GP6
- **Resolves:** —
- **Surface tier:** user-facing. It adds an argument to two exported functions and changes the moment they return.
- **Branch/PR:** —

## Goal

`lms_daemon_start()` can wait until `lms daemon status --json` reports the
daemon running.

## Scope

**In:** a `wait` argument on `lms_daemon_start()` and on `with_lms_daemon()`.
A polling helper that reads `lms daemon status --json`. The warnings for a
wait that runs out and for a status read that fails. The help pages and
NEWS.md.

**Out:** the token and host checks on `lms_server_start()`, which are M015. A
wait on `lms_daemon_stop()`, which no one asked for. Any change to
`lms_daemon_status()`, which reads `lms status` and not `lms daemon status`.

## Premise

Nobody observed `lms daemon up` return before the daemon is running. The
2026-09-20 plan session ran with the desktop app open. There,
`lms daemon status --json` printed
`{"status":"running","pid":36094,"isDaemon":false}`. T1 tests the premise. The
field name and value that AC1 to AC3 read come from T1's output. A change goes
through the amendment protocol. If `daemon up` does not return early, M016 is
dropped with that evidence. A command output with no running-state field
drops it the same way.

## Acceptance criteria

- [ ] AC1: `lms_daemon_start()` takes `wait`, with a default of 10 seconds.
      It calls `lms daemon status --json` until the status field reads
      `"running"`. It then returns the `lms daemon up` exit code with no
      warning. A test stubs `processx::run` and uses a fake clock, with
      `Sys.time` and `Sys.sleep` mocked. The stub reports a stopped state
      twice and then `"running"`. The test asserts three status calls and no
      warning.
- [ ] AC2: The budget can run out before a running status. Then
      `lms_daemon_start()` raises one warning that names `wait`, and it
      returns the exit code. The `rlmstudio.quiet` option does not silence
      the warning. A fake-clock test asserts the return value and one warning.
      It asserts that no status call starts after the budget. It asserts that
      the warning still fires with `rlmstudio.quiet = TRUE`.
- [ ] AC3: Three status faults stop the polling at once. One is a status
      call that exits non-zero. One is output that does not parse as JSON.
      One is output with no running-state field. On each, the call raises one warning and returns
      the exit code. A test covers each of the three cases. It asserts exactly
      one warning and one status call.
- [ ] AC4: `lms_daemon_start()` calls `rlm_check_wait(wait)` before
      `lms daemon up` runs. A test runs `-1`, `"10"`, `NA`, and `Inf` against
      a stub. Any call to the stub fails the test. With `wait = 0`, the call
      makes no status call. A test asserts that the stub saw only the
      `daemon up` call.
- [ ] AC5: `with_lms_daemon(code, wait = 10)` forwards `wait` to
      `lms_daemon_start()`. It still evaluates `code` after a wait that ran
      out. A test asserts the forwarded value and that `code` ran.
- [ ] AC6: `?lms_daemon_start` and `?with_lms_daemon` document `wait`.
      NEWS.md has an entry. `devtools::document()` produces no diff.
      `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T3
- AC3 → T1, T3
- AC4 → T2
- AC5 → T4
- AC6 → T5

## Tasks

- [ ] T1: Close the LM Studio desktop app. Run `lms daemon down`, then
      `lms daemon up`, then `lms daemon status --json` at once and again
      after a few seconds. Record in the work log whether `up` returned
      before the status read running. Record the exact JSON for the running
      and stopped states. Record what a failed status call prints. Amend
      AC1 to AC3 to the observed field, or drop M016 per the Premise.
- [ ] T2: Tests first for AC4. Add `wait = 10` to `lms_daemon_start()` in
      `R/daemon.R`. Call `rlm_check_wait(wait)` before `processx::run()`.
      Skip the wait for `wait = 0`.
- [ ] T3: Tests first for AC1 to AC3, with the fake clock from
      `tests/testthat/test-serve.R` (LESSONS, M014). Write the polling helper
      beside `wait_for_server()` in `R/serve.R`, with the same pause and
      budget rules. Warn through `cli::cli_warn()`. Wrap any parse that warns
      in `suppressWarnings()` inside the `tryCatch` (LESSONS, M014).
- [ ] T4: Tests first for AC5. Add `wait = 10` after `code` in
      `with_lms_daemon()` and forward it.
- [ ] T5: Update the roxygen for both functions and NEWS.md. Run
      `devtools::document()`, `devtools::test()`, and `devtools::check()`
      with `RLMSTUDIO_API_TOKEN` set (LESSONS, M009).

## Work log

- 2026-09-20: created by /milestone-plan.
- 2026-09-20: criteria audit (full mode, fresh [O] reader) returned 5 findings on the first draft and 1 on the re-check. The JSON shape joined the premise task. Quiet does not silence the warning. Three status faults stop the polling. The wait check became a call-order promise. A missing status field drops the milestone.
- 2026-09-20: plan gate chose to plan M016 with a premise task over keeping the daemon wait as a candidate. The desktop app blocked a check in the plan session. Falsified by T1 showing that `lms daemon up` returns only once the daemon runs.

## Decisions

## Review
