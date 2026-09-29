# M052: The two list functions check their arguments before any request

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP6
- **Resolves:** —
- **Surface tier:** user-facing — it changes which calls of the exported `list_models()` and `list_instances()` abort
- **Branch/PR:** m052-list-arg-checks

## Goal

`list_models()` and `list_instances()` abort with a clear message, before the server probe, on a bad `type`, `quiet`, `loaded`, or `detailed`.

## Scope

**In:** The `type` and `quiet` checks on both functions. The `loaded` and `detailed` checks on `list_models()`. `quiet = NULL`, which reads the `rlmstudio.quiet` option. The help pages, the conditions page, and NEWS.

**Out:** The TRUE/FALSE arguments of the other exported functions keep their `isTRUE()` reads. A new candidate row holds them. A list of known model types stays out, as the work log records. The other items of the "More tests for `list_instances()`" candidate row stay there. The coarse failures of the loops in `tests/testthat/test-arg-guards.R` stay with their candidate row.

## Acceptance criteria

- [ ] AC1: A valid `type` is a character vector of one or more elements. No element is `NA`, and no element holds only `[[:space:]]` characters, the empty string included. If `type` is not valid, `list_models()` and `list_instances()` abort. `is.character()` decides the type, so a factor aborts. Names, dims, and classes on a character vector are ignored. So a named vector and a 1-by-1 character matrix pass. The abort comes before the server probe, sends no request, and carries no `rlmstudio_` condition class. Its message names `type` and the rule that the value broke. Tests drive each function with ten bad values: `1`, `NA`, `NULL`, a factor, `character(0)`, `c("llm", NA)`, `""`, `c("llm", "")`, `" "`, and `"\f"`. Each test asserts its own message detail. Tests show that `c(a = "llm")` and `matrix("llm")` pass on each function. One more test per function shows the `type` abort while the server probe reports a stopped server.
- [ ] AC2: A valid `quiet` is `NULL` or a value that `isTRUE()` or `isFALSE()` accepts. If `quiet` is not valid, `list_models()` and `list_instances()` abort. The abort comes before the server probe, sends no request, and carries no `rlmstudio_` condition class. Its message names `quiet` and the rule that the value broke. Tests drive each function with `NA`, `logical(0)`, `c(TRUE, FALSE)`, `"yes"`, and `1`. Each test asserts its own message detail. One more test per function shows the `quiet` abort while the server probe reports a stopped server. The default stays `FALSE`. `quiet = TRUE` prints nothing. If the `rlmstudio.quiet` option is not `TRUE`, `quiet = FALSE` and `quiet = NULL` print the no-match message. For `list_models()`, that message is "No models found matching criteria", from a model list of at least one model. Tests pin `quiet = NULL` on each function, with the option unset and with the option `TRUE`.
- [ ] AC3: A valid `loaded` or `detailed` is a value that `isTRUE()` or `isFALSE()` accepts, so `NULL` is not valid. If either is not valid, `list_models()` aborts. The abort comes before the server probe, sends no request, and carries no `rlmstudio_` condition class. Its message names the argument and the rule that the value broke. Tests drive each of the two arguments with `NA`, `NULL`, `logical(0)`, `c(TRUE, FALSE)`, `"yes"`, and `1`. Each test asserts its own message detail. One more test per argument shows the abort while the server probe reports a stopped server.
- [ ] AC4: A `type` can pass AC1 and match no model type in the model list, such as `"vlm"`. Such a `type` does not abort. `list_models()` returns `data.frame()`, invisibly, and prints its "No models found matching criteria" message. `list_instances()` returns the zero-row frame with the four character columns, invisibly. It prints its "No loaded model instances" message. A test pins this on each function with the `rlmstudio.quiet` option unset. The model list of the test holds a model with a loaded instance, of a type other than `"vlm"`.
- [ ] AC5: Calls with values that were valid before this milestone behave as before. The evidence is that every test file at the plan commit passes or skips with no edit under `devtools::test()`.
- [ ] AC6: The help pages of the two functions give the rule of each checked argument in its `@param` text. The text says whether `NULL` is accepted. The "Server not running" section of the `rlmstudio-conditions` help page lists the arguments checked before the server probe. That list names `type`, `quiet`, `loaded`, and `detailed` of `list_models()` and `list_instances()`. `NEWS.md` has an entry that names the new aborts.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2, T3
- AC3 → T1, T2
- AC4 → T3
- AC5 → T3
- AC6 → T4

