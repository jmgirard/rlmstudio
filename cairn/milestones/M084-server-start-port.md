<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M084: The server-start examples pass port 1234, and the no-port message names the last-used port

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP6   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — the README, the vignettes, the help pages, and two messages that users read   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m084-server-start-port   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A reader who copies a server start from the README, a vignette, or a help example starts the server on port 1234, where the package's other calls look.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** Absorbs the candidate row "No-port start outside getting-started" in full. `port = 1234` in each server-start line of `README.Rmd`, `chat-options`, `text-analysis`, and `headless-config`, and in each roxygen example that starts the server. The no-port success message of `lms_server_start()` (`R/serve.R:153`) names the last-used port, not "the default port". The `port` argument help says where the request functions look. The browser branch of `install_lmstudio()` (`R/setup.R:148`) says to open the app once. A live re-knit of the three vignettes. One NEWS bullet.

**Out:**
- A `port` default of 1234 in `lms_server_start()`: the user chose to keep the default at the plan gate, 2026-10-18.
- `vignette("getting-started")`: M083 shipped its port fix.
- A stop right after a port switch: the `lms_server_status(json = TRUE)` candidate row.
- The `rlmstudio.quiet` bypass of the browser-branch warning: the new "install message quiet" candidate row.
- The headless-branch install message: llmster has no app to open, so it stays as it is.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: Each line of `README.Rmd` and `vignettes/*.Rmd.orig` that starts, after any spaces, with `lms_server_start(` passes `port = 1234`, as a test in `tests/testthat/test-vignette-claims.R` checks. `README.md` holds the line `## ✔ LM Studio server started successfully on port 1234.` under its server-start call.
- [ ] AC2: With no `port`, `lms_server_start()` reports "LM Studio server started successfully on the port that LM Studio used last.", and with `port = 1234` it reports "LM Studio server started successfully on port 1234.", as a test in `tests/testthat/test-serve.R` checks. `grep -rn "default port" R/ man/ README.Rmd README.md vignettes/` prints no line.
- [ ] AC3: In `man/lms_server_start.Rd`, the `port` argument text names the functions that send requests and `http://localhost:1234`. For each `man/*.Rd` file, `tools::Rd2ex(f, out, commentDontrun = FALSE)` writes its examples, and `grep -n '^ *lms_server_start(' out` prints only lines that pass `port = 1234`, except `lms_server_start(port = 8080, cors = TRUE)` from `man/lms_server_start.Rd`, whose comment above it holds `host = "http://localhost:8080"`.
- [ ] AC4: `install_lmstudio(method = "browser")` tells the user to open the LM Studio app once and then restart R, as an assertion on its message in the browser-method test of `tests/testthat/test-vignette-claims.R` checks.
- [ ] AC5: The knitted `vignettes/chat-options.Rmd`, `vignettes/text-analysis.Rmd`, and `vignettes/headless-config.Rmd` each hold the MD5 sum of their edited source, as `tests/testthat/test-vignette-knit.R` checks. The output of the server-start chunk in `chat-options.Rmd` and of the `start-server` chunk in `headless-config.Rmd` holds `✔ LM Studio server started successfully on port 1234.`
- [ ] AC6: The development section of `NEWS.md` says that the success message of `lms_server_start()` with no `port` names the port as the one LM Studio used last, that the help examples, the README, and the vignettes start the server with `port = 1234`, and that `install_lmstudio()` says to open the app once.
- [ ] AC7: `devtools::test()` and `devtools::check()` report no failures, errors, or warnings.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T4
- AC2 → T1, T2, T4, T5
- AC3 → T1, T2
- AC4 → T3
- AC5 → T5
- AC6 → T6
- AC7 → T7

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive change is amend-via-gate. -->

