# M050: A table of loaded model instances

- **Status:** review
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

- [x] AC1: `list_instances()` is exported. It sends one `GET api/v1/models` request. It returns a data frame with one
      row for each entry of `loaded_instances`. Only models whose `type` is in its `type` argument count, and the
      default is `c("llm", "embedding")`. Rows follow the order of the models in the reply, then the order of the
      instances in a model. A duplicate instance id or model key gives separate rows. The first four columns are
      `id`, `key`, `type`, and `display_name`, in that order, all character. The `id` is the `id` of the instance,
      and the other three come from its model. A test uses a mocked reply with four models. The first has two
      instances, and the second has none. The third has an instance and a type outside `type`. The fourth has one
      instance. The test asserts the rows and every cell of the four columns.
- [x] AC2: After the four columns, the frame has one column for each field name in the `config` object of a returned
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
- [x] AC3: The function can have no instance to return. There are three cases: the reply has no models, no model has
      an instance, or no model with an instance has a type in `type`. In each case, the function returns a data
      frame with zero rows and the four character columns of AC1, invisibly. It also prints a message through
      `rlm_inform()`. If `quiet = TRUE` or the `rlmstudio.quiet` option is `TRUE`, it prints no message. Tests
      assert the column names and types, the zero rows, and the message, for each of the three cases. Tests also
      assert that each of the two quiet values stops the message.
- [x] AC4: The function checks the body through `request_model_list()`. It so aborts with `rlmstudio_bad_response`
      on each body that `model_list_fault()` rejects. It also aborts with that class on two faults in a model entry
      whose `type` is in `type` and that has at least one instance. One fault is a `display_name` that is present,
      not `null`, and not a string. The other is an instance `config` that is present, not `null`, and not a JSON
      object. An absent or `null` `display_name` gives `NA`. An absent or `null` `config` gives `NA` in every
      configuration column. The message names the field and its entry. Tests fire each of the two new faults and one fault of
      `model_list_fault()`. They assert the class and the field that the message names. The two new checks live in
      `list_instances()` alone. `model_list_fault()` and `request_model_list()` do not change, so `list_models()`
      and `lms_server_ready()` accept the same bodies as before. The files `tests/testthat/test-list.R`,
      `test-model-list-shape.R`, and `test-server-ready.R` pass with no edit.
- [x] AC5: If the server does not answer, the function aborts with `rlmstudio_no_server` and sends no HTTP request.
      A reply with a status other than 200 aborts with `rlmstudio_api_error`. Its `status` field holds that status.
      The request carries the token that `token` resolves as a bearer header. Tests assert each class and the
      `status` field. The token-wrapper table in `tests/testthat/test-token-wrappers.R` asserts the header.
- [x] AC6: A reply recorded from the live model list under `tests/testthat/list_instances/` backs a test that runs
      without a server. The reply holds google/gemma-3-1b and an embedding model, each with one loaded instance. The
      test asserts one row per loaded instance and the `context_length` value of each row. A live test asserts that
      the `id` column equals the instance ids that `list_models(detailed = TRUE)` returns, in the same order. If no
      server answers, the `tests/testthat/helper-skips.R` helpers skip it. If no model is loaded, it skips. It
      loads and unloads nothing.
- [x] AC7: The help page states the columns of AC1, the column rules of AC2, and the empty result of AC3. It inherits
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
- [x] T6: Run `devtools::test()`, then `devtools::check()` with `RLMSTUDIO_API_TOKEN` set, and fix what they report.

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
- 2026-09-28: T6 done. With `RLMSTUDIO_API_TOKEN` set, `devtools::test()` gave 0 failures, 0 warnings, and 0 skips. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. Nothing needed a fix.
- 2026-09-28: claim audit: 55 claims read, 3 corrected — R/conditions.R, tests/testthat/test-list-instances.R, data-raw/record-list-instances-cassette.R
- 2026-09-28: the claim audit reader verified its two open items on its re-read. `lms ps --json` reports `status`, `queued`, `ttlMs`, and `lastUsedTime`, and the recording has none of them. The installed LM Studio is 0.4.25+1. The last suite run after the fixes gave 0 failures, with three live tests skipped because the server had stopped.
- 2026-09-28: review evidence recorded for AC1 to AC7 and the consistency gate passed. The three fresh reviewers are running, so their findings are not triaged yet.

