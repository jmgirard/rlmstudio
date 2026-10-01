# M072: The headless vignette covers what differs without the desktop app

- **Status:** review
- **Priority:** normal
- **Depends on:** M070
- **Driving RR:** —
- **Principles touched:** IP1, IP2
- **Resolves:** —
- **Surface tier:** user-facing — a vignette that package users read
- **Branch/PR:** m072-headless-vignette-rewrite

## Goal

A user on a machine without the LM Studio desktop app, or with LM Studio on
another machine, can follow `headless-config` to a working server.

## Scope

**In:** A rewrite of `vignettes/headless-config.Rmd.orig`, knitted by the
M070 script. It covers only what differs from `getting-started`: installing
the command line tool with `install_lmstudio(method = "headless")`, shown and
not run, which asks before it installs (IP2). It also covers the daemon
(`lms_daemon_start()`, `lms_daemon_status()`, `lms_daemon_stop()`), the
server on a slow host, and a script wrapped in `with_lms_daemon()`. A new
section covers a server that requires an API token (`RLMSTUDIO_API_TOKEN`
and the `token` argument) and a server on another machine (the `host`
argument). Remote-host code is shown and not run. The text says that text
then goes to that machine (IP1). The download, load, and chat steps link to
`getting-started` and are not repeated. The code and prose follow the
vignette rules in DESIGN.md Conventions (M070). A NEWS entry.

**Out:** A headless llmster run of the knit stays in the candidate row on
`lms daemon up`. Batch work is M073, and chat options are M074.

## Acceptance criteria

- [x] AC1: The R code that `knitr::purl()` extracts from
      `vignettes/headless-config.Rmd.orig` holds each of these strings:
      `install_lmstudio(method = "headless")`, `lms_daemon_start(`,
      `lms_daemon_status(`, `lms_daemon_stop(`, `lms_server_start(`,
      `with_lms_daemon(`, `RLMSTUDIO_API_TOKEN`, `token =`, and `host =`. It
      holds neither `lms_download(` nor `list_models(`. In the knitted
      `vignettes/headless-config.Rmd`, no line starts with ```` ```{r ````
      or with `#> Error`. The block of the chunk that calls
      `lms_daemon_status(` holds a line that starts with `#>` after its last
      code line.
- [x] AC2: A search of that purled code for each regular expression in the
      DESIGN.md code list finds no match. A search of the source for
      `` `r `` finds no inline R expression.
- [x] AC3: A case-blind search for each entry of the DESIGN.md prose list
      finds no match. It runs over every line of the source outside
      its ```` ```{r} ```` chunks, with the YAML header and inline code.
- [x] AC4: Each of these terms is explained in plain words at or before
      its first use in prose or in a code comment of the knitted vignette:
      headless, daemon, host, and API token.
- [x] AC5: The prose next to the `host =` chunk states that the input text
      goes to that machine. The prose next to `install_lmstudio()` states
      that it asks before it installs, unless `RLMSTUDIO_ALLOW_INSTALL` is
      set.
- [x] AC6: Take each prose sentence and each `#` comment line that states
      what a package function does with an argument, returns, or raises,
      beyond what its name says. A named test under `tests/testthat/`
      exercises that behavior. A sentence about what LM Studio itself does
      matches what a live call on this machine returned.
- [x] AC7: `NEWS.md` has an entry under the development-version heading
      that names the rewritten vignette. `devtools::document()` gives no
      diff, `devtools::test()` passes, and `pkgdown::check_pkgdown()`
      passes. With the server stopped and `RLMSTUDIO_API_TOKEN` unset,
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2, T3
- AC2 → T2
- AC3 → T2, T4
- AC4 → T2, T4
- AC5 → T1, T2
- AC6 → T1, T5
- AC7 → T6

## Tasks

- [x] T1: Probe `lms_daemon_status()` and `with_lms_daemon()` on this
      machine, where the desktop app runs the daemon, and log what each
      returns. Read `?rlmstudio_token` and `?install_lmstudio` for the
      token and consent rules that the prose states.
- [x] T2: Rewrite the source to the outline in Scope. Keep each code chunk
      short, with a comment that says what it does.
- [x] T3: Knit with `data-raw/knit-vignettes.R` from a clean start. Read
      the knitted file for error lines and for the output lines of AC1.
- [x] T4: Spawn a fresh reader with the persona of a researcher who knows
      R and runs a remote Linux server. It reads the knitted vignette and
      lists each step that it cannot follow and each term used before it is
      explained. Fix each item, or log why not, and re-knit.
