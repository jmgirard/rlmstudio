# M015: The server start call takes a token and checks its wait arguments before it starts

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** none
- **Driving RR:** —
- **Principles touched:** IP1, GP3, GP6
- **Resolves:** —
- **Surface tier:** user-facing. It adds an argument to an exported function and moves two aborts to before the server starts.
- **Branch/PR:** m015-server-start-token-and-host-check

## Goal

`lms_server_start()` takes a `token` for its readiness wait. A fault in `host`
or `token` never aborts after the CLI started the server.

## Scope

**In:** a `token` argument on `lms_server_start()`, passed to the readiness
request. One internal helper that builds the readiness request, used by
`lms_server_ready()` and by a check that `lms_server_start()` runs before the
CLI. A fallback warning for an abort from `lms_server_ready()` during the
wait. The help page, NEWS.md, and the token wrapper table in
`tests/testthat/test-token-wrappers.R`.

**Out:** a wait on `lms_daemon_start()` and `with_lms_daemon()`, which is M016.
Any change to what `lms_server_ready()` returns or aborts on. A check on
`port` or `cors`, which the CLI reads and reports on. The candidate rows about
guards over the token table and the condition help page stay candidates.

## Acceptance criteria

- [ ] AC1: `lms_server_start(token = "t")` sends `Authorization: Bearer t` on
      its readiness request. With `token = NULL`, it sends the value of the
      `rlmstudio.token` option. A test reads the header off the recorded
      readiness request in both cases.
- [ ] AC2: Before `processx::run()` runs, `lms_server_start()` builds its
      readiness request from a non-`NULL` `host`. It uses the same helper as
      `lms_server_ready()`. If the build rejects `host`, the call aborts with a
      message that names `host`. `lms_server_ready()` keeps its own messages.
      A test runs each of these values against a `processx::run` stub. Any
      call to the stub fails the test. It does this with `wait = 10` and with `wait = 0`.
      The values are two strings, `NA_character_`, `""`, `1`, `list("a")`,
      `character(0)`, `"http://local host:1234"`, and `"localhost:1234"`. The
      values `NULL` and `"http://localhost:1234"` pass.
- [ ] AC3: Before `processx::run()` runs, `lms_server_start()` passes `token`
      to `rlm_token()`. This holds for `host = NULL` too. A rejected `token` aborts
      there, with `wait = 10` and with `wait = 0`. A test runs two strings,
      `NA_character_`, and `1` against the same stub, with `host` left at
      `NULL`. It matches the message against `token`.
- [ ] AC4: With AC2 and AC3 in place, an abort from `lms_server_ready()`
      during the wait has no known trigger. This criterion is the fallback for
      one. If `lms_server_ready()` aborts during the wait, `lms_server_start()`
      raises one warning that names the host. It then returns the CLI exit
      code. A test mocks `lms_server_ready()` to abort. It asserts the return
      value, one warning, and the warning message.
- [ ] AC5: `lms_server_start()` raises three warnings: the wait ran out, no
      host was found, and the probe aborted. With `token = "secret-token-xyz"`,
      none of the three carries the token in its `conditionMessage()`. A test
      asserts this for all three.
- [ ] AC6: `?lms_server_start` documents `token`. It states that two faults
      abort before the CLI runs. One is a `host` that the readiness request
      cannot be built from. The other is a `token` that is not one string or
      `NULL`. NEWS.md has
      an entry. `devtools::document()` produces no diff. `devtools::check()`
      reports 0 errors and 0 warnings.

## Coverage

- AC1 → T2
- AC2 → T1, T3
- AC3 → T3
- AC4 → T4
- AC5 → T4
- AC6 → T5

## Tasks

- [x] T1: Move the request build out of `lms_server_ready()` (`R/serve.R`,
      near line 578) into one internal helper. `lms_server_ready()` calls it
      and keeps its return values and aborts. The existing
      `test-server-ready.R` tests stay green unchanged.
- [x] T2: Add `token = NULL` as the last formal of `lms_server_start()`. Pass
      it through `warn_unless_ready()` and `wait_for_server()` to
      `lms_server_ready()`, in place of the fixed `token = NULL`. Add
      `lms_server_start` to the table in `tests/testthat/test-token-wrappers.R`
      and write the AC1 header test.
- [x] T3: Tests first for AC2 and AC3. Then call the T1 helper in
      `lms_server_start()` next to `rlm_check_wait()`, before the CLI runs.
      Catch a `host` fault and abort again with a message that names `host`.
      Let the `rlm_token()` abort through. Delete the check in a scratch copy
      and make sure that the tests go red.
- [ ] T4: Tests first for AC4 and AC5. Catch an abort from the probe in
      `warn_unless_ready()` and raise one `cli::cli_warn()` that names the
      host. Wrap the read so that a warning from the probe does not double the
      warning (LESSONS, M014).
- [ ] T5: Update the roxygen for `lms_server_start()` and NEWS.md. Run
      `devtools::document()`, `devtools::test()`, and `devtools::check()`
      with `RLMSTUDIO_API_TOKEN` set (LESSONS, M009).

## Work log

- 2026-09-20: created by /milestone-plan.
- 2026-09-20: criteria audit (full mode, fresh [O] reader) returned 7 findings on the first draft and a re-check after the gate. Fixed: token faults tested at both wait values, three warnings rather than two, and a malformed host moved to the pre-start check.
- 2026-09-20: plan gate chose a pre-start build of the readiness request over a shape-only check on `host`. A malformed URL is a call fault knowable without a server, and D-008 puts such faults first. Falsified by a host that the build accepts and the probe rejects at build time.
- 2026-09-20: plan gate chose a warning over an abort for a probe abort during the wait. An abort cannot undo the start. Falsified by a caller who needs that fault to stop the script.
- 2026-09-20: implement started. Pre-implementation gate chose a host abort that names `host` and quotes the httr2 or curl reason, and a probe-abort warning that quotes the abort message.
- 2026-09-20: T1 done. `server_ready_request()` in `R/serve.R` builds the request, and `lms_server_ready()` calls it. `test-server-ready.R` is unchanged and green, and the full suite is green.
- 2026-09-20: T2 done. `token` is the last formal of `lms_server_start()` and reaches `lms_server_ready()`. The token table lists fourteen functions, and a new test reads `Bearer t` and the option token off the readiness request. Setting the forward in `wait_for_server()` back to `NULL` turned three expectations red.
- 2026-09-20: T3 done. `lms_server_start()` calls `rlm_token(token)` and then `rlm_check_ready_host(host)` before the CLI runs. The token check runs first, so the host check catches host faults alone. In a scratch copy, deleting either line turned its tests red. The full suite is green.

## Decisions

## Review
