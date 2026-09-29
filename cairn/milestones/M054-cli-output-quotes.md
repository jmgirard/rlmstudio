# M054: A failed CLI or installer run quotes what it wrote

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP5, GP6
- **Resolves:** —
- **Surface tier:** user-facing — the abort messages and one stop exit of five exported functions
- **Branch/PR:** m054-cli-output-quotes

## Goal

If the LM Studio CLI or the headless installer fails, the abort gives the
exit code and quotes what the run wrote.

## Scope

**In:** `lms_server_stop()`, `lms_daemon_start()`, and `lms_daemon_stop()`
quote the CLI text as `lms_server_start()` does since M053. The shared
helper `cli_output_text()` (`R/serve.R:182`) also removes ANSI escape
sequences and cuts a long text to its end. `lms_server_stop()` treats a
server that is not running as done, as `lms_daemon_stop()` does for the
daemon. `install_lmstudio(method = "headless")` shows the installer output.
Its outer handler (`R/setup.R:211-217`) drops that output today. Help pages
and NEWS.

**Out:** `lms_server_status()` and `lms_daemon_status()` return the CLI
output and never abort, so they stay as they are. `check_lms_version()`
shows an unparsed version in a message, not in an abort. It stays as it is.
The other CLI and messaging rows stay candidates in the ROADMAP.

## Acceptance criteria

- [ ] AC1: The grep `grep -n 'processx::run(lms_path()' R/*.R` lists six
      call sites. Two of them return the output and never abort:
      `lms_server_status()` and `lms_daemon_status()`. The other four are
      in `lms_server_start()`, `lms_server_stop()`, `lms_daemon_start()`,
      and `lms_daemon_stop()`. On a non-zero exit, each of the four aborts,
      except for the stop exits of AC3. The abort gives the exit code. If
      stderr or stdout holds a character other than whitespace, the abort
      also gives one bullet `The CLI said: <text>`. `<text>` is the stderr
      text. If stderr holds only whitespace, `<text>` is the stdout text. A
      test runs each of the four over stderr text, stdout text alone, both,
      and no text. It compares after it collapses each whitespace run. It
      asserts the exit code and which text is quoted. For no text, it
      asserts that no "The CLI said" bullet shows.
- [ ] AC2: The quoted text of each of the four is cleaned in this order. A
      byte that is not valid UTF-8 shows as `<xx>`, its hex value. ANSI
      escape sequences are removed: color codes, other cursor codes, and
      terminal links. Each whitespace run becomes one space, and a
      non-breaking space counts as whitespace. Last, a text of more than
      1000 characters, as `nchar()` counts them, keeps its last 1000 after
      a leading "…". The "…" is not counted. If the cut splits a `<xx>`
      token, the part of the token is dropped, so fewer than 1000 remain. Braces in the text show as written and do not run. A test runs
      each of the four over one text per rule. One text holds byte 0xff.
      Three texts each hold one of the three escape forms. One text has
      several lines, tabs, and a non-breaking space. One text is
      `brace_probe`. The cut has three texts: 1500 characters, exactly 1000
      characters that are not cut, and a cut that falls inside a `<xx>`
      token.