- [x] T1: Test first in `tests/testthat/test-serve.R`: the success message of a no-port start and of `port = 1234`, red against `R/serve.R:153`. Then change that message. Add to `@param port` (`R/serve.R:38-40`) that the request functions ask `http://localhost:1234` by default. Pass `port = 1234` in the four `lms_server_start()` examples (`R/serve.R:104-116`), and rewrite the first comment.
- [x] T2: Pass `port = 1234` in each other roxygen example line that starts with `lms_server_start(`. On 2026-10-18, `grep -n "^#' *lms_server_start(" R/*.R` gave `R/chat.R:2618`, `R/load.R:93`, `R/download.R:37`, `:193`, `:280`, `R/list.R:50`, `:236`, `R/serve.R:443`, `:528`, `:694`, `:821`, `R/unload.R:36`, `:108`. Rerun the grep at the task. Run `devtools::document()`, then the AC3 grep and the AC2 grep over `R/` and `man/`.
- [x] T3: Add a message assertion to the browser-method test (`tests/testthat/test-vignette-claims.R:357`) and see it red. Then edit the warning at `R/setup.R:148` to say to open the LM Studio app once, then restart R.
- [x] T4: Test first in `tests/testthat/test-vignette-claims.R`: read `README.Rmd` and `vignettes/*.Rmd.orig`. Skip when they are absent (`.Rbuildignore` drops them, LESSONS M005). Fail when the files are present and give no matching line, and fail on a matching line without `port = 1234`. See it red on today's six lines. Then edit `README.Rmd:59-60`, `chat-options.Rmd.orig:38`, `text-analysis.Rmd.orig:69`, and `headless-config.Rmd.orig:101`, `:184`, `:233`, plus any prose that says the start uses the default port. Run `devtools::build_readme()`.
- [x] T5: Live knit, one source per run: `Rscript data-raw/knit-vignettes.R vignettes/<name>.Rmd.orig` for `chat-options`, `text-analysis`, and `headless-config` (LESSONS M009), with the server stopped and no model loaded. Stop the daemon after the `headless-config` knit. End with a start on port 1234 and a stop (LESSONS M083). Run the AC2 grep over `vignettes/`.
- [x] T6: One new bullet in the development section of `NEWS.md`, written against the T1 to T5 output.
- [ ] T7: `devtools::test()` and `devtools::check()` clean.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which work — the server port fix, the "No-port start outside getting-started" candidate row.
- 2026-10-18: question set: change the `port` default of `lms_server_start()` — no, keep the default and fix the docs and messages.
- 2026-10-18: question set: live LM Studio runs on this Mac (start and stop the server, re-knit chat-options, text-analysis, and headless-config) — granted.
- 2026-10-18: plan gate chose the docs and message fix over a `port` default of 1234 because the user chose it and it changes no exported behavior; falsified by a reader who follows the fixed docs and still starts the server on another port.
- 2026-10-18: collision check: absorbs the "No-port start outside getting-started" row in full; M083 shipped the getting-started part; no D-entry bears on a server port; inbox has 0 open issues and 0 open PRs.
- 2026-10-18: lessons surfaced: M005 (skip a source-reading test on an empty file list), M009 (knit one source per run; the headless knit leaves the daemon up), M083 (end a live run with a start on 1234 and a stop).
- 2026-10-18: criteria audit (full mode), 6 findings, all taken: AC1's test skip and non-empty check moved to T4; AC1's README.md clause now names the line, not a `build_readme()` diff; AC3 widened to every `man/*.Rd` example line (13 sites outside `lms_server_start()`) and its port text narrowed to the request functions; AC4 names the new message assertion; AC5's output clause narrowed to chat-options and headless-config, because text-analysis sets `rlmstudio.quiet` before its start chunk; the browser warning's quiet bypass became a candidate row.
- 2026-10-18: AC1 keeps a one-line domain (a call split over lines is outside it), decided toward the narrower promise.
- 2026-10-18: changelog: one new NEWS bullet, beside the M083 getting-started bullet.
- 2026-10-18: status in-progress; branch m084-server-start-port cut from main at 62eaeab.
- 2026-10-18: T1 kept the custom-port example `lms_server_start(port = 8080, cors = TRUE)`, with a comment naming the `host` the other functions then need; AC3 as written requires `port = 1234` there, so AC3 goes to amendment.
- 2026-10-18: re-audit: AC3 (full) — the whole-file grep also matches the `\usage{}` line of `man/lms_server_start.Rd`, which can never pass `port = 1234` (the old wording had the same flaw); the probe could not show the exception's comment.
- 2026-10-18: re-audit: AC3 (full) — domain limited to `\examples{}` is reachable and unblocked; name the extraction procedure (`tools::Rd2ex(..., commentDontrun = FALSE)`, since the default comments out `\dontrun` lines and a brace range mis-scopes), and do not grep the port sentence literally (roxygen writes `\verb{}` and wraps lines). Second re-audit line on AC3: the wording goes to the user.
- 2026-10-18: substantive amendment: AC3 limited to the examples sections through `tools::Rd2ex()`, with the 8080 example as its one exception; the user accepted the wording at the stop.
- 2026-10-18: T1 done: test-serve.R tests the no-port and `port = 1234` messages (red on the old message, then green); message, `port` help, and `lms_server_start()` examples changed; `devtools::test()` 0 fail, 3 skip, 24571 pass.
- 2026-10-18: T2 done: the grep gave the same 13 sites; `port = 1234` added; `R/chat.R:2618` is a `@noRd` block, so 12 Rd pages changed. The AC3 `Rd2ex()` check printed 15 lines, 14 with `port = 1234` and the 8080 line under its `host` comment; `grep -rn "default port" R/ man/` printed nothing; `devtools::test()` 0 fail.
- 2026-10-18: T3 done: the browser-method test asserts "open the LM Studio app once, then restart R" (red on the old warning, then green); `R/setup.R:148` changed; the README's hand-written copy of that warning (`README.Rmd:45`) changed with it; `devtools::test()` 0 fail.
- 2026-10-18: T4 done: the new source test in test-vignette-claims.R was red on the six planned lines and silent on getting-started, then green after the edits; the README Quick Start now says why port 1234; `devtools::build_readme()` rebuilt README.md. `devtools::test()` has 3 failures, all `test-vignette-knit.R:43` for the three edited sources, which T5's knit clears.
- 2026-10-18: T5 done: live knits of chat-options, text-analysis, and headless-config, one per run, each exit 0; chat-options and headless-config print "started successfully on port 1234."; new model replies changed review 1's sentiment and review 4's stars in text-analysis, and the prose there names neither; `lms daemon down` refused because the desktop app runs the daemon, so it stays up; ended with `lms server start --port 1234` and a stop, no model loaded; the AC2 grep printed nothing; `devtools::test()` 0 fail, 3 skip, 24580 pass.
- 2026-10-18: T6 done: two NEWS bullets, one for the start message and examples and one for the install message (the plan said one bullet; two read better as separate behaviors); the request-function default was read from the signatures (13 `host = "http://localhost:1234"`, plus `lms_server_start()`'s `host = NULL`).

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
