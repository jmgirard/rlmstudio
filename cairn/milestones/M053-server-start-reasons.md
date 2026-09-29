# M053: The server start call says why a start was refused

- **Status:** review
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

- [x] AC1: `lms_server_start()` aborts for each rejected `port` value below. The abort carries no `rlmstudio_` condition class, and `processx::run()` is not called. Nine values are not one plain number: `"8080"`, `"abc"`, `TRUE`, `NA`, `list(8080)`, `factor("8080")`, `c(8080, 8081)`, `numeric(0)`, and `matrix(8080)`. Five are missing or not finite: `NA_real_`, `NA_integer_`, `NaN`, `Inf`, and `-Inf`. Seven are out of range or not whole: `-1`, `0`, `0L`, `8080.5`, `65536`, `99999`, and `1e10`. The message names `port` and the rule "one whole number from 1 to 65535". The accepted values `1`, `65535`, `8080L`, `8080`, and `c(p = 8080)` reach `processx::run()` after `"--port"`. They arrive as `"1"`, `"65535"`, `"8080"`, `"8080"`, and `"8080"`. `port = NULL` sends no `"--port"`. A test in `tests/testthat/test-serve.R` verifies this with a counting `processx::run()` mock. It drives each rejected value once with `wait = 0` and once with `host = "http://localhost:1234"`.
- [x] AC2: `lms_server_start()` aborts for each rejected `cors` value: `"yes"`, `1`, `NA`, `NULL`, `logical(0)`, and `c(TRUE, FALSE)`. The abort carries no `rlmstudio_` condition class, `processx::run()` is not called, and the message names `cors`. `cors = TRUE`, `cors = c(x = TRUE)`, and `cors = matrix(TRUE)` send `"--cors"`. `cors = FALSE` sends no `"--cors"`. A test in `tests/testthat/test-serve.R` verifies this with a counting `processx::run()` mock. It drives each rejected value once with `wait = 0` and once with `host = "http://localhost:1234"`.
- [x] AC3: If the CLI exits with a non-zero status, the abort message of `lms_server_start()` holds the exit code and the CLI output. The CLI output is the stderr text. If stderr is absent, `NULL`, or `NA`, or holds only whitespace, it is the stdout text. After `trimws()` and after each whitespace run is collapsed to one space on both sides, the message holds that text. If both outputs are absent, `NULL`, or `NA`, or hold only whitespace, the message holds the exit code and no CLI-output line. A test with a mocked `processx::run()` verifies seven cases. It compares texts after `gsub("\\s+", " ", trimws(x))` on both sides. The first case is the stderr text `error: option '-p, --port <port>' argument 'abc' is invalid. Not a number`, recorded from the CLI on 2026-09-28. The second is a text on stdout alone. The third is a stderr text that holds `{port}`, and its braces reach the message. The fourth is a stderr of two lines and more than 80 characters. The fifth is a status of 1 with no output fields. The sixth has text on both stderr and stdout, and only the stderr text reaches the message. The seventh has a stderr of only whitespace and a stdout text, and the stdout text reaches the message.
- [x] AC4: The help page `man/lms_server_start.Rd`, read after `devtools::document()`, states four things. `port` must be `NULL` or one whole number from 1 to 65535, given as a number and not as an array. `cors` must be `TRUE` or `FALSE`. The sentence that counts the faults that abort before the CLI runs names `port` and `cors` among them. The abort of a failed start quotes the CLI output. In `R/serve.R`, `lms_server_start()` checks `port` and `cors` outside any branch on `wait`, `host`, or `token`. The comment above the `tryCatch()` in `warn_unless_ready()` no longer says that the CLI checks a malformed port.
- [x] AC5: `NEWS.md` has one entry under the development version for these changes. The entry says that `port = "8080"` and `cors = NULL` now abort, and that a failed start quotes the CLI output. The entry states no behavior beyond what AC1 to AC3 state.
- [x] AC6: `devtools::test()` reports no failures, and `devtools::check()` reports 0 errors and 0 warnings.

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
- [x] T4: Run `devtools::test()`. Run `devtools::check()` with `RLMSTUDIO_API_TOKEN` set and the server started, because the vignettes make live calls (LESSONS, M009).

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
- 2026-09-28: T4 done. With the server started and `RLMSTUDIO_API_TOKEN` set, `devtools::test()` had no failures and no skips, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-28: claim audit: 46 claims read, 6 corrected — R/serve.R, R/utils-args.R, NEWS.md, man/lms_server_start.Rd, tests/testthat/test-serve.R
- 2026-09-28: the claim audit found that `cli_output_text()` trimmed before it collapsed, so a stderr of only a form feed skipped the stdout fallback. The code now collapses first, and a test covers `"\f"` and `"\v\n"`. The other five fixes were wording: the `port` integer-step comment, the `rlm_check_port()` roxygen, the NEWS `port` and `cors` bullets, and how the quoted CLI text is reshaped. The same reader re-read all six once and found them true.
- 2026-09-28: after the fixes, `devtools::test()` had no failures and no skips, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. Status set to review.

