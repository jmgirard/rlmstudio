<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M086: Every alert of the package follows the quiet option

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP6   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — messages that users see or silence   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m086-quiet-alerts   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

With `options(rlmstudio.quiet = TRUE)`, no alert of the package prints, except the `lms_load()` echo alert that the "load echo alert" candidate row holds.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** Absorbs the candidate row "install message quiet" in full, widened to four of the five other direct `cli::cli_alert_*` calls that a grep of `R/*.R` found on 2026-10-18. The five call sites are `check_lms_version()` (`R/setup.R:43`, `:69`, `:82`), the browser branch of `install_lmstudio()` (`R/setup.R:147`), and the empty-logprobs line of `print.lms_chat_result()` (`R/chat_oop.R:94`). Two new helpers in `R/utils-msg.R`, `rlm_alert_warning()` and `rlm_alert_danger()`, built as `rlm_alert_info()` is. One NEWS bullet.

**Out:**
- The echo alert of `lms_load()` (`R/load.R:149`): with `echo_load_config = TRUE` and the model already loaded, the call returns the model key and not the load config, a lost result. D-010, D-021, and D-037 keep warnings about lost results visible past quiet, but they cover warnings and not alerts. So the alert stays as it is, and the new "load echo alert" candidate row holds the choice between a classed warning past quiet and a quiet-aware alert.
- Warnings raised with `cli::cli_warn()`: they are conditions, not alerts, and D-010, D-021, D-032, and D-037 set which of them pass quiet.
- The rest of `print.lms_chat_result()` and the download-status print method (`cli_rule()`, `cli_h3()`): the printed object is the output that the user asked for.
- The no-server hints: M085.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [x] AC1: `grep -n "cli::cli_alert" R/*.R` prints lines of `R/utils-msg.R` and the one line of the already-loaded echo branch of `R/load.R`, and no other line.
- [x] AC2: A table test in `tests/testthat/test-quiet-alerts.R` has one row for each of the five call sites that the Scope `In:` names. Each row runs its call once with `rlmstudio.quiet` set to `TRUE` and asserts that the shown output does not hold that row's alert text, and once with the option `FALSE` and asserts that it does.
- [x] AC3: The development section of `NEWS.md` has one bullet that names `check_lms_version()`, `install_lmstudio()`, and the print of a chat result as now silent under `rlmstudio.quiet`.
- [x] AC4: `devtools::test()` and `devtools::check()` report no failures, errors, or warnings.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive change is amend-via-gate. -->

- [x] T1: Test first: write `tests/testthat/test-quiet-alerts.R` with the AC2 rows, each row in a nested `test_that()` (D-038). Reuse the mocks of the existing tests for each site: `tests/testthat/test-setup.R:35` and `tests/testthat/test-vignette-claims.R:346` (`check_lms_version()`), `tests/testthat/test-vignette-claims.R:357` (browser install), and the print tests of `tests/testthat/test-chat.R`. See the quiet half of each row red.
- [x] T2: Add `rlm_alert_warning()` and `rlm_alert_danger()` to `R/utils-msg.R`. Route the five calls through them. Rerun the AC1 grep, which also catches a bare `cli::cli_alert(`, and see T1 green. Plant a direct `cli::cli_alert_warning()` back at one site and see its row go red.
- [x] T3: One NEWS bullet in the development section, written against the T1 and T2 output.
- [x] T4: `devtools::test()` and `devtools::check()` clean.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which work — the "install message quiet" row, planned as M086 beside M085 and M087.
- 2026-10-18: plan widened the row from one call to five of the six direct `cli::cli_alert_*` calls that a grep of `R/*.R` found, because each one breaks GP6 in the same way and a bounded grep can then certify the set. The `lms_load()` echo alert reports a lost result, the class that D-010, D-021, and D-037 keep past quiet for warnings, so its quiet choice goes to the new "load echo alert" candidate row and the alert stays as it is.
- 2026-10-18: criteria audit (full mode, fresh Opus reader), 3 findings, all taken: AC1 no longer rests on the D-entries, which cover warnings only, and the Goal names the echo alert as the exception; AC1 greps `cli::cli_alert` so a bare `cli_alert(` counts; AC2 asserts the absence of each row's alert text, because the print method always shows its rules and text.
- 2026-10-18: plan chose quiet-aware helpers over a `quiet` argument on `check_lms_version()`, `install_lmstudio()`, and `lms_load()` because no exported signature changes; falsified by a user who needs to silence one call and not the option.
- 2026-10-18: collision check: absorbs the "install message quiet" row in full; D-028 (quiet follows the option when the argument is `NULL`) holds; D-010, D-021, D-032, and D-037 govern warnings past quiet and stay out of scope; inbox has 0 open issues and 0 open PRs.
- 2026-10-18: lessons surfaced: M014 (a base mock does not reach `interactive()` in the byte-compiled package; mock the package binding), M019/M015 (`expect_no_error()` and `expect_s3_class()` take no `info`; nested tests and parent checks).
- 2026-10-18: changelog: one new NEWS bullet in the development section.
- 2026-10-18: implement started on branch m086-quiet-alerts, cut from main at 7524bcc.
- 2026-10-18: T1: `test-quiet-alerts.R` holds five cases in nested `test_that()` blocks; each mocks inside its own `run()` and reads `capture_shown()` stdout and messages; quiet half red on all five (the alert text shows with the option TRUE), loud half green.
- 2026-10-18: T2: added `rlm_alert_warning()` and `rlm_alert_danger()` beside `rlm_alert_info()` with the same signature, routed the five calls; AC1 grep prints only `R/utils-msg.R:27,41,55,69` and `R/load.R:149`; T1 green 30/30; a direct `cli::cli_alert_warning()` planted back at the print site turned only that row red, then restored; `devtools::test()` FAIL 0, SKIP 3 (no live server), PASS 24649.
- 2026-10-18: T3: one NEWS bullet in the development section, after the browser-install bullet; its alert wording read from the five T1 alert texts and the routed calls; "results do not change" read from the helpers, which gate only the cli call.
- 2026-10-18: T4: `devtools::document()` no diff (its link warning at `R/serve.R:753` predates the branch); `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::test()` as at T2 (T3 changed NEWS only).
- 2026-10-18: claim audit: 16 claims read, 0 corrected — NEWS.md, R/chat_oop.R, R/setup.R, R/utils-msg.R, tests/testthat/test-quiet-alerts.R (fresh Opus reader; ran each path under quiet TRUE and FALSE).
- 2026-10-18: implement complete; status review.
- 2026-10-18: step-7 approval: m086-quiet-alerts approved for merge