## Review

Evidence gathered 2026-09-28 on `m050-list-instances` at 909b7fd. Its merge base is `origin/main` (417e480), so no
sync merge was needed. The run of `devtools::test()` with the token set and the server started gave 13549 expectations,
0 failures, 0 warnings, and 0 skips. In it, `test-list-instances.R` ran 20 tests with 0 failures and 0 skips.

- AC1: `NAMESPACE` has `export(list_instances)`. Two tests over the four-model body pass. They assert one GET to
  `/api/v1/models` and the names `id`, `key`, `type`, `display_name` in that order. They assert every cell of the four
  columns as character vectors. The ids are `i1`, `i1`, `i4`, so the duplicate id and the duplicate key `m1` give
  separate rows. The model with no instance and the `other` model give no row.
- AC2: Six tests pass. They cover the order of first appearance and the four atomic kinds, with `typeof` double for
  8192 and a `null` string that becomes `NA`. They cover a field of only `null` values that gives a logical `NA`
  column, and a field in one instance only. They cover a `config` of `{}` and an absent `config`. An object, an array, and a
  number, string, and boolean in one field give list-columns, with `NULL` cells for the absent and the `null` value.
  The name cases are `a-b` kept as is, `id` that becomes `config.id`, and `config.id` beside `id` in both orders. The
  last two are an empty name that becomes `config.`, and two equal keys where the first counts.
- AC3: Two tests loop over the three empty bodies: no models, no instances, and no instance of a listed type. For
  each body they assert zero rows, the four column names, a `character()` value in each column, and an invisible
  value. They assert the "No loaded model instances" message with the option unset. They assert no message under
  `quiet = TRUE` and under the `rlmstudio.quiet` option.
- AC4: Tests fire a `display_name` in each non-string JSON form and a `config` in each non-object form. They fire
  `{"models": {}}` for `model_list_fault()`. Each asserts `rlmstudio_bad_response`, status 200, and the field and
  entry in the message. A further test shows that both checks skip a model outside `type` and a model with no
  instance. Another shows that an absent or `null` `display_name` or `config` gives `NA`. The diff on `R/list.R`
  has 253 added lines and 0 removed, so `request_model_list()` and `model_list_fault()` do not change. The files
  `test-list.R`, `test-model-list-shape.R`, and `test-server-ready.R` have no diff against `origin/main` and pass.
- AC5: With no server, `list_instances()` aborts with `rlmstudio_no_server` under `local_no_request_allowed()`. A
  status of 500 aborts with `rlmstudio_api_error` whose `status` is `500L`. The token-wrapper table in
  `test-token-wrappers.R` lists `list_instances` with one request, and its tests pass. The fifteen-name set test
  passes too.
- AC6: The recording is `tests/testthat/list_instances/localhost-1234/api/v1/models.json`. Its test clears both token
  sources and passes. It asserts the ids `google/gemma-3-1b` and `text-embedding-nomic-embed-text-v1.5`, the types,
  and `context_length` 8192 and 2048. The live test ran and passed in the `devtools::test()` run above, with 0 skips.
  It calls `skip_if_no_server()`, skips with no loaded model, and loads or unloads nothing. Under `devtools::check()`
  it skipped with "LM Studio local server is not running", which AC6 allows.
- AC7: `man/list_instances.Rd` has a Columns section with the four columns, the AC2 name and type rules, and a
  return value with the empty result. It also has the sections Server not running, API failure, and Malformed
  response. `pkgdown/_pkgdown.yml` lists `list_instances` after `list_models`. `NEWS.md`, the DESIGN function
  families, and item 6 of the API reference page name it. `devtools::document()` left `git status` clean, and
  `pkgdown::check_pkgdown()` found no problems. `devtools::test()` gave 0 failures and 0 warnings, as above. The
  first `devtools::check()` run gave 1 error, a test failure in `test-ttl.R` at `rawToChar(out$body)` inside
  `httr2::req_dry_run()`. That file is not in this diff. A second run gave 0 errors, 0 warnings, and 0 notes. Fifteen
  more runs of `test-ttl.R` gave 0 failures.

