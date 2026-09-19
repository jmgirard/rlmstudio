# M008: Tests that fail on the branch they name

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — test-suite changes only, no exported behavior or documentation changes
- **Branch/PR:** `m008-test-discrimination`

## Goal

Close the seven recorded gaps where a test passes although the code path it names is broken.

## Scope

**In:** `tests/testthat/` only. Host assertions for all eight REST wrappers and for
`lms_unload_all()`'s forwarding. Body assertions read off the serialized request. The raw-body
fallback split by cause. The character-vector shape test and the two nothing-loaded message
assertions made able to fail. The verb assertion in `test-list.R`. The two inline `req_perform`
closures folded onto the shared recorder.

**Out:**
- Any change under `R/`. A plant that exposes a real defect becomes a candidate row or a `/hotfix`, never a fix on this branch.
- The abort-contract behavior gaps → they stay candidate rows. Those are the unbounded non-JSON message body and the TCP probe that does not make sure that the listener is LM Studio.
- The three source-grepping guard checkers → they stay candidate rows.
- CI and workflow cleanup → it stays candidate rows.

## Acceptance criteria

- [x] AC1: Every wrapper named in the `api_error_callers` list in `tests/testthat/test-api-error.R`
      is called with a non-default host. The test asserts that host on the recorded request. Two
      plants each turn `devtools::test()` red. One drops `host = host` from the `lms_unload()` call
      inside `lms_unload_all()` (`R/unload.R:104`). The other drops `host` from the `lms_client()`
      call in `list_models()`.
- [x] AC2: No test file under `tests/testthat/` reads a request body off the httr2 request object:
      `grep -rnE 'body\$data|body\[\["data"\]\]' tests/testthat/` returns no match. The
      `lms_unload()` dots test and the `lms_unload_all()` loop test read their body assertions from
      what `httr2::req_dry_run()` reports.
- [x] AC3: Two tests cover the raw-body fallback of `api_error_message()`: one whose response
      carries `Content-Type: text/plain`, one whose response carries `Content-Type:
      application/json` with a body that is not parseable JSON. Both assert the full abort message
      with `fixed = TRUE`. Plant: `api_error_message()` returning its status fallback in place of
      the body text turns both red.
- [x] AC4: The `lms_unload_all()` character-vector shape test goes red when `as.character(x)` in
      `R/unload.R` is replaced by `return(x)`.
- [x] AC5: Both `expect_message()` assertions for the nothing-loaded path in
      `tests/testthat/test-unload.R` match the message including its terminal period, with
      `fixed = TRUE`. Plant: changing that message in `R/unload.R` to "No models are currently
      loaded here." turns both red.
- [x] AC6: The `list_models()` path test in `tests/testthat/test-list.R` also asserts the HTTP
      method `GET`. Plant: adding a JSON body to the `list_models()` request, which makes httr2
      infer POST, turns it red.
- [x] AC7: No test file outside `tests/testthat/helper-mock-http.R` names `req_perform`:
      `grep -rn 'req_perform' tests/testthat/` matches that file alone. The `lms_load()` body test
      and the `lms_chat()` openresponses test obtain their fake response through
      `local_request_recorder()`.
- [x] AC8: The profile's verify slot is clean: `devtools::test()` reports 0 failures,
      `devtools::document()` produces no diff, and `devtools::check()` reports 0 errors and
      0 warnings.

## Coverage

- AC1 → T1, T2, T9
- AC2 → T1, T3, T9
- AC3 → T4, T9
- AC4 → T5, T9
- AC5 → T6, T9
- AC6 → T7, T9
- AC7 → T8, T9
- AC8 → T9

## Tasks

- [x] T1: Extend `request_target()` in `tests/testthat/helper-mock-http.R` to return the host header
      and the serialized body that `httr2::req_dry_run()` reports, beside the method and path it
      already returns. Keep the `httpuv` skip.
- [x] T2: Give each entry of `api_error_callers` in `tests/testthat/test-api-error.R` a host
      argument, and add one test looping over `names(api_error_callers)` that calls each wrapper
      with a non-default host and asserts that host on the recorded request. Add a test in
      `tests/testthat/test-unload.R` asserting that `lms_unload_all()` forwards its host to every
      `lms_unload()` request.
