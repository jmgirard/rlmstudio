# M028: Brace tests for the six cli sites that show server or CLI text

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — the deliverable is tests, and no code under `R/` changes
- **Branch/PR:** m028-brace-probe-tests

## Goal

Six cli call sites show server or CLI text and have no brace test. If braces in that text run as R code, a new test for that site fails.

## Scope

**In:** One test for each site in the list below. Each test plants `{cat("EVALUATED")}` in the text from the server or the CLI. The six sites come from the 2026-09-27 plan sweep. The sweep ran `grep -n 'cli::\|rlm_alert\|rlm_inform\|rlm_progress' R/*.R`. Then it read each call site that the grep returned for text from a server reply or from CLI output. Eight sites show such text. All eight splice the text in as a value, so no site runs braces today. Two sites already have a brace test: the `rlm_abort_api()` message (`test-api-error.R`) and the status in `print.lms_download_status()` (M027). The other six sites are:

1. `print.lms_chat_result()`: the reply text, at `R/chat_oop.R:66`.
2. `print.lms_download_status()`: the server's `job_id` in the heading, at `R/download.R:250`.
3. `lms_download()`: the server's `job_id` in the success alert, at `R/download.R:88-90`.
4. `lms_daemon_stop()`: the CLI's stderr or stdout in the abort, at `R/daemon.R:139-143`.
5. `check_lms_version()`: the CLI's `--version` output that holds no version number, at `R/setup.R:69-72`.
6. `install_lmstudio(method = "headless")`: the installer's stdout in the abort, at `R/setup.R:201-204`. The outer handler at `R/setup.R:213-216` shows that abort's message a second time.

**Out:** Sites that show text the user passed, such as `model` or `host`. The candidate row names text from a server, the CLI, or a file, and a user controls their own arguments. No row is kept. A grep test over `R/` that flags a format string built with `paste()` is also out. The plan gate rejected it, and no row is kept. The sweep found no site that reads text from a file.

## Acceptance criteria

- [x] AC1: For each of the six sites listed in Scope, `devtools::test()` runs a test that gives that site server or CLI text holding `{cat("EVALUATED")}`. The test asserts that the printed output or the condition message holds the braces as written. It also asserts that "EVALUATED" was not printed.
- [x] AC2: `devtools::test()` passes with no failures, and `git diff --stat main -- R/` prints nothing.

## Coverage

- AC1 → T1, T2, T3, T4
- AC2 → T5

## Tasks

- [x] T1: Add the two print tests to `tests/testthat/test-chat.R` and `tests/testthat/test-download.R`. Build a `lms_chat_result` object whose `text` holds the probe, and a `lms_download_status` object whose `job_id` holds it. Capture the output with `capture.output()` or `expect_snapshot()`, and use the M027 status test as the model.
- [x] T2: Add the `lms_download()` test in `tests/testthat/test-download.R`. Serve a status-200 reply through the mock transport (`helper-mock-http.R`) with a `job_id` that holds the probe, and a `status` other than `"already_downloaded"`.
- [x] T3: Add the `lms_daemon_stop()` and `check_lms_version()` tests. Stub `processx::run` with `local_mocked_bindings(.package = "processx")`, as `test-daemon.R` and `test-serve.R` do. The daemon stub returns a non-zero status and a stderr that holds the probe and neither "part of LM Studio" nor "not running". The version stub returns output that holds the probe and no version number. Stub `lms_path()` so that no real CLI is needed.
- [x] T4: Add the `install_lmstudio(method = "headless")` test. Set `RLMSTUDIO_ALLOW_INSTALL=TRUE` with `withr::local_envvar()`. Stub `Sys.which` so that `curl` is found. Stub `processx::run` to return a non-zero status and a stdout that holds the probe. The stub must count its calls. If the stub was not called exactly once, the test fails. That way an install never runs for real. The outer abort keeps only the first line of the inner abort, so a wrapper around `cli::cli_abort` records each abort message. Assert on the inner abort's message, and assert that the outer abort is the condition the user sees.
- [x] T5: For each of the six tests, edit a scratch copy of its site. Put the server or CLI text into the format string itself. Examples are `cli::cli_text(x$text)`, or `paste0()` into the bullet. Make sure that the test goes red, then restore the site. Record one work-log line with the six red results. Run `devtools::test()` and `git diff --stat main -- R/`.

