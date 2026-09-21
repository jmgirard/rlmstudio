# M015: The server start call takes a token and checks its wait arguments before it starts

- **Status:** review
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

- [x] AC1: `lms_server_start(token = "t")` sends `Authorization: Bearer t` on
      its readiness request. With `token = NULL`, it sends the value of the
      `rlmstudio.token` option. A test reads the header off the recorded
      readiness request in both cases.
- [x] AC2: Before `processx::run()` runs, `lms_server_start()` builds its
      readiness request from a non-`NULL` `host`. It uses the same helper as
      `lms_server_ready()`. If the build rejects `host`, the call aborts with a
      message that names `host`. `lms_server_ready()` keeps its own messages.
      A test runs each of these values against a `processx::run` stub. Any
      call to the stub fails the test. It does this with `wait = 10` and with `wait = 0`.
      The values are two strings, `NA_character_`, `""`, `1`, `list("a")`,
      `character(0)`, `"http://local host:1234"`, and `"localhost:1234"`. The
      values `NULL` and `"http://localhost:1234"` pass.
- [x] AC3: Before `processx::run()` runs, `lms_server_start()` passes `token`
      to `rlm_token()`. This holds for `host = NULL` too. A rejected `token` aborts
      there, with `wait = 10` and with `wait = 0`. A test runs two strings,
      `NA_character_`, and `1` against the same stub, with `host` left at
      `NULL`. It matches the message against `token`.
- [x] AC4: With AC2 and AC3 in place, an abort from `lms_server_ready()`
      during the wait has no known trigger. This criterion is the fallback for
      one. If `lms_server_ready()` aborts during the wait, `lms_server_start()`
      raises one warning that names the host. It then returns the CLI exit
      code. A test mocks `lms_server_ready()` to abort. It asserts the return
      value, one warning, and the warning message.
- [x] AC5: `lms_server_start()` raises three warnings: the wait ran out, no
      host was found, and the probe aborted. With `token = "secret-token-xyz"`,
      none of the three carries the token in its `conditionMessage()`. A test
      asserts this for all three.
- [x] AC6: `?lms_server_start` documents `token`. It states that two faults
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
- [x] T4: Tests first for AC4 and AC5. Catch an abort from the probe in
      `warn_unless_ready()` and raise one `cli::cli_warn()` that names the
      host. Wrap the read so that a warning from the probe does not double the
      warning (LESSONS, M014).
- [x] T5: Update the roxygen for `lms_server_start()` and NEWS.md. Run
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
- 2026-09-20: T4 done. `warn_unless_ready()` turns an abort from the wait into one `cli_warn()` that names the host and quotes the abort message, with `suppressWarnings()` inside the `tryCatch()`. Removing `suppressWarnings()` turned the double-warning test red. The AC5 probe-abort case uses a mocked abort message that holds no token, so it checks only the text the package composes.
- 2026-09-20: T5 done. The `?lms_server_start` page documents `token`, the two pre-start aborts, and the third warning. The quiet-option test now covers all three warnings. NEWS.md has three new bullets, and the old sentence saying that the request passes `token = NULL` is gone. `document()` gave no further diff. `devtools::check()` with the token set gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-20: claim audit: 26 claims read, 3 corrected — R/serve.R, tests/testthat/test-serve.R, NEWS.md. The reader re-read all six changed lines and all hold. It found that a malformed caller `port` can still reach the probe-abort warning when the CLI accepts it, because `port` stays out of scope. The AC4 premise "no known trigger" is therefore not strictly true. Its tested promise still holds, and the criterion text was not amended.
- 2026-09-20: re-verified after the wording fixes. `devtools::test()` is green, `devtools::check()` with the token set gave 0 errors, 0 warnings, and 0 notes, and `document()` gave no diff. Status is now review.

## Decisions

## Review

Evidence gathered 2026-09-20 on branch head ee37644, which already contains `origin/main` (0e09922).