- [ ] AC3: If the CLI text holds "not running" in any letter case,
      `lms_server_stop()` prints an info message and returns the CLI exit
      code invisibly, with no abort. On 2026-09-29, `lms server stop` with
      no server running exited 1 with the stderr text "Error: The server is
      not running.", and the test uses that text. `lms_daemon_stop(force =
      TRUE)` with no server running now shows this info message too, and a
      test asserts it. `lms_daemon_stop()` keeps its two
      exits. If the text holds "part of LM Studio" in any letter case, it
      returns `FALSE` with the GUI message. A text that holds "not running"
      and not the GUI phrase returns `TRUE` with the already-stopped
      message.
      In both functions, the phrases are matched in the text that AC1
      selects, after cleaning and before the cut. If the text also has a byte that is not valid
      UTF-8, each exit still holds. Today that byte makes
      `lms_daemon_stop()` fail with the base R error "input string 1 is
      invalid UTF-8". The abort of `lms_daemon_stop()` keeps its hint about
      `force = TRUE`. Tests cover each of the three exits with plain text
      and with invalid UTF-8 text. Tests also cover a phrase that sits more
      than 1000 characters before the end, a text with both phrases, and
      the hint.
- [ ] AC4: If the headless installer exits with a status other than 0,
      `install_lmstudio()` aborts. The error message holds the exit code
      and one bullet `The installer said: <text>`. The installer runs with
      stderr sent to stdout, so `<text>` is the stdout text, cleaned by the
      rules of AC2. The message holds "Headless installation failed" once
      and no "Error message:" bullet. Braces in the installer output show
      as written and do not run. Every other error inside the install
      `tryCatch()` keeps the wrapped message of today: "Headless
      installation failed." with an "Error message:" bullet. Tests assert
      that message for a missing `curl`, an unsupported system, and a shell
      that fails to start.
- [ ] AC5: The help pages of `lms_server_start()`, `lms_server_stop()`,
      `lms_daemon_start()`, `lms_daemon_stop()`, and `install_lmstudio()`
      state what the message of a failed run quotes. The
      `lms_server_stop()` page states the not-running exit. NEWS.md has one
      entry for the change. A test of AC1 to AC4 asserts each behavior that
      these texts state.
- [ ] AC6: `devtools::document()` leaves no diff. `devtools::test()` is
      clean, and `devtools::check()` gives 0 errors, 0 warnings, and 0
      notes.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T1, T2, T3
- AC3 → T2, T3
- AC4 → T4
- AC5 → T5
- AC6 → T6

## Tasks

- [x] T1: In `R/serve.R`, give `cli_output_text()` the AC2 order: the
      `<xx>` step, then `cli::ansi_strip()`, then the whitespace collapse,
      then the cut. Keep the cut a separate step, so a phrase match can
      read the cleaned text before the cut. Test every AC2 rule through
      `lms_server_start()` first, and see each new test red before the
      code changes.
- [x] T2: Route the failed runs of `lms_server_stop()` and
      `lms_daemon_start()` through the helper with `The CLI said:`. Add the
      not-running exit to `lms_server_stop()` through `rlm_alert_info()`.
      Add one table-driven test file that runs three functions over the
      AC1 and AC2 texts. T3 adds the `lms_daemon_stop()` rows. Add the AC3
      tests of the `lms_server_stop()` exit: plain text, invalid UTF-8
      text, and a phrase more than 1000 characters before the end. Mock
      `lms_path()` and `processx::run`, so no CLI runs (LESSONS, M003).
- [x] T3: Rewrite the failure branch of `lms_daemon_stop()` in
      `R/daemon.R` to use the helper. Match the two phrases in the cleaned
      text before the cut, "part of LM Studio" first. Change the label to
      `The CLI said:` and keep the hint. Update the brace test in
      `test-daemon.R` to the new label. Add the `lms_daemon_stop()` rows to
      the T2 test file. Add its AC3 tests, including the invalid UTF-8
      regression, which must fail before the fix, and the `force = TRUE`
      message.
- [x] T4: In `R/setup.R`, raise the non-zero-exit abort of
      `install_lmstudio()` so that its outer handler does not wrap it, with
      `The installer said:` and the helper. Rewrite the M028 test in
      `test-setup.R` to assert the message the user gets. Add the three
      tests of the wrapped message.
- [x] T5: Update the five help pages and add the NEWS.md entry. Write each
      stated behavior from a test run of T1 to T4. Run
      `devtools::document()`.
- [x] T6: Run `devtools::test()` and `devtools::check()`. Set
      `RLMSTUDIO_API_TOKEN` and start the server first (LESSONS, M009).

## Work log

- 2026-09-29: created by /milestone-plan.
- 2026-09-29: criteria audit, full mode, one [O] reader. It returned 10 findings. Nine were fixed in the wording, and one (a second `lms_server_stop()` call aborts) went to the gate.
- 2026-09-29: second audit pass, full mode, same [O] reader, on the gate-changed criteria. It returned 5 findings, all fixed in the wording: the cut of a `<xx>` token, a recorded stop text, the `force = TRUE` message, and two Coverage gaps.
- 2026-09-29: plan gate chose the `The CLI said:` one-line shape over the quoted `CLI output:` shape with line breaks. The helper and its tests exist. Falsified by a user report that a collapsed multi-line CLI message is hard to read.
- 2026-09-29: plan gate chose an info message for `lms_server_stop()` with no server over the abort. Stop calls are safe to repeat (GP5). Falsified by a CLI failure whose text holds "not running" while a server still runs.
- 2026-09-29: plan gate chose to keep the last 1000 characters over no cap or the first 1000. A log ends with its reason. Falsified by a failure whose reason sits more than 1000 characters before the end.
- 2026-09-29: plan gate chose to fold the installer bug in over a separate hotfix. It shares the helper. Falsified by a review finding that the installer fix needs a design choice the CLI functions do not share.
- 2026-09-29: plan chose to strip ANSI codes over leaving them. `lms` wrote none into a pipe on 2026-09-29, but `lms_daemon_status()` strips them and a forced-color setting passes them. Falsified by a CLI message whose meaning depends on an escape sequence.
- 2026-09-29: implement started. No question gate, because the plan left no open choice.
- 2026-09-29: T1 done. `cli_output_clean()` and `cli_output_cut()` split out of `cli_output_text()` in `R/serve.R`. New `test-cli-output.R` ran red on the escape and cut rules before the change. A cut with no token step turned the three token cases red. `devtools::test()`: 547 tests, 0 failed, 3 skipped.
- 2026-09-29: T2 done. New `rlm_abort_cli_run()` in `R/serve.R` builds the abort for server start, server stop, and daemon start. `lms_server_stop()` has the not-running exit. The code came before its tests, so the new tests ran against the T1 code: every case but "no text" went red. `devtools::test()`: 550 tests, 0 failed, 3 skipped.
- 2026-09-29: T3 done. `lms_daemon_stop()` matches its phrases in `cli_output_clean()` text and aborts through `rlm_abort_cli_run()` with its hint. Its new tests went red first, the invalid UTF-8 and no-text cases included. The `force = TRUE` test passed before T3, because T2 added the server exit. `devtools::test()`: 554 tests, 0 failed, 3 skipped.
- 2026-09-29: T4 done. The install `tryCatch()` now returns the run, and the exit-code check follows it through `rlm_abort_cli_run()` with "The installer said". The M028 test is rewritten. On the old code the two output tests went red, and the three wrapped-message tests passed, as they pin unchanged text. `devtools::test()`: 558 tests, 0 failed, 3 skipped.
- 2026-09-29: T5 done. Five help pages and one NEWS entry with two parts. Minor amendment: the pages of `lms_daemon_start()` and `lms_daemon_stop()` also get a corrected `@return`, and the GUI section of `lms_daemon_stop()` no longer says the call fails. The code returns 0, or `TRUE` and `FALSE`, and tests assert both. A second `document()` wrote nothing, and `devtools::test()` gave 558 tests, 0 failed.
- 2026-09-29: T6 done. With the server started and the token set, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.

## Decisions

## Review