## Work log

- 2026-09-27: created by /milestone-plan. Promotes the [high] candidate row about cli format strings (added 2026-09-22, M027 T3). The sweep found no unsafe site, so the row's fix is already in the code, and this milestone adds the tests that keep it there.
- 2026-09-27: reduced criteria audit (internal tier) by a fresh reader. It returned three findings. (1) The site list missed `lms_download()`'s `job_id` alert at `R/download.R:88-90`. It is now site 3, and the title names six sites rather than "every" site. (2) A criterion that each test goes red under a planted defect bound a property of the verification, not of the tests. It moved to T5. (3) "`R/` is unchanged" now names `git diff --stat main -- R/`.
- 2026-09-27: plan gate chose one brace test per site over a grep of `R/` for `paste()` format strings, because such a grep skips under R CMD check (LESSONS, M005); falsified by a new unsafe site that the grep catches.
- 2026-09-27: plan gate chose a milestone over closing the row with no tests, because no test covers six of the eight sites; falsified by six tests that catch no new defect.
- 2026-09-27: the fresh reader re-ran the reduced audit on the revised Scope list, AC1, and AC2. It found nothing and confirmed the cited line ranges.
- 2026-09-27: implement started on branch m028-brace-probe-tests. No question gate, because the plan left no choice open.
- 2026-09-27: T1 done. New `helper-brace-probe.R` holds the probe and a capture helper. At `{.val}` sites cli shows the probe in quotes with its inner quotes escaped, so those tests match `encodeString(probe, quote = '"')`. The braces are shown as written in both forms.
- 2026-09-27: T2 and T3 done, and `devtools::test()` passes. T2, T3, and T4 share one commit, because T3 and T4 both edit `test-setup.R`.
- 2026-09-27: T4 done. The first run showed that the outer abort keeps only the first line of the inner abort, so the installer output never reaches the user. The test reads the inner abort through a wrapper around `cli::cli_abort`, and T4's wording now says so. The dropped output is a new candidate row for `/hotfix`, because this milestone does not change `R/`.
- 2026-09-27: T5 done. Each site was planted in turn with its text in the format string, through `cli::cli_text(x$text)` or `paste0()`. All six tests went red, each with 2 failed expectations. The sites are the chat reply, the status heading, the download alert, the daemon stop, the version check, and the installer abort. No other test in each file failed. `devtools::test()` then passed with 9123 expectations, and `git diff --stat main -- R/` printed nothing.
- 2026-09-27: claim audit: not owed — internal tier
- 2026-09-27: review started. The branch already held `origin/main`, so no merge was needed.

## Review

- AC1: the six brace tests ran on 2026-09-27 through `testthat::test_file()` on the four files, with 0 failed, 0 skipped, and 0 errors. Expectation counts: chat reply 3, status heading 3, download alert 4, daemon stop 3, version check 4, installer abort 7. Each test plants `brace_probe` and matches the braces as written in the messages or the abort message. Each test also runs `expect_no_match(shown$stdout, "EVALUATED")`. T5 recorded each test red under a planted format-string site.
- AC2: `devtools::test()` ran on 2026-09-27 and exited 0 with no failure section in the summary reporter. `git diff --stat main -- R/` printed nothing.
- Gate: `cairn_validate.py` passed all checks. `devtools::document()` left no diff. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. The branch does not touch `README.Rmd`, and the repo has no `_pkgdown.yml`. No NEWS entry is owed, because the branch adds tests only. No top-level file is new.