- [x] T3: Move the two body assertions in `tests/testthat/test-unload.R` off `req$body$data` and
      onto the serialized body from T1.
- [x] T4: Split the raw-body fallback coverage in `tests/testthat/test-unload.R` into a `text/plain`
      response and an unparseable `application/json` response.
- [x] T5: Change the character-vector shape test in `tests/testthat/test-unload.R` to feed a
      non-character vector, so the `as.character()` coercion is load-bearing.
- [x] T6: Anchor the two nothing-loaded `expect_message()` assertions in
      `tests/testthat/test-unload.R` on the full message text with `fixed = TRUE`.
- [x] T7: Add the `GET` assertion to the path test in `tests/testthat/test-list.R`.
- [x] T8: Fold the inline `req_perform` closures in `tests/testthat/test-load.R` and
      `tests/testthat/test-chat.R` onto `local_request_recorder()`.
- [x] T9: Planted-defect pass: apply each plant AC1, AC3, AC4, AC5 and AC6 name, record the result,
      revert it. Then run `devtools::test()`, `devtools::document()` and `devtools::check()` clean.

## Work log

- 2026-09-18: created by /milestone-plan.
- 2026-09-18: criteria audit ran in reduced mode (internal tier) and returned two findings, both fixed before the file was written. AC2's unprocedured "instead" clause narrowed to a two-spelling grep plus two named tests. AC7's promise narrowed to the `req_perform` token its grep enumerates.
- 2026-09-18: plan gate chose covering all eight wrappers in `api_error_callers` over covering the two unload functions alone because that list already enumerates the domain; falsified by a wrapper in the list that takes no `host` argument.
- 2026-09-18: plan gate chose reading the request through `httr2::req_dry_run()` over reading the request object's own fields because the dry run reports what goes over the wire; falsified by a CI run that skips these tests for a missing `httpuv`.
- 2026-09-18: plan gate chose folding the two inline `req_perform` closures into the shared recorder over leaving them a candidate row because D-004's own consequences name that folding; falsified by a closure whose response shape the recorder cannot produce.
- 2026-09-18: plan gate chose two raw-body tests, one per cause, over correcting the single test's content type because the parse-failure cause otherwise carries no test of its own; falsified by the two causes proving indistinguishable at the abort.
- 2026-09-18: eight criteria sits at the split tripwire and was not split, because each criterion is one small test edit inside one pull request and no part of it ships independently.
- 2026-09-18: implement gate chose a parsed list for the body `request_target()` reports, over a text string. Every request this package sends is JSON. Falsified by a wrapper that sends a body in another format.
- 2026-09-18: implement gate chose a host argument on each `api_error_callers` entry's `call`, over a second call field. One call expression per wrapper cannot drift from itself. Falsified by a wrapper the two loops must call differently.
- 2026-09-18: T1 done. `request_target()` now reports the host header and the parsed request body beside the method and path. Suite 147 pass, 0 fail, 0 skip.
- 2026-09-18: T2 done. Two host-forwarding tests added, one looping the eight wrappers and one for `lms_unload_all()`. Both plants ran early and turned red on the dropped host, reporting `localhost:1234`. Suite 150 pass, 0 fail, 0 skip.
- 2026-09-18: T3 done. The two `test-unload.R` body assertions now read the serialized body. AC2's grep still matches `test-load.R`, which T8 folds onto the recorder.
- 2026-09-18: T4 done. The raw-body fallback now has one `text/plain` test and one unparseable `application/json` test. The plant ran early. Both went red, each reporting `API Unload Failed: HTTP Status 502` in place of the body text.
- 2026-09-18: T5 done. The plain-vector shape test now feeds numbers, so the `as.character()` coercion carries the result. The plant ran early and reddened that one test alone.
- 2026-09-18: T6 done. Both nothing-loaded assertions now match the full message with `fixed = TRUE`. The plant ran early and reddened both, at `test-unload.R:147` and `test-unload.R:282`.
- 2026-09-18: T7 done. The `list_models()` path test now asserts `GET`. The plant added a JSON body to the request. The verb assertion went red at `test-list.R:17`, and the recorded-fixture test errored too, because the cassette holds no POST.
- 2026-09-18: T8 done. Both inline `req_perform` closures now go through `local_request_recorder()`. The fold exposed a fact the closure hid: `lms_load()` without `force = TRUE` sends two requests, and the closure kept only the last. The test now expects two and reads the second. AC2 and AC7 greps both hold. Suite 153 pass, 0 fail, 0 skip.
- 2026-09-18: T9 done. Planted-defect pass over the six plants the criteria name, each applied to a clean tree and reverted after its run. AC1a reddened `test-unload.R:220`. AC1b reddened `test-api-error.R:308`. AC3 reddened `test-unload.R:105` and `test-unload.R:122`, plus eight rows of the failure table. AC4 reddened `test-unload.R:270`. AC5 reddened `test-unload.R:147` and `test-unload.R:282`. AC6 reddened `test-list.R:17`, plus the recorded-fixture and end-to-end tests. Control run on the restored tree: 153 pass, 0 fail, 0 skip.
- 2026-09-18: verify slot clean. `devtools::test()` 153 pass, 0 fail, 0 skip. `devtools::document()` produced no diff. `devtools::check()` reported 0 errors, 0 warnings, 0 notes.
- 2026-09-18: claim audit: not owed — internal tier.
- 2026-09-19: review ran all eight criteria with fresh evidence, including the six plants. Consistency gate passed with one advisory, the 8-criteria split tripwire already justified above. Three-lens fan-out returned seven findings, all from the diff-bug lens: two fix-now, one recorded in the Review section, three rejected. Two candidate rows carry the deferred hardening from findings 1 and 6. No finding meets the return floor.