## Review
<!-- owner: review · exclusive -->

- AC1: `grep -n "cli::cli_alert" R/*.R` on 2026-10-18 at 8edc161 printed `R/load.R:149` (the `cli_alert_warning(` inside `if (isTRUE(echo_load_config))` of the already-loaded branch, lines 145-151 read) and `R/utils-msg.R:27`, `:41`, `:55`, `:69`, and no other line. Pass.
- AC2: `tests/testthat/test-quiet-alerts.R` has five cases, one per Scope `In:` site: `check_lms_version()` no CLI (`R/setup.R:43`), unparsed output (`:69`), version 0.3.9 (`:82`), `install_lmstudio("browser")` (`:147`), print with `logprobs = NULL` (`R/chat_oop.R:94`). Each nested `test_that()` runs its call with `rlmstudio.quiet` TRUE and asserts `expect_no_match` of its alert text, then FALSE and asserts `expect_match`. `test_file()` on 2026-10-18: 30 expectations, 0 failures. Implement T1 saw all five quiet halves red before T2, and a planted direct call turned one row red. Pass.
- AC3: `NEWS.md:9`, under `# rlmstudio (development version)`, is one bullet that names `check_lms_version()`, `install_lmstudio(method = "browser")`, and "the print of a chat result" as showing no alerts with `options(rlmstudio.quiet = TRUE)`. Pass.
- AC4: on 2026-10-18 at b07e6be (the final code tree), `devtools::test()` FAIL 0, WARN 0, SKIP 3 (no live server), PASS 24649; `devtools::check()` 0 errors, 0 warnings, 0 notes; `devtools::document()` left no diff. Pass.
- spawned: diff-bug, blame-history, prior-review
- gate: `cairn_validate.py` all checks passed (exit 0); `pkgdown::check_pkgdown()` no problems; no new top-level files; README not touched; NEWS has the entry (AC3); no principle changed, so `cairn_impact` skipped.
- diff-bug #1: `test-setup.R:38` (unparsed-output braces test) and `test-vignette-claims.R:357` (browser install test) assert alert text that the branch made quiet-aware and do not pin `rlmstudio.quiet = FALSE`, so both fail under an ambient `options(rlmstudio.quiet = TRUE)` — fix now, fixed b07e6be (both pinned; under ambient quiet `test-setup.R` passes and `test-vignette-claims.R` shows only the four failures that main at 7524bcc also shows, which went to the new candidate row "tests under ambient quiet").
- diff-bug #2: the `quiet` argument of the new helpers has no direct test and no caller — reject (planned change): the plan builds them as `rlm_alert_info()` is, no call passes `quiet`, and the profile test-doctrine tests internal helpers indirectly.
- diff-bug #3: under quiet, `check_lms_version()` returns a bare `FALSE` and the browser install opens the page with no follow-up text — reject (planned change): the Goal asks for exactly this silence.
- blame-history #1: `lms_chat_openai(logprobs = TRUE)` always returns `NULL` logprobs (`R/chat.R:827-833`), and the print alert at `R/chat_oop.R:94` is now silent under quiet, so a quiet user gets no sign at the call or print — follow-up: the call never warned before this branch (pre-existing gap), and its help documents the stub (`R/chat.R:612-613`, `:644-645`); new candidate row "openai logprobs stub".
- blame-history #2: the four `R/setup.R` alerts were left direct by 79a553d with no recorded reason; with a too-old CLI, the browser install now opens the page with no reason shown under quiet — reject (planned change): the Goal and the "install message quiet" row ask for it.
- blame-history #3: the `lms_load()` echo alert (`R/load.R:149`) still shows past quiet — follow-up: already held by the "load echo alert" candidate row, out of scope by the plan.
- prior-review: archived reviews (M001, M014, M028, M052, M069, M072, M079, M084, M085) and LESSONS read, 0 PR comments in the repo; no regression found, 0 findings.
