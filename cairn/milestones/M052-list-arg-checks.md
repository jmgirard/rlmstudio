# M052: The two list functions check their arguments before any request

- **Status:** review
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

- [x] AC1: A valid `type` is a character vector of one or more elements. No element is `NA`, and no element holds only `[[:space:]]` characters, the empty string included. If `type` is not valid, `list_models()` and `list_instances()` abort. `is.character()` decides the type, so a factor aborts. Names, dims, and classes on a character vector are ignored. So a named vector and a 1-by-1 character matrix pass. The abort comes before the server probe, sends no request, and carries no `rlmstudio_` condition class. Its message names `type` and the rule that the value broke. Tests drive each function with ten bad values: `1`, `NA`, `NULL`, a factor, `character(0)`, `c("llm", NA)`, `""`, `c("llm", "")`, `" "`, and `"\f"`. Each test asserts its own message detail. Tests show that `c(a = "llm")` and `matrix("llm")` pass on each function. One more test per function shows the `type` abort while the server probe reports a stopped server.
- [x] AC2: A valid `quiet` is `NULL` or a value that `isTRUE()` or `isFALSE()` accepts. If `quiet` is not valid, `list_models()` and `list_instances()` abort. The abort comes before the server probe, sends no request, and carries no `rlmstudio_` condition class. Its message names `quiet` and the rule that the value broke. Tests drive each function with `NA`, `logical(0)`, `c(TRUE, FALSE)`, `"yes"`, and `1`. Each test asserts its own message detail. One more test per function shows the `quiet` abort while the server probe reports a stopped server. The default stays `FALSE`. `quiet = TRUE` prints nothing. If the `rlmstudio.quiet` option is not `TRUE`, `quiet = FALSE` and `quiet = NULL` print the no-match message. For `list_models()`, that message is "No models found matching criteria", from a model list of at least one model. Tests pin `quiet = NULL` on each function, with the option unset and with the option `TRUE`.
- [x] AC3: A valid `loaded` or `detailed` is a value that `isTRUE()` or `isFALSE()` accepts, so `NULL` is not valid. If either is not valid, `list_models()` aborts. The abort comes before the server probe, sends no request, and carries no `rlmstudio_` condition class. Its message names the argument and the rule that the value broke. Tests drive each of the two arguments with `NA`, `NULL`, `logical(0)`, `c(TRUE, FALSE)`, `"yes"`, and `1`. Each test asserts its own message detail. One more test per argument shows the abort while the server probe reports a stopped server.
- [x] AC4: A `type` can pass AC1 and match no model type in the model list, such as `"vlm"`. Such a `type` does not abort. `list_models()` returns `data.frame()`, invisibly, and prints its "No models found matching criteria" message. `list_instances()` returns the zero-row frame with the four character columns, invisibly. It prints its "No loaded model instances" message. A test pins this on each function with the `rlmstudio.quiet` option unset. The model list of the test holds a model with a loaded instance, of a type other than `"vlm"`.
- [x] AC5: Calls with values that were valid before this milestone behave as before. The evidence is that every test file at the plan commit passes or skips with no edit under `devtools::test()`.
- [x] AC6: The help pages of the two functions give the rule of each checked argument in its `@param` text. The text says whether `NULL` is accepted. The "Server not running" section of the `rlmstudio-conditions` help page lists the arguments checked before the server probe. That list names `type`, `quiet`, `loaded`, and `detailed` of `list_models()` and `list_instances()`. `NEWS.md` has an entry that names the new aborts.

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
- 2026-09-28: claim audit: 32 claims read, 2 corrected — NEWS.md, R/utils-args.R
- 2026-09-28: the two corrections were the NEWS claim that `quiet = NA` always failed, which held only on a call that matched no model, and a `rlm_check_type()` comment that a number or an empty string can match nothing. The reader re-read both once and found them correct. Status set to review.

## Decisions

## Review

Review run 2026-09-28 on `m052-list-arg-checks` at 9241ad7. The branch already held `origin/main` (5b62302), so no merge was needed.