## Decisions

## Review

Evidence gathered 2026-09-18 on `m008-test-discrimination` at 9fa9526, with `origin/main`
an ancestor of the branch, so no sync was needed. Control run before any plant: 153 pass,
0 fail, 0 skip.

- AC1: verified. `api_error_callers` gives each of the eight wrappers a `call` that takes a
  host. `test-api-error.R:280` loops `names(api_error_callers)` and calls each wrapper with
  `http://api-error-test.invalid:9999`. It asserts that host on the recorded request.
  Plant a dropped `host = host` from the `lms_unload()` call in `lms_unload_all()`
  (`R/unload.R:143`). It reddened `test-unload.R:220`. Plant b dropped `host` from the
  `lms_client()` call in `list_models()` (`R/list.R:56`). It reddened `test-api-error.R:308`.
- AC2: verified. `grep -rnE 'body\$data|body\[\["data"\]\]' tests/testthat/` returned no
  match and exited 1. The `lms_unload()` dots test (`test-unload.R:40`) and the
  `lms_unload_all()` loop test (`test-unload.R:183`) both read their body through
  `request_target()`. That helper reports what `httr2::req_dry_run()` serialized.
- AC3: verified. `test-unload.R:95` sends a `text/plain` response. `test-unload.R:111` sends
  an `application/json` response whose body does not parse. Both assert
  `API Unload Failed: Bad Gateway, not JSON` with `fixed = TRUE`. The plant made
  `api_error_message()` return its status fallback. Both tests went red at
  `test-unload.R:105` and `test-unload.R:122`, each reporting
  `API Unload Failed: HTTP Status 502`. Eight rows of the failure table went red too.
- AC4: verified. The shape test at `test-unload.R:264` now feeds `c(101, 102)` and expects
  `c("101", "102")`. The plant replaced `as.character(x)` with `return(x)` at
  `R/unload.R:125`. It reddened `test-unload.R:270` and nothing else.
- AC5: verified. Both `expect_message()` calls now carry `fixed = TRUE` and the terminal
  period, at `test-unload.R:147` and `test-unload.R:282`. The plant changed both message
  sites in `R/unload.R` to `No models are currently loaded here.` Both assertions went red.
- AC6: verified. `test-list.R:17` asserts `target$method` equals `GET`. The plant added a
  JSON body to the `list_models()` request, which makes httr2 infer POST. The verb assertion
  went red at `test-list.R:17`. The recorded-fixture and end-to-end tests errored too,
  because no cassette holds a POST.
- AC7: verified. `grep -rn 'req_perform' tests/testthat/` matched only
  `tests/testthat/helper-mock-http.R`, on four lines. The `lms_load()` body test
  (`test-load.R:11`) and the `lms_chat()` openresponses test (`test-chat.R:91`) both obtain
  their fake response through `local_request_recorder()`.
