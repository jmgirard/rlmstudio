# M057: One meaning for each flag argument

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP4, GP6
- **Resolves:** —
- **Surface tier:** user-facing — it changes which values exported functions accept and what `quiet` does
- **Branch/PR:** m057-flag-arguments

## Goal

Each TRUE/FALSE argument of an exported function accepts only the values
that its help page names, with one meaning for each value.

## Scope

**In:** The candidate row on flags read through `isTRUE()`, taken whole.
Each flag argument that no check covers yet gets `rlm_check_flag()` in
`R/utils-args.R`, above `stop_if_no_server()` or the `lms` CLI run (D-008).
`quiet` defaults to `NULL` and follows D-028. The two `lms_load()` load
settings drop their `as.logical()` conversion. A `logprobs` in the `...` of
`lms_chat_batch()` and `lms_chat_native()` is checked, the second by D-029.
Help pages, the `?rlmstudio` option entry, and NEWS follow.

**Out:** The `stream` check keeps its D-023 rule. The warnings that D-010
and D-021 show past `quiet` stay as they are. The other fields in `...` stay
with the server (D-003). The stderr parse of `lms_server_status(json =
TRUE)` and the encoding detail of `type_fault()` keep their own candidate
rows.

## Acceptance criteria

- [ ] AC1: Scan `formals()` of each function that `getNamespaceExports("rlmstudio")` lists on the
      branch. Take each formal whose default is the constant `TRUE` or `FALSE`. Each such argument
      aborts on each of these values: `NA`, `"yes"`, `1`, `c(TRUE, FALSE)`, `logical(0)`,
      `list(TRUE)`, and `NULL`. The abort has no condition class, and its message names the
      argument. It comes before the check for a running server, before any HTTP request, and before
      any `lms` CLI run. `TRUE`, `FALSE`, `c(a = TRUE)`, and `matrix(FALSE)` pass the check.
- [ ] AC2: A scan of `formals()` over the same exports, with no default filter, finds `quiet` in
      five functions. They are `lms_server_status()` and four others: `list_models()`,
      `list_instances()`, `lms_chat_batch()`, and `lms_embed()`. In the four, `quiet` defaults to
      `NULL`. It aborts as AC1 states on each AC1 value other than `NULL`. With `quiet = NULL`, the
      function follows the `rlmstudio.quiet` option. `TRUE` hides the messages below. If the option is
      `TRUE`, `FALSE` still prints them. They are the two "No models found" messages of
      `list_models()`, and the "No loaded model instances" message of `list_instances()`. In the
      same way, `TRUE` starts no progress bar and `FALSE` starts one. The bars are the one of
      `lms_chat_batch()`, and the one of an `lms_embed()` call that sends more than one request. The
      rule holds for each of nine pairs. `quiet` is `TRUE`, `FALSE`, or `NULL`, and the option is
      `TRUE`, `FALSE`, or unset. With `quiet = TRUE` and the option `TRUE`, these warnings still
      show: the failed-inputs, cut-off, and list-fallback warnings of `lms_chat_batch()`, and the
      failed-inputs warning of `lms_embed()`.
- [ ] AC3: `lms_server_status()` keeps `quiet = FALSE`. `quiet = TRUE` adds `--quiet` to the CLI
      arguments, and `quiet = FALSE` does not. The `rlmstudio.quiet` option does not change them.
      This holds for `quiet = FALSE` with the option `TRUE`, and for `quiet = TRUE` with the option
      `FALSE`.
- [ ] AC4: The `flash_attention` and `offload_kv_cache_to_gpu` arguments of `lms_load()` abort as
      AC1 states on each AC1 value other than `NULL`, and on `"true"`. `NULL`, `TRUE`, and `FALSE`
      pass. `TRUE`, `c(x = TRUE)`, and `matrix(TRUE)` reach the load request body as JSON `true`.
      `FALSE` and `matrix(FALSE)` reach it as `false`. `NULL` leaves the field out of the body.
- [ ] AC5: In `lms_chat_batch()`, a `logprobs` in `...` aborts as AC1 states on each AC1 value,
      `NULL` included. That holds for each name that `lms_chat()` matches to `logprobs`, from `l` to
      `logprobs`, and the message names `logprobs`. In `lms_chat_native()`, each element of `...`
      named exactly `logprobs` aborts as AC1 states on each AC1 value other than `NULL`. There,
      `NULL`, `TRUE`, `FALSE`, `c(a = TRUE)`, and `matrix(FALSE)` pass. A value that `isTRUE()`
      accepts warns. For each passing value, and for two elements named `logprobs`, no `logprobs`
      field reaches the request body.
- [ ] AC6: The help text of each argument in AC1 to AC5 names the values it accepts. It says that
      any other value aborts before the check for a running server. Where a function makes no such
      check, it says before the `lms` CLI runs. The `rlmstudio.quiet` entry of `?rlmstudio` states
      the AC2 rule, and says that the option does not change `lms_server_status(quiet)`. Take each
      argument or `...` element in AC1, AC2, AC4, or AC5 that at cd90e63 accepts a value that it now
      rejects. NEWS names the function of each. It states the old rule that now aborts. For the two
      load settings, that is any value that `as.logical()` turned into `TRUE` or `FALSE`. For the
      other flags, it is any value other than `TRUE`, read as `FALSE`. It names the new `quiet`
      default of `list_models()`, `list_instances()`, and `lms_chat_batch()`. It says that
      `quiet = FALSE` now shows their output when the option is `TRUE`. `devtools::document()`
      leaves no diff.