- AC1 evidence: `devtools::test()` ran "a bad type aborts, named, before any request" with 60 expectations and 0 failures. Each of the 10 bad values on each function matched its own detail, matched the `type` rule, and carried no `rlmstudio_` class, under `local_no_request_allowed()`. "a named type and a 1-by-1 character matrix pass" gave 8 expectations, 0 failures. "an argument abort comes before the probe of a stopped server" covers `type = 1` on each function, with 0 probe calls. The same test file against the `main` code errored in the type and stopped-server tests.
- AC2 evidence: "a bad quiet aborts, named, before any request" gave 30 expectations, 0 failures, for the 5 bad values on each function. The stopped-server test covers `quiet = NA` on each function, with 0 probe calls. The `quiet = NULL` test passed on each function. It ran with the option unset and with the option `TRUE`. `formals()` shows a default of `FALSE` on both. A direct run with `type = "vlm"` and `quiet = TRUE` gave 0 messages on each function. The AC4 test shows the default `quiet = FALSE` printing both no-match messages with the option unset. Against `main`, the quiet and `quiet = NULL` tests errored.
- AC3 evidence: "a bad loaded or detailed aborts list_models, NULL included" gave 36 expectations, 0 failures. That is 6 bad values for each of `loaded` and `detailed`, each with its own detail, the argument rule, and no `rlmstudio_` class. The stopped-server test covers `loaded = NULL` and `detailed = NULL`, with 0 probe calls. Against `main`, this test errored.
- AC4 evidence: "an unknown type returns the empty frame and a message, with no abort" gave 6 expectations, 0 failures, with the option unset. `list_models(type = "vlm")` returned `data.frame()` invisibly with its no-match message. `list_instances(type = "vlm")` returned the zero-row frame of four character columns invisibly with its message. The fixture holds one `"llm"` model with one loaded instance. This test also passed against `main`, so the old behavior holds.
- AC5 evidence: `git diff --stat 5b62302..HEAD -- tests/` lists only the new `tests/testthat/test-list-args.R`, so no test file at the plan commit changed. `devtools::test()` on the branch gave 13,914 expectations, 0 failed, 0 errors, 3 skipped, 0 warnings.
- AC6 evidence: the six `@param` entries in `man/list_models.Rd` and `man/list_instances.Rd` each give the rule and say whether `NULL` passes. The "Server not running" section of `man/rlmstudio-conditions.Rd` names `type`, `quiet`, `loaded`, and `detailed` of `list_models()` and `list_instances()`. `NEWS.md` line 3 names the new aborts. `devtools::document()` gave no diff.

Consistency gate: `cairn_validate.py` passed, exit 0. No `DESIGN.md` principle changed, so `cairn_impact` did not run. `devtools::document()` gave no diff. `README.md` and `README.Rmd` come from the same commit, and the branch touches neither. `pkgdown::check_pkgdown()` found no problems. The branch adds no top-level file. `devtools::check()` gave 0 errors, 0 warnings, 0 notes.

Independent review: three fresh reviewers ran. They were a diff reviewer (O), a history reviewer (S), and a prior-review reviewer (P). Findings, most severe first, with the disposition proposed at the gate:

- O1: `quiet = FALSE` defers to the `rlmstudio.quiet` option in the list functions, because `rlm_inform()` reads it again. So `NULL` acts the same as `FALSE`. In `lms_embed()` and `lms_chat_batch()`, `FALSE` overrides the option. The help text is accurate, and AC2 states this behavior. Proposed: follow-up candidate row. S2 reports the same fact and finds no regression from `main`.
- O8 and S1: NEWS lists no call that worked before and now aborts. On `main`, `quiet = 1` acted as `TRUE`. Proposed: fix now, with one NEWS sentence.
- O9: no test pins that `list_models()` prints nothing with `quiet = TRUE` on a no-match call. A direct run gave 0 messages. Proposed: fix now, with one test.
- O5: the new rule lines write `TRUE, FALSE, or NULL` as plain text. Other rule lines in `R/utils-args.R` use `{.code}`, as in the `stream` rule. Proposed: fix now, and update the fixed strings in the new tests.
- O6: the conditions-page sentence can suggest that `list_instances()` has `loaded` and `detailed`. Proposed: fix now, with a split of the list by function.
- O3: a string with an invalid encoding gets the detail "holds only whitespace", with two `grepl()` warnings. `id_fault()` shares the pattern. Proposed: follow-up candidate row that covers both helpers.
- O2: a character `type` with class `"Date"` passes the check and then matches nothing, because `%in%` converts through `as.character.Date()`. Proposed: reject. The value is contrived, and the match code is unchanged from `main`.
- O4: a no-break space or a zero-width space passes as a type. Proposed: reject. It follows the `[[:space:]]` rule shared with `id_fault()`.
- O7: `quiet = NA_integer_` gets "You gave an integer value." Proposed: reject. The detail is accurate.
- O10: the `list_models()` `@return` text does not say the empty frame is invisible. Proposed: reject. The text predates this milestone.
- S3: `rlm_check_type()` takes no `arg` argument, and `type_fault()` accepts a `dim`, unlike `id_fault()`. Proposed: reject. AC1 asks for the `dim` rule, and the helper serves one argument.
- P1: the help text says `FALSE` defers to the option, and the reviewer said it does not. Proposed: reject. A direct run with the option `TRUE` and `quiet = FALSE` printed nothing, so the help text is correct.

Mutation runs by O: the tests fail with `rlm_check_type()` removed, with the probe above the checks, and with the `null_ok` return removed. The P reviewer did not run the GitHub comment probe. Archived Review sections were its evidence.