- AC8: verified on the restored tree. `devtools::test()` reported 153 pass, 0 fail, 0 skip.
  `devtools::document()` left the working tree clean. `devtools::check()` reported 0 errors,
  0 warnings and 0 notes, in 5 minutes 14 seconds.

### Consistency gate

`cairn_validate.py` exited 0 with all checks passing. One advisory fired: M008 carries 8
acceptance criteria, above the 7 tripwire. The work log already records why the milestone was
not split. No principle changed, so `cairn_impact.py` was not run.

Toolchain checks from the profile, in order. `devtools::document()` produced no diff.
`devtools::check()` reported 0 errors, 0 warnings and 0 notes. `pkgdown::check_pkgdown()`
found no problems. README.md is not behind README.Rmd. The branch adds no top-level file.
Because the branch changes no user-visible behavior, NEWS.md gets no entry.

### Independent review

The diff touches executable test files, so the full three-lens fan-out ran. Each reviewer had
a fresh context and a distinct evidence base. The first diff-bug reviewer stalled and was
respawned.

- Blame-history lens: no findings. It confirmed that the `test-load.R` fold reads request 2
  because `lms_load()` without `force = TRUE` calls `list_models()` first. The old inline
  closure had overwritten the first request. It noted one unverified comment claim in
  `helper-mock-http.R`, that every request this package sends carries a JSON body.
- Prior-review lens: no findings. It reported that the branch resolves the one directly
  applicable prior point, D-004's unsanctioned inline closures. The GitHub inline-comment
  probe returned an empty list, so the thread walk was skipped.
- Diff-bug lens: seven findings, ranked below with their dispositions.

#### Findings and dispositions

1. The `httpuv` skip empties the body and host assertions on a machine without that package.
   `helper-mock-http.R:76` calls `skip_if_not_installed("httpuv")`. Before this branch the
   body assertions read `req$body$data` and needed no suggested package.
   **Rejected.** D-005 decided this and named the consequence. A contributor without `httpuv`
   sees skips rather than failures. The CI wait at the merge gate is what settles green.
   `httpuv` is in Suggests and `setup-r-dependencies` installs Suggests, so CI runs these
   tests. A candidate row carries the hardening idea. When the `CI` environment variable is
   set, the helper fails rather than skips.
2. The integer half of `test-load.R`'s named contract does not discriminate. The test is
   called "builds body with correct integer/logical conversions". The body now returns
   through `jsonlite::fromJSON()`, and JSON has no integer type. Verified here: a double
   `2048` round-trips back as an integer, and `expect_equal(2048, 2048L)` passes in edition 3.
   Dropping `as.integer()` at `R/load.R:87` leaves the test green.
   **Fix now.** Feed `context_length = 2048.7` and keep the `2048L` expectation. Only the
   coercion can produce that value.
3. AC3's two raw-body tests reach one package branch, not two. Verified here: a `text/plain`
   body and an unparseable `application/json` body both make `resp_body_json()` throw. Both
   then land at `parsed <- NULL` and take the same final line of `api_error_message()`. No
   package defect can redden one without the other.
   **Recorded, no code change.** AC3 as written is met. It promises two tests with those
   content types, the full message with `fixed = TRUE`, and one plant that reddens both.
   The Scope line "split by cause" claims more than the package distinguishes. The second
   test guards httr2's content-type behavior rather than a package branch.
4. The host loop reads only the first recorded request. `test-api-error.R:296` reads
   `recorder$requests[[1]]`. Every wrapper sends one request under this mock today, so the
   read is correct now. A wrapper that later sends a correct-host request before a wrong-host
   one still passes.
   **Fix now.** Assert the host on every recorded request instead of the first.
5. `test-load.R:27` asserts a request count that the body test does not care about.
   **Rejected.** The length check is what makes the `requests[[2]]` read legible. Without it a
   changed call pattern gives a subscript error rather than a named failure.
6. `request_target()` parses the body with no guard. A request whose body is not JSON
   surfaces a raw `jsonlite` error from the helper.
   **Follow-up.** No wrapper sends a non-JSON body today. A candidate row carries it.
7. The acceptance-criteria boxes were unticked while every task was ticked.
   **Rejected as stale.** The reviewer read the committed head. This review ticked each box
   against its evidence line above.