Consistency gate: `cairn_validate.py` passed with exit 0. No DESIGN principle changed, so `cairn_impact` did not run.
`devtools::document()` gave no diff, and `pkgdown::check_pkgdown()` passed. The branch does not touch `README.Rmd` or
`README.md`. `NEWS.md` has the entry and no milestone number. The branch adds no top-level file. The check gave 0
notes.

Independent review: three fresh reviewers ran on 2026-09-28. The [O] reviewer read the diff, the [S] history reviewer
read `git blame`, and the [S] prior-review reviewer read the archives. The `gh` comment probe returned `[]`. Each
finding below is ranked by its own reviewer. I read the code for the findings marked "seen in code". Dispositions
are set at the merge gate.

- O1 `R/list.R:277-283`: the column of a `config` field depends on the fields before it in all rows. With `{"id":1}`
  and `{"config.id":2}`, the server field `config.id` lands in `config.config.id`. With only the second instance, it
  lands in `config.id`. AC2 asks for this behavior.
- O2 `R/list.R:216-257`: `type` and `quiet` get no argument guard. `quiet = NA` fails with a base error after the request.
  An empty `type` prints a message with no type. `type = 1` returns an empty frame. `list_models()` does the same.
- O3 `test-list-instances.R:253-292`: the two new fault tests do not assert the fault text ("is not a string", "is
  not a JSON object"), which the M026 lesson asks for.
- O4 `test-list-instances.R:200-215`: no test mixes only a number and a string, and no test covers `type = NA`, an
  empty `type`, or `display_name = ""`. The reviewer ran each case and found correct results.
- O5 `NEWS.md`: the entry leaves out "of a listed type" and the `quiet` rule for the empty result. The help page
  has both.
- O6 `R/list.R:374-381`: atomic number columns are doubles, but a list-column keeps `1L` as an integer. The help page
  says so.
- O7 AC4 text: it says an absent or `null` `config` gives `NA` in every configuration column. A list-column holds
  `NULL` there, as AC2 and the help page say. Seen in code: the AC4 clause as written fails for a list-column.
- O8 the fixture holds the full local model catalog, not only the two loaded models. Nothing secret is in it.
- S1 `R/conditions.R:30-43`: the "Server not running" section lists the raisers of `rlmstudio_bad_response` for a
  non-JSON body and for a wrong model list. It names `list_models()` and omits `list_instances()` in both. Seen in code.
- S2 `R/conditions.R:96-105`: the new `lms_chat_batch()` sentence repairs an M049 omission, beyond this scope. It is
  accurate. Line 97 is wider than the wrapping around it.
- S3 `R/list.R:246-256`: the empty message is an `"i"` bullet, and `list_models()` uses `"!"` for a filter that
  matches nothing.
- S4 D-017: `list_instances()` now rejects bodies that `lms_server_ready()` accepts. The help page states it, and no
  D-entry records it.
- S5 `R/list.R`: the `list_models()` help page has no `@seealso` link to `list_instances()`.
- S6 `R/utils-api-error.R:177`: an internal comment lists four callers of `rlm_abort_bad_reply()`, and
  `list_instances()` is a fifth.
- P1 `tests/testthat/test-api-error.R:139`: `list_instances` is not in `api_error_callers`. So it gets neither the
  400 and 503 rows nor the host-forwarding test. If the call drops `host`, no test turns red. Seen in code.
- P2 `test-list-instances.R:343`: no 401 or 403 token-hint test. The hint goes through `request_model_list()`, which
  `test-token-rejected.R` covers through `list_models()`.
- Flaky test: the first `devtools::check()` failed once in `test-ttl.R`, which this branch does not touch.