- [x] T5: List the claims of AC6 with the test or probe that backs each, as
      a ledger in the work log. Add tests to
      `tests/testthat/test-vignette-claims.R` where none covers a claim.
      Narrow the `lms daemon up` candidate row: the vignette no longer
      stops a daemon during a package check.
- [x] T6: Add the NEWS entry and run the checks of AC7.

## Work log

- 2026-09-30: created by /milestone-plan.
- 2026-09-30: M070 claim audit handed two findings on the carried-over headless prose to this rewrite. First, the comments "Stop the background daemon" and "the daemon will stop on exit" sit above knitted output that says the GUI keeps the daemon running, because the knit runs on a desktop host. Second, the knitted `str_extract()` chat reply is a wrong pattern that the prose does not flag.
- 2026-09-30: M070 review handed two findings to this rewrite. F7: the knitted model list shows every model on the author's machine. F8: the knit ran with the model on disk, so the download chunk shows "already downloaded" and no download job, next to prose about a download.
- 2026-09-30: T1 probes on macOS with the desktop app, LM Studio 0.4.25+1. `lms_daemon_status()` runs `lms status` and returned the server lines ("Server:  OFF"). `lms_daemon_start()` returned 0. `lms_daemon_stop()` and the teardown of `with_lms_daemon()` returned `FALSE` with "managed by the LM Studio GUI". `lms server start` binds 127.0.0.1 by default. With `LMS_SERVER_HOST=0.0.0.0` set in R before `lms_server_start()`, it listened on all addresses. Then `lms_server_ready()` at the LAN address gave TRUE with the token and FALSE without it. The default start gave FALSE at the LAN address. `lms` has no command that creates an API token. Read `?rlmstudio_token` and the `install_lmstudio()` source.
- 2026-09-30: T2 and T3 rewrote `headless-config.Rmd.orig` and knitted it from a clean start. With a model loaded and the server off, `lms status` printed only the server lines, so the prose claims the server state alone. A scratch check of AC1 to AC3 passed, and planted `lapply(`, `invisible(`, `simply`, and `seamless` lines each turned it red.
- 2026-09-30: T4 fresh Opus reader with the remote Linux persona listed 13 steps, 6 terms, and 5 mismatches. Fixed: `rlmstudio::` before the first call, how to set an environment variable, the `lms` version check, `RLMSTUDIO_LMS_PATH` for a missing `lms`, skipping the browser install of `getting-started`, `.Renviron`, port, `0.0.0.0`, the two meanings of server, the `lms server start` hint in the status output, the two causes of a `FALSE` ready, the token example, `with_lms_daemon()` on a running daemon, the host-side functions, and the firewall.
- 2026-09-30: T4 not fixed. The finished-download status is in the M071 candidate row. LM Studio documents token setup in the desktop app only, so the vignette links that page. The reader asked whether `LMS_SERVER_HOST` must be set before the daemon starts, and the T1 probe set it after. Whether the daemon survives a closed SSH session and what a stop without `force` does with the server on need a headless host, as the `lms daemon up` row states. Installing the package itself is in the README. The gate chose `LMS_SERVER_HOST` over an SSH tunnel.
- 2026-09-30: T5 ledger, install section. Install script: `install_lmstudio() with the headless method runs the LM Studio install script`. Console question, yes only: `... at the console asks first and installs only on yes`. Script stop and `"true"`: `... in a script stops unless RLMSTUDIO_ALLOW_INSTALL is true`. Nothing for `lms` 0.4.0 or later: `... installs nothing when lms 0.4.0 or later is found`. `has_lms()`, `RLMSTUDIO_LMS_PATH`: `test-setup.R`. `check_lms_version()`: the version test of `test-vignette-claims.R`.
- 2026-09-30: T5 ledger, daemon and server. `llmster`: `lms daemon --help`. The desktop app runs the daemon, and a stop then gives `FALSE` and a message: T1 probe and `lms_daemon_stop exits gracefully when managed by GUI`. Status lines of `lms status`: `lms_daemon_status() returns the lines that lms status prints` and the T2 probe. `lms_server_start()` runs `lms server start`: `build_args_server_start constructs correct arguments`. Wait and warning: `lms_server_start warns rather than aborts when the wait runs out`. Ready TRUE only on an answer, FALSE on a 401: `test-server-ready.R`.
- 2026-09-30: T5 ledger, token and host. Token sent from the variable, the argument on every request function, the argument winning, the two messages: `test-token.R`, `test-token-wrappers.R`, `test-token-rejected.R`. Desktop-only token setup: the authentication page, read 2026-09-30. Default `localhost:1234`: `list_models() asks localhost:1234 by default`. `host` on load, chat, unload: `lms_load(), lms_chat(), and lms_unload() take a host argument`. Prompt to the host: `a host argument sends the prompt to that computer`. Default bind and `0.0.0.0`: T1 probe.
- 2026-09-30: T5 ledger, script and stop. `with_lms_daemon()` starts, runs, stops server and daemon, returns the value, also on error and on a running daemon: the two `with_lms_daemon()` tests of `test-vignette-claims.R`. `lms_daemon_stop()` TRUE when stopped or not running, `force = TRUE` stops the server first: the two `lms_daemon_stop()` tests there. A plant that skipped the console question with the variable set, and a plant that skipped the teardown on error, each failed one new test. The `lms daemon up` row is narrowed and the vignette lesson corrected. `devtools::test()`: 0 failures, 0 errors, 3 skips.
- 2026-09-30: T6 NEWS entry added. The first `devtools::check()` failed 10 expectations of the consent tests. In the byte-compiled package, the base `interactive()` call is inlined, so the base mock never reached it. `R/setup.R` gained a package binding `interactive <- NULL` that the tests mock. With the server stopped and the token unset, `devtools::document()` gave no diff, `pkgdown::check_pkgdown()` found no problems, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and `devtools::test()` gave 0 failures, 0 errors, 3 skips.
- 2026-09-30: claim audit: 62 claims read, 4 corrected — vignettes/headless-config.Rmd.orig, vignettes/headless-config.Rmd, tests/testthat/test-vignette-claims.R. Two vignette lines said that the desktop app runs the daemon, against the `isDaemon` false probe. Two test comments were wrong. The list of causes of a `FALSE` ready gained a held port. The same reader re-read the 5 spots once and found 0 wrong. Re-knitted, and the AC1 to AC3 check and the claim tests passed.
- 2026-09-30: review gate: the user chose the proposed split. Ten findings fixed on the branch, one moved to the `lms daemon up` row at hygiene, two rejected, two noted. Re-knitted, and check, test, document, and pkgdown are clean.
- 2026-09-30: review moved one line break in AC3, with the words unchanged. The line started with a four-backtick code span. `cairn_validate.py` read it as a code fence and counted the Review section as plan lines (156, cap 150).
- 2026-09-30: step-7 approval: m072-headless-vignette-rewrite approved for merge. The user also chose to move the `lms daemon up` row to DESIGN.md Known issues at hygiene.