## Decisions

## Review

Evidence gathered 2026-09-28 on head 2672b2b. The branch had 0 commits behind `origin/main`, so no merge was needed.

- AC1: `test-serve.R` "a port that is not one whole number…" ran 148 expectations, 0 failed. That count is the length check, plus 21 rejected values × 2 runs × 3 assertions, plus one zero-call count per value. The two runs use `wait = 0` and a `host`. The three assertions are no `rlmstudio_` class, the name `port`, and the rule text. "an accepted port reaches the CLI…" ran 22, 0 failed, covering the five sent strings and `port = NULL`. With `rlm_check_port()` replaced in memory by a no-op, the rejection test failed 63 expectations.
- AC2: "a cors that is not TRUE or FALSE aborts first" ran 30 expectations, 0 failed. That is 6 rejected values × 2 runs × 2 assertions (no `rlmstudio_` class, the name `cors`), plus one zero-call count per value. "cors = TRUE sends --cors…" ran 8, 0 failed, for `TRUE`, `c(x = TRUE)`, `matrix(TRUE)`, and `FALSE`. With the `cors` flag check replaced in memory by a no-op, the rejection test failed 18 expectations.
- AC3: the seven failed-start tests in `test-serve.R` ran 33 expectations, 0 failed. They cover the recorded `abc` stderr, stdout alone, braces, a two-line stderr over 80 characters, and no output in five shapes. The shapes are absent fields, `NULL`, `NA`, whitespace, and `"\f"` with `"\v\n"`. The last two tests cover stderr over stdout and a whitespace stderr over stdout. With `cli_output_text()` replaced in memory by one that returns `NULL`, six of the seven tests failed, and the no-output test passed, as it must. With a version that reads stdout alone, the recorded-stderr and stderr-over-stdout tests failed.
- AC4: `devtools::document()` left no diff. `man/lms_server_start.Rd` says that `port` is "one whole number from 1 to 65535, given as a number and not as an array or a string". It says that `cors` "Must be `TRUE` or `FALSE`". The fault sentence reads "Five faults … a bad `wait`, `port`, `cors`, `host`, or `token`". A paragraph says that a failed start quotes the CLI text. In `R/serve.R`, `rlm_check_port(port)` and `rlm_check_flag(cors, "cors")` are the second and third lines of `lms_server_start()`, before any branch. The `warn_unless_ready()` comment above the `tryCatch()` now says that each input is checked before the probe. A grep for "malformed port" and "left to the CLI" in `R/serve.R` found nothing.
- AC5: `NEWS.md` has one top-level `lms_server_start()` bullet under the development heading, with three sub-bullets. It says that `port = "8080"` and `cors = NULL` now abort, and that a failed start quotes the CLI output. Each statement of what the function now does maps to AC1, AC2, or AC3. The entry also has two "Before" sentences about the old code: a string or one-cell matrix port reached the CLI as `"8080"`, and `cors` values other than `TRUE` acted as `FALSE`. Both match `build_args_server_start()` on `origin/main`, which used `as.character(port)` and `isTRUE(cors)`. This review reads "behavior" in AC5 as what the function does after the change, so the "Before" sentences do not count against it. That reading goes to the maintainer at the gate.
- AC6: with the LM Studio server started and `RLMSTUDIO_API_TOKEN` set, `devtools::test()` ran 538 tests and 14164 expectations. It had 0 failures, 0 errors, 0 skips, and 0 warnings. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. The vignette build stopped the server again, which matches an existing candidate row.

Consistency gate: `cairn_validate.py` passed, exit 0, coverage complete included. `DESIGN.md` is not in the diff, so no principle changed and `cairn_impact.py` was skipped. `devtools::document()` left no diff. The diff does not touch `README.Rmd` or `README.md`. `pkgdown::check_pkgdown()` found no problems. `NEWS.md` has the entry, with no milestone numbers. The diff adds no top-level files. `devtools::check()` is clean, as AC6 records.
