<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M026: A model list with the wrong JSON shape aborts with rlmstudio_bad_response

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP2, GP5   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing, because three exported functions change what they accept and raise   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m026-model-list-shape   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`list_models()`, `lms_unload_all()`, and `lms_server_ready()` read a status-200
model list through one shape check.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** One check of the model-list body against rules L1 to L4 below. It runs
on a parse with `simplifyVector = FALSE`, before any filter or data frame.
`list_models()` calls it. `lms_server_ready()` calls it in place of
`is_model_list()` (`R/serve.R:702`). `lms_unload_all()` reads each instance
by its `id` alone. The crash on `{"models": []}` goes. Help page and NEWS.

Words used below. A JSON string is one JSON string value, and a number is
one JSON number. A field is present only under its exact name. A field whose
name extends it, such as `keyX` for `key`, does not make it present.

Background. On 2026-09-22 a mocked `{}` gave an empty data frame, and
`{"modelsX": [...]}` was read as the model list. `{"models": []}`, the reply
of a server with no models, gave "missing value where TRUE/FALSE needed".

**Out:**
- The load, download, and download-status replies. That work is M027.
- A `"failed"` status in the reply of `lms_download()`. That work is a new
  candidate row.
- Fields that no rule names, such as `display_name`. They come as they are.
- The loaded-instance table. That work stays in its candidate row.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: `list_models()` reads a status-200 body under four rules. L1: the
      body is a JSON object whose `models` is an array. L2: each entry of
      `models` is a JSON object. Its `type` and `key` are JSON strings, and
      its `loaded_instances` is an array. L3: the `size_bytes` of an entry is
      a number, or absent, or `null`. L4: each entry of `loaded_instances` is
      a JSON object whose `id` is a JSON string with a character that is not
      whitespace. A body that breaks a rule
      aborts with `rlmstudio_bad_response`, also for an entry that the `type`
      or `loaded` filter drops. The condition's `status` is `200L`. The
      first line of the message holds `API List Failed`. The message names the
      field that broke the rule, or the array whose entry broke it, or it says
      that the body is not a JSON object. It does not contain `simplify`.
- [ ] AC2: A test pins each rule of AC1 with one body per fault, and each body
      breaks one rule. Take each of `models`, `type`, `key`,
      `loaded_instances`, and `id`. Its faults are the field absent, `null`,
      and under a name that extends it. The field as each other type from
      number, string, boolean, array, and object is a fault too. An array
      fault is `[]` and `["a"]`, and an object fault is `{}` and `{"a": 1}`.
      `id` as `""` and as `" "` is a fault. For
      `size_bytes`, absent, `null`, and an extended name each pass, and each
      other type fails. An entry of `models` or of
      `loaded_instances` that is a string, number, boolean, `null`, or array
      is a fault too. Each L2 and L3 fault and each non-object entry of
      `models` sits in the only entry, in the first of two entries, and in the
      second after a valid entry. Each L4 fault sits in the same three places
      among the instances. It also sits inside the only model, the first of
      two models, and the second after a valid model. The body as a JSON
      array, string, number, boolean, and `null` is a fault. One fault entry
      has type `"embedding"` under `type = "llm"`, and one is unloaded under
      `loaded = TRUE`.
- [ ] AC3: `{"models": []}` makes `list_models()` return
      `invisible(data.frame())`, and unless `quiet` it informs "No models
      found on host". With that body, `lms_unload_all()` informs "No models
      are currently loaded", and `lms_load()` without `force` sends the load
      request. A test pins each of the three.
- [ ] AC4: If the model-list body breaks a rule of AC1, `lms_load()` without
      `force` and `lms_unload_all()` abort with `rlmstudio_bad_response`. The
      message holds `API List Failed`, and no request goes out after the model
      list. A test pins each of the two.
- [ ] AC5: `lms_unload_all()` unloads each loaded instance by its `id`. A test
      with two loaded models, one with two instances, asserts that
      `lms_unload()` runs three times. Its `model` arguments are the three ids
      in body order.
- [ ] AC6: `lms_server_ready()` returns `TRUE` for a status-200 body that
      passes L1 to L4, and `FALSE` for each fault body of AC2. A test runs it
      over the AC2 bodies. The example response of the LM Studio list docs
      (lmstudio-ai/docs, `1_developer/2_rest/list.md`, "Response" block) and
      the fixture in `tests/testthat/list_models/` pass L1 to L4. A test
      asserts the `list_models()` return for the docs example. The existing
      tests pass. An existing test changes only where its body breaks L1 to
      L4, or where it pins the fallback chain that AC5 removes.
- [ ] AC7: The `rlmstudio-conditions` help page names three raisers of
      `rlmstudio_bad_response` for a model list with the wrong shape. They are
      `list_models()`, `lms_unload_all()`, and `lms_load()` without `force`.
      It says that `lms_server_ready()` applies the same rules. It no longer says that
      `list_models()` can fail with an unclassed error for such a body.
      NEWS.md has an entry for AC1, AC3, AC5, and AC6. `devtools::test()` is
      clean, and `devtools::document()` produces no diff.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1