## Decisions

- 2026-09-30 (question gate): `lms_daemon_start()` and `lms_daemon_status()` run in the knit. `lms_daemon_stop()` and the `with_lms_daemon()` script are shown and not run. On the desktop host of the knit, the stop returns `FALSE` with a GUI message. A headless reader never sees that message. The prose states the headless result, backed by package tests.
- 2026-09-30 (question gate): the remote section sets `LMS_SERVER_HOST` to `0.0.0.0` on the server machine before `lms_server_start()`. The other machine passes `host =`. `lms_server_start()` has no bind argument.

## Review

Evidence gathered 2026-09-30 on the branch head 2245d56, which holds `origin/main`. The AC1 to AC3 checks ran from a scratch script outside the repo.

- AC1: `knitr::purl()` of the source gave 70 code lines. All 9 strings are present, and neither `lms_download(` nor `list_models(` is. The knitted file has 0 lines that start with ```` ```{r ```` and 0 that start with `#> Error`. The chunk that calls `lms_daemon_status(` (knitted lines 88 to 94) has three `#>` lines after its code line.
- AC2: the 16 DESIGN.md regular expressions over the 70 purled lines gave 0 matches. The source has 0 inline `` `r `` expressions. A planted `lapply(` chunk turned the check red.
- AC3: the 14 DESIGN.md entries, case-blind, over 168 source lines outside the chunks (YAML and inline code kept) gave 0 matches. A planted line with `simply` and `seamless` turned the check red.
- AC4: a read of the knitted file. "Headless" and "API token" are each explained in the sentence of their first use (lines 12 and 118). "Host" is explained in the sentence of its first use (line 177). "Daemon" is explained in the first sentence of running text that uses it (line 69). The heading "Start the daemon" (line 67) sits two lines above the daemon sentence. This review reads a heading as a title, not as prose.
- AC5: next to the `host =` chunk, line 207 says that the package sends your prompts to that computer. Next to `install_lmstudio()`, lines 32 to 36 say that it asks first at the console and installs only on yes. They also say that in a script it stops unless `RLMSTUDIO_ALLOW_INSTALL` is `"true"`. `R/setup.R` lines 152 to 169 do the same.
- AC6: the T5 ledger in the work log names a test or probe for each claim. The 11 named tests exist under `tests/testthat/`, and the suite passed (AC7). Live probes today, LM Studio 0.4.25+1 on macOS with the desktop app: `lms status` with the server off printed "Server:  OFF" and the `lms server start` hint, as knitted. A default `lms server start` listened on 127.0.0.1:1234. `LMS_SERVER_HOST=0.0.0.0` set in R before `lms_server_start()` gave a listener on `*:1234`. `lms daemon status --json` gave the desktop app's process with `isDaemon` false. Without the token, `lms_server_ready()` gave `FALSE` and `lms_server_start()` warned that the wait ran out, one of the causes the vignette lists.
- AC7: `NEWS.md` line 3, under the development-version heading, names `vignette("headless-config")`. `devtools::document()` gave no diff. `devtools::test()` gave 0 failures, 0 errors, and 3 skips. `pkgdown::check_pkgdown()` found no problems. With the server stopped and `RLMSTUDIO_API_TOKEN` unset, `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.

Consistency gate: `cairn_validate.py` passed every check. No DESIGN.md principle changed, so the impact report did not run. The toolchain checks are the AC7 results above. README.Rmd is not on the branch diff, and the branch adds no top-level file.

Independent review: one Opus diff reviewer (14 findings), one Sonnet history reviewer (6), and one Sonnet prior-review reviewer (2, and the PR-comment probe found none). The list below merges the duplicates into 15 items. The user chose the proposed split at the gate.

- 1 (diff 1, prior 1). DESIGN.md said that sources have no `eval` gates, against 5 `eval = FALSE` chunks that the plan called for. Fixed now: DESIGN.md allows a chunk that must not run in the knit.
- 2 (diff 2). The advice to require a token on an exposed server cannot be followed on a host without the desktop app. Fixed now: the vignette says that the documentation shows the token check only in the desktop app, read again today, and advises a private network.
- 3 (diff 3, history 1 and 2). The vignette offered the stop of a daemon that ran before the call as a benefit. Fixed now: a caution about a shared computer and the desktop app.
- 4 (diff 4, history 4). Headless-only claims have only macOS probes. Follow-up: the `lms daemon up` candidate row, at the hygiene pass.
- 5 (diff 5). No test showed that an older `lms` goes on to install. Fixed now: a new test. A plant that dropped the version check turned it red.
- 6 (diff 6). The host loop had no nested `test_that()` per pass. Fixed now.
- 7 (diff 7). The token example claimed the same result as without the argument. With the `rlmstudio.token` option set, that claim is false. Fixed now: the sentence is narrowed.
- 8 (diff 8). "Port" came before its explanation. Fixed now: the explanation moved to its first use.
- 9 (diff 9). The start warning on a server that needs a token was not explained. Fixed now: the cause paragraph also covers the warning.
- 10 (diff 10). "In a script, R cannot ask you" was not exact. Fixed now: it names a script with no console, such as `Rscript`, and the chunk comment says "At the console".
- 11 (diff 11). The AC5 wording does not match the code at the console. Rejected: the prose states both cases as the code does and meets AC5 as written.
- 12 (diff 12, history 3, prior 2). The "it" in the stop sentence was unclear. Fixed now. The sentence that the app does the work of the daemon stays: today's daemon status gave the app's process.
- 13 (diff 13). The vignette does not say that a stop without `force` can fail with the server on. Rejected: that LM Studio behavior is not verified.
- 14 (diff 14, history 5). The `interactive <- NULL` binding. Noted: check gave 0 notes.
- 15 (history 6). The corrected LESSONS line holds only while the knit never stops the daemon. Noted.

After the fixes, the knit from a clean start changed prose only. The AC1 to AC3 checks passed again. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and `devtools::test()` gave 0 failures, 0 errors, and 3 skips. `devtools::document()` gave no diff, and `pkgdown::check_pkgdown()` found no problems.