- [ ] AC7: `devtools::test()` reports no failure. `devtools::check()` gives 0 errors and 0 warnings.
      It gives no note that main at cd90e63 does not give.

## Coverage

- AC1 → T1, T2, T5
- AC2 → T3
- AC3 → T3
- AC4 → T2
- AC5 → T1
- AC6 → T4
- AC7 → T6

## Tasks

- [x] T1: Chat functions. Add `rlm_check_flag()` for `logprobs` and
      `simplify` of `lms_chat()`, `lms_chat_openai()`, and
      `lms_chat_openresponses()`, and for `simplify` of `lms_chat_native()`
      and `lms_chat_batch()`, above `stop_if_no_server()`. In the batch,
      test the name `logprobs` in `rlm_chat_dots()` output, because
      `args[["logprobs"]]` (`R/chat.R:1658`) is `NULL` for an absent name
      too. In `lms_chat_native()`, replace `dots$logprobs`
      (`R/chat.R:1192`) with an exact-name read of every element. Tests go
      in a new `tests/testthat/test-flag-args.R`, one `test_that()` block
      per function, over a scan built like `guarded_exports()` in
      `test-arg-guards.R`. An empty scan fails. Stubs for the server probe,
      the request, and `processx::run()` count their calls (M015 lesson).
      For `lms_chat()`, stub its delegates, so that its own check is the one
      under test (M003 and M013 lessons).
- [ ] T2: The other functions. Check `simplify` of `lms_embed()`,
      `echo_load_config` and `force` of `lms_load()`, `force` of
      `lms_daemon_stop()`, and `json`, `verbose`, and `quiet` of
      `lms_server_status()`. Check `flash_attention` and
      `offload_kv_cache_to_gpu` with `null_ok = TRUE`. Send `isTRUE(x)` in
      place of `as.logical()` (`R/load.R:104-114`), so that names and dims
      do not reach the body.
      Read the sent load body through the shared recorder or
      `req_dry_run()` (M004 and M008 lessons). Extend T1's tests.
- [ ] T3: `quiet`. Set the default to `NULL` in `list_models()`,
      `list_instances()`, and `lms_chat_batch()`. Pass `quiet` into
      `rlm_inform()` in `R/list.R`, so that `FALSE` overrides the option.
      Test the nine pairs per function, each function in its own block, and
      the four warnings with `quiet = TRUE` and the option `TRUE`. Test the
      two `lms_server_status()` cases of AC3 through
      `build_args_server_status()` and the exported function.
- [ ] T4: Help text for each argument of AC1 to AC5, and the
      `rlmstudio.quiet` entry in `R/rlmstudio-package.R`. If the
      `rlmstudio-conditions` page names these checks, update it. In NEWS, rewrite the unreleased `quiet`
      bullet of `list_models()` (`NEWS.md:21`), and add one entry for the
      rest. Run `devtools::document()`.
- [ ] T5: Planted defect. In a scratch copy, delete the check of one
      argument in `lms_chat()` and one in `lms_server_status()`. Check
      that only the blocks of those functions go red in `test-flag-args.R`.
- [ ] T6: Run `devtools::test()` and `devtools::check()`. The check needs
      `RLMSTUDIO_API_TOKEN` where the server asks for a token (M009 lesson).

## Work log

- 2026-09-29: created by /milestone-plan.
- 2026-09-29: criteria audit (full mode, fresh [O] reader) returned 15 findings. 13 fixes landed in the criteria text. They add attributed and list probes, name the AC2 outputs and warnings, and add the unset option. AC3 tests both directions, AC4 a named `TRUE`, and AC5 the `NULL` and `l` cases. AC6 covers functions with no server check and names old values. Two test-layout sentences moved to the tasks. The `lms_chat_native()` finding became a gate question.
- 2026-09-29: second criteria audit (full mode, fresh [O] reader) on the gate-changed text returned 7 findings, all fixed. AC2 scans with no default filter and says that `FALSE` starts a bar, not that it shows one. AC4 adds `matrix()` probes. AC5 names the passing native values and the message name. AC6 states the old rules in place of sample values.
- 2026-09-29: plan gate chose `NULL` as the `quiet` default, with `TRUE` and `FALSE` over the option, over "`FALSE` and `NULL` both follow the option" because no value can then show output that the option hides; falsified by a user who needs the option to silence a call that passes `quiet = FALSE`.
- 2026-09-29: plan gate chose a check of `logprobs` in the `...` of `lms_chat_native()` over leaving it to the server because the function already reads it as a flag; falsified by a `/api/v1/chat` request that honors `logprobs`.
- 2026-09-29: plan gate chose `TRUE`, `FALSE`, or `NULL` alone for the two `lms_load()` load settings over keeping `as.logical()` because every other flag follows that rule; falsified by a user whose script passes `"true"` or `1` there and cannot change it.
- 2026-09-29: plan chose a scan of exported formals as the test domain over a hand list of functions because a new flag argument then falls under the test; falsified by a flag argument whose default is not a constant `TRUE` or `FALSE` that the scan misses.
- 2026-09-29: implement started on branch m057-flag-arguments. Question gate skipped, because the plan left nothing open. The export scan found that `lms_embed()` takes `quiet = NULL` with no check, so T3 adds one for AC2.
- 2026-09-29: T1 done. The five chat functions check `logprobs` and `simplify` above the server probe. The batch checks a `logprobs` name in `rlm_chat_dots()` output, and the native function checks and drops each exact `logprobs`. `test-flag-args.R` covers the chat functions only until T2 and leaves `quiet` to T3. `devtools::test()` gave 0 failures.

## Decisions

## Review
