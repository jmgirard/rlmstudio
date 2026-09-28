# M050: A table of loaded model instances

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP2, GP3, GP6
- **Resolves:** —
- **Surface tier:** user-facing — the milestone adds an exported function
- **Branch/PR:** m050-list-instances

## Goal

A new function `list_instances()` returns one row per loaded model instance, with the load configuration of each
instance in columns.

## Scope

**In:** a new export `list_instances(type, quiet, host, token)` in `R/list.R`. It sends the request that
`list_models()` sends, through `request_model_list()`, and flattens the `loaded_instances` field. It wraps the
loaded-instance view that `lms ps` offers, over the REST model list (GP1). The milestone also adds a help page, a
pkgdown entry, a NEWS entry, and a recorded reply. It updates the DESIGN function families and the API reference page.
The live model list on 2026-09-28, from LM Studio 0.4.25+1, gave each model its own `config` fields. The
google/gemma-3-1b instance had `context_length` 8192, `parallel` 4, and `reasoning_budget_message` `""`. The nomic
embedding instance had `context_length` 2048 alone. The docs example has `context_length`, `eval_batch_size`,
`parallel`, `flash_attention`, `num_experts`, and `offload_kv_cache_to_gpu`.

**Out:** `lms ps --json` reports four fields that the REST list does not carry: the generation status, the queued
requests, the ttl, and the last-used time. They go to a candidate row. The milestone does not change `list_models()`.

## Acceptance criteria

- [ ] AC1: `list_instances()` is exported. It sends one `GET api/v1/models` request. It returns a data frame with one
      row for each entry of `loaded_instances`. Only models whose `type` is in its `type` argument count, and the
      default is `c("llm", "embedding")`. Rows follow the order of the models in the reply, then the order of the
      instances in a model. A duplicate instance id or model key gives separate rows. The first four columns are
      `id`, `key`, `type`, and `display_name`, in that order, all character. The `id` is the `id` of the instance,
      and the other three come from its model. A test uses a mocked reply with four models. The first has two
      instances, and the second has none. The third has an instance and a type outside `type`. The fourth has one
      instance. The test asserts the rows and every cell of the four columns.
- [ ] AC2: After the four columns, the frame has one column for each field name in the `config` object of a returned
      instance. The columns follow the order of first appearance. In one `config`, the first of two equal keys
      counts. A column takes the field name with no change and no R name repair. A field name that is empty, or
      equal to a name in AC1 or to the column name of an earlier, different field, takes the prefix `config.`. It
      takes the prefix again while the name still equals such a name. A row whose `config` lacks the field holds `NA` there.
      The column type follows the values of the field that are present and not `null`. All strings give a
      character column. All numbers give a double column, whole numbers included. All booleans give a logical
      column. No such values give a logical column of `NA`. In these four kinds, a `null` value is `NA`. Any other
      mix, or any JSON object or array, gives a list-column. It holds each value as `jsonlite::parse_json()` returns
      it, and `NULL` where the field is absent or `null`. Tests over mocked replies assert each rule of this
      criterion. The cases are the four atomic kinds, with `typeof` double for whole numbers, and a `null` in an
      atomic column. Other cases are a field in one instance only, a `config` of `{}`, and an object value. Also
      tested are an array value, and a number and a string in one field. Further cases are `NULL` cells for an
      absent value and for a `null` value. Name cases are a field named `id`, a field named `a-b`, and two
      equal keys in one `config`. The last cases are a field with an empty name, and a field named `config.id`
      beside one named `id`.
- [ ] AC3: The function can have no instance to return. There are three cases: the reply has no models, no model has
      an instance, or no model with an instance has a type in `type`. In each case, the function returns a data
      frame with zero rows and the four character columns of AC1, invisibly. It also prints a message through
      `rlm_inform()`. If `quiet = TRUE` or the `rlmstudio.quiet` option is `TRUE`, it prints no message. Tests
      assert the column names and types, the zero rows, and the message, for each of the three cases. Tests also
      assert that each of the two quiet values stops the message.
- [ ] AC4: The function checks the body through `request_model_list()`. It so aborts with `rlmstudio_bad_response`
      on each body that `model_list_fault()` rejects. It also aborts with that class on two faults in a model entry
      whose `type` is in `type` and that has at least one instance. One fault is a `display_name` that is present,
      not `null`, and not a string. The other is an instance `config` that is present, not `null`, and not a JSON
      object. An absent or `null` `display_name` gives `NA`. An absent or `null` `config` gives `NA` in every
      configuration column. The message names the field and its entry. Tests fire each of the two new faults and one fault of
      `model_list_fault()`. They assert the class and the field that the message names. The two new checks live in
      `list_instances()` alone. `model_list_fault()` and `request_model_list()` do not change, so `list_models()`
      and `lms_server_ready()` accept the same bodies as before. The files `tests/testthat/test-list.R`,
      `test-model-list-shape.R`, and `test-server-ready.R` pass with no edit.
- [ ] AC5: If the server does not answer, the function aborts with `rlmstudio_no_server` and sends no HTTP request.
      A reply with a status other than 200 aborts with `rlmstudio_api_error`. Its `status` field holds that status.
      The request carries the token that `token` resolves as a bearer header. Tests assert each class and the
      `status` field. The token-wrapper table in `tests/testthat/test-token-wrappers.R` asserts the header.
- [ ] AC6: A reply recorded from the live model list under `tests/testthat/list_instances/` backs a test that runs
      without a server. The reply holds google/gemma-3-1b and an embedding model, each with one loaded instance. The
      test asserts one row per loaded instance and the `context_length` value of each row. A live test asserts that
      the `id` column equals the instance ids that `list_models(detailed = TRUE)` returns, in the same order. If no
      server answers, the `tests/testthat/helper-skips.R` helpers skip it. If no model is loaded, it skips. It
      loads and unloads nothing.