- AC2 → T1
- AC3 → T1, T2
- AC4 → T2
- AC5 → T2
- AC6 → T1, T3
- AC7 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: Shape check. Tests first, in a new test file. Add a helper in
      `R/list.R` that takes the parse with `simplifyVector = FALSE` and returns
      the first broken rule, or nothing. `list_models()` (`R/list.R:69-76`)
      parses the body through `parse_json_body()` without simplification and
      runs the check. It then parses again with `simplifyVector = TRUE` to
      build the data frame. Read every field with `[[` (LESSONS, M018).
      Abort through `rlm_abort_bad_response()` with a hint that does not name
      `simplify`. Write the AC1, AC2, AC3, and AC6 `list_models()` tests.
      Fix the existing bodies that break L1 to L4, such as `{}` at
      `test-list.R:8`, the load test's list reply at `test-load.R:14`, and
      the `identifier` instances at `test-token-wrappers.R:16`. Record each
      edited test in the work log.
- [x] T2: Callers. `lms_unload_all()` (`R/unload.R:124-148`) reads `id` and
      drops the fallback chain. Delete the tests of that chain in
      `test-unload.R:159-292` and record them in the work log. Write the AC3,
      AC4, and AC5 tests. Mock out
      the delegate, so that each test goes red without its call site
      (LESSONS, M003).
      `lms_load()` without `force` sends two requests (LESSONS, M008).
- [x] T3: `lms_server_ready()` (`R/serve.R:667`) calls the T1 check and
      `is_model_list()` goes. Write the AC6 server-ready tests. Fix the
      entries with no `loaded_instances` at `test-server-ready.R:100` and
      `:131` and at `test-body-parse.R:261`.
- [x] T4: Docs. Rewrite the "Server not running" and "Malformed response"
      sections of `R/conditions.R` (`:26-39`, `:64-79`). Update the
      `lms_server_ready()` help text on what counts as a model list. Add the
      NEWS entries. Run `devtools::document()` and `devtools::test()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-22: created by /milestone-plan.
- 2026-09-22: criteria audit, full mode, fresh [O] reader, on one draft for both M026 and M027. It found 12 gaps. Nine were fixed in the criteria. A check on the simplified data frame misses a fault after the first entry. Optional fields had no pass cases. The message label, a boolean top-level body, non-object entries, and the list docs example were missing. Three went to the gate: the instance `id` rule, `lms_server_ready()`, and the `"failed"` download status.
- 2026-09-22: plan gate chose to fold the `{"models": []}` crash into M026 over a separate hotfix. The same lines of `R/list.R` change. Falsified by a user report of the crash before M026 ships.
- 2026-09-22: plan gate chose an `id` rule for loaded instances over a candidate row. `lms_unload_all()` then reads the documented field alone. Falsified by a live server whose instance entries carry `identifier` and no `id`.
- 2026-09-22: plan gate chose one check for `list_models()` and `lms_server_ready()` over a candidate row. One body then has one rule set, as D-016 chose for the parse. Falsified by a live LM Studio model list that fails L1 to L4.
- 2026-09-22: criteria re-audit, full mode, second fresh [O] reader, after the gate changed the criteria. It found 12 gaps across M026 and M027, all fixed in the criteria. The claim that existing tests pass unchanged was false for eight tests. An `id` of `""` passed L4 and then broke `lms_unload()`. The places of L4 faults, the forms of array and object faults, and the reading of the message rule were unclear. AC4 did not forbid a request after the model list, and AC5 said "nothing else" over an open domain.
- 2026-09-22: plan chose to reject an empty or blank instance `id` over a silent skip, the old behavior. A skip hides a server fault, and M026 rejects every other bad field. Falsified by a live server that reports a loaded instance with an empty `id`.
- 2026-09-22: plan chose to split the draft into M026 and M027 over one milestone. The draft had 11 criteria, and the model-list work ships alone. Falsified by a merge conflict between the two that costs more than one review.
- 2026-09-22: T1 and T3 done in one commit, because the new tests in `test-model-list-shape.R` drive `lms_server_ready()` over the same bodies. `model_list_fault()` in `R/list.R` checks the unsimplified parse, `list_models()` parses a second time with `simplifyVector = TRUE`, and `lms_server_ready()` calls the check in place of `is_model_list()`. The docs example is saved as `tests/testthat/fixtures/list-docs-example.json` (lmstudio-ai/docs commit 2e643a417b). With the call site replaced by `fault <- NULL`, the new tests fail.
- 2026-09-22: existing tests edited because their bodies break L1 to L4: `test-list.R` (GET test, `{}` to `{"models": []}`), `test-load.R` (integer conversion test, a list reply and a load reply in sequence), `test-token-wrappers.R` (`identifier` to `id`), `test-server-ready.R` (three tests, `loaded_instances` added), and `test-body-parse.R` (text/plain server-ready test, `loaded_instances` added). `devtools::test()`: 0 failures, 8377 passes.
- 2026-09-22: T2 done. `lms_unload_all()` reads `x[["id"]]` and the fallback chain is gone. Deleted from `test-unload.R`: the `identifier` column test, the first-column fallback test, the number coercion test, and the two NA and empty-id tests. Two unload tests now use an `id` column. With the `list_models()` pre-check in `lms_load()` removed, or with `lms_unload_all()` reading the first field, the new caller tests fail. `devtools::test()`: 0 failures, 8384 passes.
- 2026-09-22: T4 done. `R/conditions.R` states the four rules in "Malformed response" and names the three raisers in "Server not running". `lms_server_ready()` help says it applies the `list_models()` rules. NEWS.md has four entries. `devtools::document()` is stable on a second run, and `devtools::test()`: 0 failures, 8384 passes.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