- AC1: `test-token-wrappers.R` "lms_server_start sends its token, or the option, on the readiness request" passed, 4 expectations, 0 skipped. It reads `Bearer t` with `token = "t"` and `Bearer option-token` with `token = NULL` off the one recorded request. The table test lists fourteen functions and passed.
- AC2: `R/serve.R` calls `rlm_check_ready_host(host)` for a non-`NULL` host before `processx::run()`. That helper and `lms_server_ready()` both build through `server_ready_request()`. `test-serve.R` "a host the readiness request cannot be built from aborts first" passed with 48 expectations. It runs the eight listed values at `wait = 10` and `wait = 0` and matches `` `host` `` in each message. A `processx::run` stub fails the test on any call. "a NULL host and a usable host pass the pre-start check" passed with 4 expectations. `test-server-ready.R` is unchanged on the branch and passed. In a scratch copy, replacing the host check with `invisible(NULL)` turned that one test red.
- AC3: `R/serve.R` calls `rlm_token(token)` before the host check and before `processx::run()`, with `host` at any value. `test-serve.R` "a bad token aborts before the CLI runs, with host left NULL" passed with 6 expectations. It runs two strings, `NA_character_`, and `1` at both wait values against the failing stub and matches "`token` must be one character string". In a scratch copy, removing the `rlm_token(token)` call turned that one test red.
- AC4: `test-serve.R` "an abort from the probe during the wait becomes one warning" passed with 5 expectations. It mocks `lms_server_ready()` to abort. It asserts a return value of 0 and one warning. The warning holds the host `127.0.0.1:9999`, the quoted abort text, and the matched phrase "could not ask". "a warning raised by the probe before it aborts is not doubled" passed with 3 expectations. In a scratch copy, removing the `suppressWarnings()` wrapper turned that one test red.
- AC5: `test-serve.R` "none of the three wait warnings carries the token" passed with 9 expectations. It passes `token = "secret-token-xyz"` and raises each of the three warnings in turn. For each it asserts one warning, matches the warning's own text, and asserts that `conditionMessage()` does not hold the token. The probe-abort case uses a mocked abort message without the token, so it covers only the text the package writes.
- AC6: `man/lms_server_start.Rd` has a `token` item at line 32. Its section at line 69 names the two faults that abort before the CLI runs. They are a `host` the request cannot be built from and a `token` that is not one string or `NULL`. NEWS.md has three new bullets for `token`, the pre-start checks, and the probe-abort warning. `devtools::check()` with `RLMSTUDIO_API_TOKEN` set gave 0 errors, 0 warnings, and 0 notes in 37.7 s, and its `document()` step left the tree clean.
- Consistency gate: `cairn_validate.py` exited 0 with all checks passed. `devtools::document()` gave no diff. `pkgdown::check_pkgdown()` found no problems. README.Rmd and README.md are untouched on the branch. No new top-level files. No DESIGN principle changed, so `cairn_impact.py` was skipped.

### Independent review

Three fresh reviewers ran. The [S] blame-history reviewer and the [S] prior-review reviewer reported no findings. The prior-review reviewer found that the diff closes M014 finding O1 and follows M014 finding O2 and the M009 token wording. The [O] diff-bug reviewer reported 11 findings, ranked below. Findings 1 and 2 were confirmed by command. Dispositions are proposed here and decided at the merge gate.

1. `forbid_cli()` in `test-serve.R` calls `fail()` inside `expect_error()`, which counts that call as the expected error. The AC2 and AC3 tests go red on a stub call only through their message match. Proposed: fix now, with a flag the test asserts after the loop.
2. No test checks that the host abort quotes the httr2 or curl reason. With the `"x" = "{reason}"` line removed, the serve tests stayed green. Proposed: fix now, with one expectation on a known reason.
3. The AC5 probe-abort case uses a mocked message without the token, so it cannot detect a leak passed through from the probe. The work log records this. Proposed: reject, because the package composes no token text, and M009 keeps the token out of the probe's own aborts.
4. A malformed `port` with `host = NULL` reaches the probe-abort warning when the CLI accepts it. The claim audit found this. Proposed: follow-up as a new candidate row for a pre-start check of the host built from `port`.
5. The help page says two faults abort before the CLI runs, but a bad `wait` does too. Proposed: fix now, by naming `wait` beside them.
6. The comment above `rlm_token(token)` in `R/serve.R` gives a wrong reason for the order, because the host check always passes `token = NULL`. Proposed: fix now.
7. `suppressWarnings()` drops every probe warning during the wait, not only one before an abort. Proposed: reject, because `lms_server_ready()` raises no warning on its return paths and the LESSONS M014 pattern calls for this wrapper.
8. The host abort omits `parent = e`, so `rlang::last_error()` loses the httr2 or curl condition. Proposed: reject, because the reason is already quoted and a parent prints it twice.
9. `token = ""` falls through to the option, and the `token` help text does not say so. Proposed: reject, because every wrapper shares this and the diff did not add it.
10. A quoted cli message can carry color codes inside the warning bullet. Proposed: reject as cosmetic.
11. The `lms_server_start` row in the token table has no fake clock and relies on a ready response. Proposed: reject, because every table driver in that file answers ready.
