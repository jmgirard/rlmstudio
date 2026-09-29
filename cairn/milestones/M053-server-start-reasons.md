# M053: The server start call says why a start was refused

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4
- **Resolves:** —
- **Surface tier:** user-facing — it changes which calls of the exported `lms_server_start()` abort, and what the abort says
- **Branch/PR:** m053-server-start-reasons

## Goal

If its own checks or the LM Studio CLI refuse a start, `lms_server_start()` says what is wrong.

## Scope

**In:** A `port` check and a `cors` check, both before the CLI runs. The CLI output in the abort of a failed start. The help page, the stale comment in `warn_unless_ready()`, and NEWS.

**Out:** `lms_server_stop()` and `lms_daemon_start()` also drop the CLI output of a failed run. A new candidate row holds them. The TRUE/FALSE arguments of the other exported functions stay with the flags candidate row.

## Acceptance criteria

- [ ] AC1: `lms_server_start()` aborts for each rejected `port` value below. The abort carries no `rlmstudio_` condition class, and `processx::run()` is not called. Nine values are not one plain number: `"8080"`, `"abc"`, `TRUE`, `NA`, `list(8080)`, `factor("8080")`, `c(8080, 8081)`, `numeric(0)`, and `matrix(8080)`. Five are missing or not finite: `NA_real_`, `NA_integer_`, `NaN`, `Inf`, and `-Inf`. Seven are out of range or not whole: `-1`, `0`, `0L`, `8080.5`, `65536`, `99999`, and `1e10`. The message names `port` and the rule "one whole number from 1 to 65535". The accepted values `1`, `65535`, `8080L`, `8080`, and `c(p = 8080)` reach `processx::run()` after `"--port"`. They arrive as `"1"`, `"65535"`, `"8080"`, `"8080"`, and `"8080"`. `port = NULL` sends no `"--port"`. A test in `tests/testthat/test-serve.R` verifies this with a counting `processx::run()` mock. It drives each rejected value once with `wait = 0` and once with `host = "http://localhost:1234"`.
- [ ] AC2: `lms_server_start()` aborts for each rejected `cors` value: `"yes"`, `1`, `NA`, `NULL`, `logical(0)`, and `c(TRUE, FALSE)`. The abort carries no `rlmstudio_` condition class, `processx::run()` is not called, and the message names `cors`. `cors = TRUE`, `cors = c(x = TRUE)`, and `cors = matrix(TRUE)` send `"--cors"`. `cors = FALSE` sends no `"--cors"`. A test in `tests/testthat/test-serve.R` verifies this with a counting `processx::run()` mock. It drives each rejected value once with `wait = 0` and once with `host = "http://localhost:1234"`.
- [ ] AC3: If the CLI exits with a non-zero status, the abort message of `lms_server_start()` holds the exit code and the CLI output. The CLI output is the stderr text. If stderr is absent, `NULL`, or `NA`, or holds only whitespace, it is the stdout text. After `trimws()` and after each whitespace run is collapsed to one space on both sides, the message holds that text. If both outputs are absent, `NULL`, or `NA`, or hold only whitespace, the message holds the exit code and no CLI-output line. A test with a mocked `processx::run()` verifies seven cases. It compares texts after `gsub("\\s+", " ", trimws(x))` on both sides. The first case is the stderr text `error: option '-p, --port <port>' argument 'abc' is invalid. Not a number`, recorded from the CLI on 2026-09-28. The second is a text on stdout alone. The third is a stderr text that holds `{port}`, and its braces reach the message. The fourth is a stderr of two lines and more than 80 characters. The fifth is a status of 1 with no output fields. The sixth has text on both stderr and stdout, and only the stderr text reaches the message. The seventh has a stderr of only whitespace and a stdout text, and the stdout text reaches the message.
- [ ] AC4: The help page `man/lms_server_start.Rd`, read after `devtools::document()`, states four things. `port` must be `NULL` or one whole number from 1 to 65535, given as a number and not as an array. `cors` must be `TRUE` or `FALSE`. The sentence that counts the faults that abort before the CLI runs names `port` and `cors` among them. The abort of a failed start quotes the CLI output. In `R/serve.R`, `lms_server_start()` checks `port` and `cors` outside any branch on `wait`, `host`, or `token`. The comment above the `tryCatch()` in `warn_unless_ready()` no longer says that the CLI checks a malformed port.
- [ ] AC5: `NEWS.md` has one entry under the development version for these changes. The entry says that `port = "8080"` and `cors = NULL` now abort, and that a failed start quotes the CLI output. The entry states no behavior beyond what AC1 to AC3 state.
- [ ] AC6: `devtools::test()` reports no failures, and `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T1
- AC2 → T1
- AC3 → T2
- AC4 → T3
- AC5 → T3
- AC6 → T4

## Tasks

- [x] T1: Write the AC1 and AC2 tests first in `tests/testthat/test-serve.R`, and make sure that they fail against the current code. Add `port_fault()` and `rlm_check_port()` to `R/utils-args.R`, next to `rlm_check_wait()`. Follow the `wait_fault()` style: a plain-text detail with no cli braces. Call `rlm_check_port(port)` and `rlm_check_flag(cors, "cors")` beside `rlm_check_wait(wait)` at `R/serve.R:109`. Make `build_args_server_start()` send `as.character(as.integer(port))` with names dropped. In a scratch copy, delete each new call and make sure that its test goes red.
- [x] T2: Write the AC3 tests first. Then make the failed-start abort at `R/serve.R:133-137` add a CLI-output line. Splice the CLI text in as a value, so cli does not run its braces (LESSONS, M012). Treat a `stderr` or `stdout` field that is absent, `NULL`, or `NA` as empty, as the mock at `tests/testthat/test-serve.R:26` returns neither. Keep the `processx::run()` call to `command`, `args`, and `error_on_status`. Otherwise, update the mocks at `tests/testthat/test-token-wrappers.R:141-146` and `283-299` too.
- [x] T3: Update the `@param port` and `@param cors` text, the fault-count paragraph at `R/serve.R:63`, and a sentence on the failed-start abort. Rewrite the comment at `R/serve.R:225-231`. Run `devtools::document()`. Add the `NEWS.md` entry.
- [ ] T4: Run `devtools::test()`. Run `devtools::check()` with `RLMSTUDIO_API_TOKEN` set and the server started, because the vignettes make live calls (LESSONS, M009).

## Work log

- 2026-09-28: created by /milestone-plan.
- 2026-09-28: CLI probe with `lms` commit 69d945a. `lms server start --port` exited 1 with a stderr reason for `abc`, `99999`, `0`, `8080.5`, `-1`, and two ports. A port that another program held gave exit 0 and "Success!". The remembered port was set back to 1234 after the probe.
- 2026-09-28: criteria audit ran in full mode with a fresh [O] reader. It returned 10 findings, and each was fixed in the draft before the gate. The fixes cover whitespace in cli bullets, missing output fields, the fault-count sentence, and a code read for `wait`, `host`, and `token`. They also cover wider probe values, the `cors` class, behavior over test structure, the exact port rule, line references, and the token-wrapper mocks.
- 2026-09-28: a second fresh [O] reader audited the revised criteria in full mode and returned 7 findings, all fixed above. The fixes cover the trailing newline of CLI output, two more output cases, and a defined "absent". They add `1e10` for `port`, and `logical(0)` and `matrix(TRUE)` for `cors`. They anchor the comment by its code, not a line range, and bind the NEWS promise to the entry.
- 2026-09-28: plan gate chose an R-side port check plus the CLI output over the CLI output alone. The R check names the argument and does not depend on the CLI version. Falsified by an LM Studio release that accepts a port the R rule rejects, such as 0 for a random port.
- 2026-09-28: plan gate chose numbers only for `port` over also accepting strings of digits. It matches the help page and the `ttl` and `wait` checks. Falsified by a user whose port arrives as a string from a configuration file or an environment variable.
- 2026-09-28: plan gate chose to check `cors` here over leaving it to the flags candidate row. The helper exists and the call is the same. Falsified by a user who relies on `cors = NULL` acting as `FALSE`.
- 2026-09-28: plan chose to accept names on `port` and reject an array. `rlm_check_flag()` lets names pass, and `wait_fault()` rejects an array. Falsified by a user who passes a port read from a one-cell matrix.
- 2026-09-28: implement started on branch m053-server-start-reasons. Question gate skipped, as the plan left no implementation choice open.
- 2026-09-28: T1 done. The AC1 and AC2 tests failed 81 times before the fix. In a scratch copy, removing `rlm_check_port(port)` or the `cors` flag check turned only its own test red. `devtools::test()` clean.
- 2026-09-28: T2 done. Six AC3 cases failed before the fix, and the no-output case passed, as it must. The `processx::run()` call is unchanged, so the token-wrapper mocks needed no edit. `devtools::test()` clean.
- 2026-09-28: T3 done. The `warn_unless_ready()` comment now says each input of the target is checked before the probe, since `server_status_port()` already drops a port outside 1 to 65535. `devtools::document()` and `devtools::test()` clean.

## Decisions

## Review