## Tasks

- [x] T1: Write the fault tests of AC1 to AC3 first, in a new `tests/testthat/test-list-args.R`. Each guard test mocks `is_server_running` to `TRUE` and runs under `local_no_request_allowed()`. A request then fails the test. Each stopped-server test mocks the probe to `FALSE` and asserts the argument message, not `rlmstudio_no_server`. Make sure that the tests fail against the current code.
- [x] T2: Add `type_fault()` with `rlm_check_type()`, and `flag_fault()` with `rlm_check_flag(value, arg, null_ok)`, to `R/utils-args.R`. Follow the `id_fault()` style: a plain-text detail with no cli braces. Call the checks at the top of `list_models()` (`R/list.R:52`) and `list_instances()` (`R/list.R:217`), above `stop_if_no_server()`. Read `quiet` through `is_quiet()`, so that `NULL` reads the option. Make the T1 tests pass.
- [x] T3: Add the AC2 `quiet = NULL` tests, the AC1 passing-value tests, and the AC4 unknown-type tests. Run `devtools::test()`. Make sure that no test file at the plan commit needed an edit.
- [x] T4: Update the `@param` text of the four arguments, the "Server not running" section in `R/conditions.R:14-17`, and `NEWS.md`. Run `devtools::document()`, then a clean `devtools::check()`.

## Work log

- 2026-09-28: created by /milestone-plan.
- 2026-09-28: criteria audit ran in full mode, twice, with a fresh [O] reader. The first pass returned 14 findings, all fixed or posed at the gate. The second pass read the gate-changed criteria and returned 6 findings, all fixed in the text above.
- 2026-09-28: plan gate chose any non-blank strings for `type` over a fixed list of `"llm"` and `"embedding"`. A fixed list aborts on a model type that LM Studio adds later. Falsified by users who misspell a type and read the empty result as "no models".
- 2026-09-28: plan gate chose to accept `quiet = NULL` as "read the option" over a rejection of it. `lms_embed()` already gives `NULL` that meaning. Falsified by a user who reads `NULL` on these two functions as `TRUE`.
- 2026-09-28: plan gate chose to check `loaded` and `detailed` here over a separate candidate row. They take the same rule and test pattern as `quiet`. Falsified by a check of those two that needs a rule of its own.
- 2026-09-28: plan chose a new `type_fault()` over a reuse of `rlm_check_text()`. `rlm_check_text()` accepts `""` and gives no detail per rule. Falsified by a later merge of the two rules into one helper with details.
- 2026-09-28: implement started on branch `m052-list-arg-checks`. No question gate, because the plan left nothing open.
- 2026-09-28: T1 done. `tests/testthat/test-list-args.R` holds the AC1 to AC3 fault tests. On main, the three guard tests fail with "a request left the process", and the stopped-server test fails with `rlmstudio_no_server`.
- 2026-09-28: T2 done. `rlm_check_type()` and `rlm_check_flag()` are in `R/utils-args.R`, and both list functions call them above `stop_if_no_server()`. The T1 tests pass, and `devtools::test()` gave 523 tests, 0 failed, 0 errors, 3 skipped.
- 2026-09-28: T3 done. `test-list-args.R` adds the AC1 passing-value, AC2 `quiet = NULL`, and AC4 unknown-type tests. `git diff --stat main -- tests/` lists only the new file. `devtools::test()` gave 526 tests, 0 failed, 0 errors, 3 skipped.
- 2026-09-28: T4 done. The `@param` text of the four arguments, the "Server not running" section, and a NEWS entry are updated. `devtools::document()` regenerated 13 pages that inherit that section. `devtools::check()` gave 0 errors, 0 warnings, 0 notes. T2 reads `quiet` through `is_quiet()` as planned. `rlm_inform()` reads the option again, so `FALSE` still defers to the option.

## Decisions

## Review