- [ ] AC7: The help page states the columns of AC1, the column rules of AC2, and the empty result of AC3. It inherits
      the three condition sections of `rlmstudio-conditions`. `pkgdown/_pkgdown.yml` lists the function beside
      `list_models`. `NEWS.md` has an entry. The DESIGN function families and item 6 of
      `cairn/references/lmstudio-api-surface.md` name the function. `devtools::document()` leaves no diff, and
      `pkgdown::check_pkgdown()` passes. `devtools::test()` gives 0 failures and 0 warnings, with skips allowed.
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T1
- AC4 → T3
- AC5 → T3
- AC6 → T4
- AC7 → T5, T6

## Tasks

- [x] T1: Write the tests of AC1 and AC3 over mocked replies (`tests/testthat/helper-mock-http.R`). Then write
      `list_instances()` in `R/list.R` after `list_models()`: `request_model_list()`, the type filter, the four
      columns, and the empty result. Guard the message with `if (!quiet)`, as `list_models()` does at
      `R/list.R:66-71`. `rlm_inform(quiet = FALSE)` ignores the option. Export it through roxygen.
- [x] T2: Write the tests of AC2, then the configuration columns. Read each field by position, at the first index where
      `names(cfg)` equals the name. `[[` does not match an empty name. Build the frame with `check.names = FALSE`.
- [x] T3: Write the tests of AC4 and AC5, then the two new shape checks in a helper local to `list_instances()`.
      Add the function to the token-wrapper table and update its count. In a scratch copy, delete each new check and
      see its test go red. Check that `git diff` leaves `model_list_fault()` and `request_model_list()` unchanged.
- [x] T4: Record the live model list under `tests/testthat/list_instances/`, with `RLMSTUDIO_API_TOKEN` set. Put the
      LM Studio version and the date in a test comment. Write the recorded test and the live test of AC6.
- [x] T5: Write the help page, with each `@inheritSection` on one line. Update `pkgdown/_pkgdown.yml`, `NEWS.md`,
      the DESIGN function families, and the model-list paragraph and item 6 of
      `cairn/references/lmstudio-api-surface.md`. Run `devtools::document()` and `pkgdown::check_pkgdown()`.
- [ ] T6: Run `devtools::test()`, then `devtools::check()` with `RLMSTUDIO_API_TOKEN` set, and fix what they report.

## Work log

- 2026-09-28: created by /milestone-plan, from the candidate row "A loaded-instance table, the view `lms ps` prints".
- 2026-09-28: plan gate chose a new export `list_instances()` over an `instances` flag on `list_models()` and over the name `lms_ps()`, because a flag gives one function two row shapes and `lms_ps()` promises CLI fields the REST list lacks; falsified by users who look for the table under `list_models()` or `lms_ps()`.
- 2026-09-28: plan gate chose the REST model list over `lms ps --json` and over a merge of both, because only REST honors `host` and `token`; falsified by a user who needs a field that only the CLI reports.
- 2026-09-28: plan gate chose configuration columns under their own names, with a `config.` prefix on a clash, over a prefix on every column and over one list-column; falsified by a live configuration field whose name clashes with a fixed column.
- 2026-09-28: plan gate chose a zero-row frame with four columns for the empty case over the `data.frame()` of `list_models()`; falsified by user code that relies on the two functions returning the same empty value.
- 2026-09-28: plan criteria audit (full mode, fresh [O] reader) returned 21 findings on the draft. The clear ones are fixed above, and three judgment calls went to the plan gate. A re-audit of the criteria that the gate changed is running at the plan commit.
- 2026-09-28: re-audit of the criteria that the gate changed (full mode, same fresh [O] reader) found every earlier finding resolved and returned four clear fixes. The fixes are an empty-name read in T2, two AC2 naming test cases, the "earlier, different field" wording, and an AC4 typo, all applied.
- 2026-09-28: T1 done. `list_instances()` returns the four fixed columns and the empty result, with tests in `tests/testthat/test-list-instances.R`. The suite passes, with two live embedding tests skipped because the nomic model is not loaded.
- 2026-09-28: T2 done. The configuration columns come from the helper `config_column()` in `R/list.R`, with tests for each AC2 rule. The suite passes with the same two skips.
- 2026-09-28: T3 done. The two new checks live in `instance_list_fault()`, and `list_instances()` joins the token-wrapper table (fifteen functions). In a scratch copy, removing the `display_name` check made 6 assertions of its test fail. Removing the `config` check made 5 fail. No other test failed. `model_list_fault()` and `request_model_list()` have no diff against main, and the three named test files have no edit.
- 2026-09-28: minor amendment to T4: the recording comes from a new generator, `data-raw/record-list-instances-cassette.R`, because the profile test doctrine requires a committed generator for each fixture.
- 2026-09-28: T4 done. The cassette holds one instance each of google/gemma-3-1b and the nomic embedding model, and no token or request header. The live test passed with the token set. If the server refuses the request, the live test also skips. This third skip is beside the two of AC6, and it keeps a run with no token clean, as in the live embedding tests.
- 2026-09-28: T5 done. The help page, `pkgdown/_pkgdown.yml`, `NEWS.md`, DESIGN, and the API reference page name the function. Minor amendment: the "Malformed response" section of `rlmstudio-conditions` now counts eleven raisers and states the two new rules, because the new help page inherits that section. A second `devtools::document()` run left no diff, and `pkgdown::check_pkgdown()` found no problems.
