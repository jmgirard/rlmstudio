# M012: The package can turn text into embedding vectors

- **Status:** review
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP1, GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — a new exported function and a new condition class
- **Branch/PR:** `m012-embeddings-wrapper`

## Goal

Wrap `POST /v1/embeddings` as `lms_embed()`, returning one embedding row per input text.

## Scope

**In:** `lms_embed()` over `POST /v1/embeddings`; a double matrix return under
`simplify = TRUE`; a validator over the response `data` block with its own
condition class; the `token` argument; a recorded fixture for the happy path;
help pages, `NEWS.md`, the pkgdown index, and the API surface reference row.

**Out:** chunking and a progress bar over a long input vector → candidate row.
Named `dimensions` and `encoding_format` arguments → reachable through `...`
under GP4. `/v1/completions`, `/v1/models`, and `/v1/messages` → they stay
uncovered rows in `cairn/references/lmstudio-api-surface.md`. Structured output
on `/v1/chat/completions` → the existing candidate row.

## Acceptance criteria

- [x] AC1: `lms_embed()` is exported and documented. A call with a character
      vector of n inputs, passing no `model` or `input` through `...`, sends
      exactly one HTTP request: a POST to the `v1/embeddings` path of `host`,
      whose JSON body carries `model` and an `input` array holding those n
      strings in the order given. At n = 1 the body carries a one-element
      array and not a bare string.
- [x] AC2: With `simplify = TRUE` (the default), on a response whose `data`
      block holds one element per input, each carrying a whole unique `index`
      in 0 to n-1 and an `embedding` list of numbers of one common length d,
      `lms_embed()` returns a double matrix of n rows and d columns that
      carries no row or column names, and the row at position i holds the
      numbers of the element whose `index` is i-1. Checked at n = 1; at n = 2
      in arrival orders 0-1 and 1-0; and at n = 3 in arrival orders 0-1-2 and
      2-0-1. Evidence: a cassette recorded from a live server for the n = 3
      in-order case at 768 dimensions, from
      `text-embedding-nomic-embed-text-v1.5`; a recorder test for each of the
      five cases over a hand-built response of five fractional dimensions,
      each asserting the row values, both dimensions, the storage mode, and
      the absent names; and the AC6 control that the check stays silent on a
      block it accepts.
- [x] AC3: With `simplify = FALSE`, `lms_embed()` returns the parsed response
      body unchanged, identical to what `httr2::resp_body_json()` produced for
      that body, and runs none of the AC6 checks: a body AC6 rejects still
      returns under `simplify = FALSE`.
- [x] AC4: `lms_embed()` aborts with condition class `rlmstudio_no_server` when
      the server check fails, and with class `rlmstudio_api_error` carrying an
      integer `status` field at the statuses the failure test sends, which are
      400 and 503.
- [x] AC5: `lms_embed()` takes a `token` argument positioned after `...`. Every
      request it issues carries an `Authorization: Bearer <token>` header when
      a token resolves from the argument, the `rlmstudio.token` option, or the
      `RLMSTUDIO_API_TOKEN` environment variable, and carries no
      `Authorization` header when none of the three holds a value.
- [x] AC6: Before building the matrix, `lms_embed()` checks the response `data`
      block: one element per input, each carrying an `index` that is a whole
      number, unique, and within 0 to n-1, and an `embedding` that is a list of
      numbers, every one of the same length. A block failing any condition
      aborts with condition class `rlmstudio_bad_response`, a `status` field
      holding the response status as an integer, and a message naming
      `simplify = FALSE`. Evidence: one recorder test per probe — a base64
      string embedding, a `NULL` embedding, an embedding list holding a
      non-number, three elements whose middle one is a different length, a
      missing `index`, a fractional `index`, a duplicated `index`, an `index`
      of -1, an `index` of n, a `data` block shorter than the input vector,
      and one longer.
- [x] AC7: When `input` is supplied and holds `1:3`, `list("a")`, `NULL`, or
      `character(0)`, `lms_embed()` aborts with the message
      "`input` must be a non-empty character vector." Evidence: four probes in
      one test in `tests/testthat/test-embed.R`, each supplying one of those
      values and matching that whole sentence with `fixed = TRUE`.
- [x] AC8: `rlmstudio_bad_response` has its own section and alias on the
      `rlmstudio-conditions` help page, and that section is inherited onto the
      `lms_embed()` help page.
- [x] AC9: The `verify` slot of `cairn/PROFILE.md` is clean: `devtools::document()`
      produces no diff and `devtools::test()` passes.

## Coverage

- AC1 → T1, T4, T12
- AC2 → T1, T2, T4, T5
- AC3 → T1, T4
- AC4 → T1, T4, T9
- AC5 → T1, T4, T6
- AC6 → T2, T4, T8
- AC7 → T1, T4, T11
- AC8 → T3
- AC9 → T3, T4

## Tasks

- [x] T1: Write `R/embed.R`:
      `lms_embed(model, input, host, simplify = TRUE, ..., token = NULL)`,
      following `lms_chat_openresponses()` at `R/chat.R:123`. Input check,
      `stop_if_no_server()`, a body merged with `...`, POST through
      `lms_client()`, a non-200 to `rlm_abort_api()`.
- [x] T2: Write the `data`-block validator and the matrix assembly, raising
      `rlmstudio_bad_response` from a new helper in `R/utils-api-error.R`.
      Each embedding arrives as a list (LESSONS, M005), so coerce per element.
- [x] T3: Add the third `@section` and `@aliases` entry to `R/conditions.R`
      and the `@inheritSection` tags to `lms_embed()`. The tag stays on one
      line and the title matches character for character (LESSONS, M007).
- [x] T4: Write `tests/testthat/test-embed.R` against
      `local_request_recorder()`: the request shape, the permutations,
      `simplify = FALSE`, both condition classes, the AC6 probes, and the
      input contract.
- [x] T5: Record the happy-path cassette from a live server, with a
      `data-raw/` generator carrying its provenance per `cairn/PROFILE.md`.
- [x] T6: Add `lms_embed` to the token wrapper table and take its name list
      from twelve to thirteen.
- [x] T7: Add `lms_embed` to `pkgdown/_pkgdown.yml`, write the `NEWS.md`
      entries, and replace the "No wrapper exists" note on the
      `/v1/embeddings` row of the API surface page.
- [x] T8: Repair the response check on the two returned failures. Read every
      field by exact name, and guard the body and each element on being a JSON
      object. Also reject a `data` block sent as an object, give an empty
      embedding its own clause, and drop the dead `dimnames()` line.
- [x] T9: Add an `lms_embed` row to the shared failure-message table, so the
      wrapper runs every body shape at both statuses like the other eight.
- [x] T10: Correct the two `...` examples on the help page. Make the
      live-cassette test clear both token sources.
- [x] T11: Amend AC7 through the gate and record the `NA` input case as a
      candidate row. Change the four input probes to match the whole abort
      sentence, so the sibling's pattern no longer passes them.
- [x] T12: Send a named `input` vector as a JSON array. `as.list()` keeps the
      names and jsonlite writes a named list as an object, so the fix is
      `unname()`. Probe at n = 1 and n = 2 by reading the names off the sent
      body, because `is.list()` cannot tell an array from an object.
- [x] T13: Guard the body parse. A 200 that is not JSON raises an unclassed
      error from `resp_body_json()`. Catch it and abort with the class. Give
      the helper a `hint` argument, because the parse runs before the
      `simplify` branch and the standing advice cannot help.
- [x] T14: Read the input count by exact name. Split the misdescribing clause,
      so a `data` block of the wrong JSON type says so. Name the changelog's
      two missing faults. Make the cassette generator state its prerequisites.
- [x] T15: Record the unguarded `model` argument as a candidate row covering
      this wrapper and its siblings together.

## Work log

- 2026-09-20: created by /milestone-plan.
- 2026-09-20: plan criteria audit ran in full mode (user-facing tier) and returned fifteen findings. Eleven were fixed here: the n=1 auto_unbox case, the `...` override of `model` and `input`, AC2's unenumerable "whatever order", AC4's internal-call-site clause and its sweep over every non-200 status, AC5's missing negative case, AC7's pkgdown row as an instrument-bound promise, the stale twelve-name table, and three missing record updates. Four went to the question gate as the malformed-response question.
- 2026-09-20: a second audit pass over the two criteria the gate changed returned twelve more findings, and all were fixed here: the `rlm_abort_api()` blocker, n=1 and d≠n in the AC2 probes, fractional fixture values, D-004 routing for the happy path, five unprobed AC6 conditions, the middle-element ragged probe, and AC3's silence on whether `simplify = FALSE` runs the checks.
- 2026-09-20: plan gate chose a numeric matrix return over a data.frame with an embedding list-column and over a list of numeric vectors, because GP2 makes the scripted batch win ties and a matrix feeds `dist()` and `prcomp()` with no reshaping; falsified by a user report that the input text must travel beside the vector.
- 2026-09-20: plan gate chose one request for the whole input vector over a `chunk_size` argument with a progress bar, because the endpoint takes an array natively and chunking adds a second request-assembly path; falsified by a payload or context limit hit on a real corpus.
- 2026-09-20: plan gate chose a single classed validator over a numbers-only check and over no guard, because base64 is one member of a family that also holds ragged and misindexed blocks, and a silently misaligned matrix corrupts a batch run; falsified by a live server producing a `data` block the validator rejects.
- 2026-09-20: step 4 chose a new `rlmstudio_bad_response` class over reusing `rlmstudio_api_error` and over a bespoke unclassed abort, because `rlm_abort_api()` on an HTTP 200 returns the whole body as the message (LESSONS, M006) and cannot carry the `simplify = FALSE` guidance, and because a `status` field fixed at 200 tells a catching user nothing; falsified by a second malformed-body site wanting different handling. Recorded as D-007.
- 2026-09-20: implement gate made three choices. The happy-path cassette is recorded live this session. The returned matrix carries no row or column names. The `data` block count runs against the input array the request sent, not against the `input` argument. An override through `...` therefore stays under the same guard.
- 2026-09-20: minor amendment. T1 and T2 land in one checkpoint commit. The wrapper does not run until the matrix builder exists, so T1 alone cannot pass the `verify` slot.
- 2026-09-20: T1 and T2 done. `R/embed.R` holds `lms_embed()`, `is_one_number()`, and `embed_matrix()`. `rlm_abort_bad_response()` sits beside `rlm_abort_api()` in `R/utils-api-error.R`. The `verify` slot ran clean: document() wrote NAMESPACE and lms_embed.Rd, test() gave 315 pass and 0 fail.
- 2026-09-20: T3 done. `R/conditions.R` gained a "Malformed response" section and the `rlmstudio_bad_response` alias, and the tag lands that section on the `lms_embed()` page. Both `.Rd` files carry it once. The `verify` slot ran clean.
- 2026-09-20: T4 done. `tests/testthat/test-embed.R` runs 84 expectations. Writing it found two defects. The detail clause reached the user with its cli braces intact. cli does not interpolate a value spliced into a message, so `embed_matrix()` now formats the clause in its own frame. The gate answer about counting the sent inputs rests on a false premise: `input` is a formal argument, so R rejects a call naming it twice and the dots can never override it. The body-derived count is kept as the safer read and a test now pins the R behavior.
- 2026-09-20: check discrimination for T4. Planted `input = input` in place of `as.list(input)` and the single-input array test went red. Planted `out[i, ]` in place of the index placement and the three permutation expectations went red. Both were restored and the suite is green at 399 pass and 0 fail.
- 2026-09-20: T6 and T7 done. The token wrapper table now carries `lms_embed` and the name list runs to thirteen. `_pkgdown.yml` gained an Embeddings title, `NEWS.md` gained three entries in user-facing words, and the `/v1/embeddings` row of the API surface page now names the wrapper. `pkgdown::check_pkgdown()` found no problems and the suite gave 405 pass and 0 fail.
- 2026-09-20: T5 done. The cassette in `tests/testthat/embed_live/` was recorded against a live server running text-embedding-nomic-embed-text-v1.5, with `data-raw/record-embed-cassette.R` as its generator and provenance. It holds three in-order elements of 768 fractional numbers each. It carries no request header and no token. A grep for the token value over the file found nothing. The test reads it with the server stopped and the token unset, and passes.
- 2026-09-20: LM Studio ignores the `dimensions` field on `/v1/embeddings`. A request asking for 5 came back with 768. AC2 asks for a cassette of five dimensions, which no live recording can give, so the wording goes to the amendment gate.
- 2026-09-20: substantive amendment to AC2, taken at the mini gate. The old evidence clause asked a live recording for five dimensions, which LM Studio cannot give. The criterion now names the domain it holds over and narrows the placement promise to the five cases the tests reach. It states the recorded model and its 768 dimensions. It also adds the absent row and column names, which no criterion covered before.
- 2026-09-20: re-audit: AC2 (full) — four findings. AC2 and AC6 demanded opposite outcomes for a base64 body reachable through the dots. The dimension count was deferred to whatever the fixture held. The placement promise ran over every n and every arrival order with no procedure enumerating them. No n = 2 permutation probe existed. All four fixed before the text was written.
- 2026-09-20: re-audit: AC2 (full) — six findings on the fixed text. The case list read as a cross product of nine pairs, six of which do not exist. The n = 1 placement claim rested on no probe. The shape sentence was still universal. The n = 2 probe the amendment named did not exist yet. No criterion covered the absent row and column names. The domain was stated by reference to another criterion rather than in observable terms. All six fixed. This is the second re-entry, so no further reader runs on AC2.
- 2026-09-20: the amendment added to T4. `expect_embedding_matrix()` asserts the size, the storage mode, the absent names, and every row. All five arrival-order cases run it, and the two n = 2 cases are new. Planting `out[i, ]` again turned the n = 2 out-of-order case red as well as the n = 3 one.
- 2026-09-20: claim audit: 95 claims read, 6 corrected — NEWS.md, R/conditions.R, R/embed.R, tests/testthat/test-embed.R. The changelog claimed five faults abort where eight branches do, and it omitted the missing-block and fractional-index faults. The condition page said the status is usually 200 where it is always 200. A comment claimed one probe per reject condition while no probe reached the missing-block branch, so a twelfth probe was added. The live-cassette test compared two row pairs and claimed three. The `simplify` help implied two possible values where any value other than TRUE takes the raw path. A comment claimed the endpoint's own contract promises index placement, which nothing in the branch supports. The reader re-read all six and found them accurate.
- 2026-09-20: all seven tasks done, status to review. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and `devtools::test()` gave 436 pass and 0 fail.
- 2026-09-20: the sizing tripwire fired at 9 acceptance criteria. Kept as one milestone: the only split line runs between the wrapper and its response validator, and shipping the wrapper first would put a silent matrix-corruption path on main for the length of a second milestone. The seven tasks each stay under one session.
- 2026-09-20: review checkpoint. Every acceptance criterion verified against fresh evidence and ticked. The consistency gate passed: cairn_validate exits 0 with one already-dispositioned sizing advisory, document() no diff, pkgdown clean, check() Status OK. Two of three review lenses reported; the diff-bug lens is still running.
- 2026-09-20: review returned the milestone to in-progress under the return floor. AC6 fails on two fresh-context findings, both verified against the implementation this session. A 200 body that is an atomic scalar, or whose `data` elements are atomic, raises an unclassed `simpleError` from `$` rather than aborting with `rlmstudio_bad_response`. And `$` partial matching reads a `database` field as the data block, so a response carrying no `data` block returns a matrix instead of aborting, which is the silent-wrong-matrix outcome D-007 exists to prevent. Nine further findings are recorded in the Review section with recommended dispositions. First defect return; the two AC2 amendment returns stay on their own track.
- 2026-09-20: implement gate on the return took every recommended disposition. The shared failure table gets an `lms_embed` row. All five smaller fixes land. AC7 narrows rather than binds the check order. The `NA` input case goes to a candidate row rather than widening AC7.
- 2026-09-20: minor amendment. T8 to T11 added for the return work, and the Coverage lines now map AC4 to T9, AC6 to T8, and AC7 to T11.
- 2026-09-20: T8 done. `json_field()` and `is_json_object()` in `R/embed.R` read every field by exact name, so partial matching can no longer read a `database` field as the data block. The body and each element are guarded on being a JSON object. A `data` block sent as a JSON object is rejected on its names. An empty embedding has its own clause. The dead `dimnames()` line is gone. Six probes were added, for eighteen in all. Planting the partial match back turned three expectations red, and the restore is green.
- 2026-09-20: substantive amendment to AC7, taken at the mini gate with the narrowing option chosen. The old text claimed the input check behaves as `lms_chat_batch()` does. That claim is false in two ways. The sibling runs the server check first and names its argument `inputs`. The new text drops the cross-reference, names the four values the probes supply, names the whole abort sentence, and cites the test. It binds no ordering. A widening goes to the candidate row instead.
- 2026-09-20: re-audit: AC7 (full) — six findings. The domain was an unenumerated family of every non-character value. A missing `input` fell inside the wording but raises R's own error. The message clause was unprobed, because all four probes matched a loose pattern the sibling's message also matches. Two sentences stated properties of the criterion rather than of the function. A tested ordering is bound by no criterion, and the disclaimer left it that way. The abort carries no condition class, where the design says callers catch by class. Four narrowing repairs were taken. The last two were held, because each repair widens the promise and the gate chose narrowing.
- 2026-09-20: re-audit: AC7 (full) — five findings on the fixed text. The evidence clause said "recorder test", but the probes abort before any HTTP call and run as four expectations in one test. Two of the four domain members were still open families resting on one exemplar each. The comparative tail promised a property of the regex rather than of the function. The no-argument case was ambiguous. And the criterion pins message text where D-007 records that callers catch by class. Four narrowing repairs were taken. The D-007 asymmetry is held and recorded here. It matches the sibling wrapper, and closing it adds a condition class to a user-facing surface. This is the second re-entry, so no further reader runs on AC7.
- 2026-09-20: T11 done. Review finding 8 is discharged by the amendment. The four input probes now match the whole sentence with `fixed = TRUE`. Planting `inputs` in place of `input` in the abort turned both probes red, and the restore is green. The Review entry for AC7 is left as review wrote it, because that section belongs to review.
- 2026-09-20: T9 and T10 done. The shared failure-message table runs nine wrappers now. The help page says what LM Studio does with `dimensions` and what `encoding_format = "base64"` does to the default path. The live-cassette test clears both token sources. The `verify` slot ran clean: document() wrote `lms_embed.Rd`, test() gave 460 pass and 0 fail.

- 2026-09-20: claim audit: 68 claims read, 1 corrected — tests/testthat/test-embed.R. A comment counted ten reject conditions where the check has eleven. It collapsed the two branches that report a value that is not a JSON object. The reader flagged one further claim as reading exhaustive without being so. The changelog listed eight faults that abort. It left out the empty embedding and the non-object element, and both are now named there. The reader did not test the two claims about what LM Studio does with `dimensions` and with `encoding_format`. That needs a live server.
- 2026-09-20: the amendment pushed the plan-owned sections to 152 lines against a cap of 150, so T8 and T10 were compressed in one pass. The sizing tripwire now also fires at 11 tasks. Kept as one milestone for the reason already recorded: T8 to T11 are the repairs the review returned, and they belong to the criteria they repair.
- 2026-09-20: the return work is done and the status goes back to review. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and `devtools::test()` gave 460 pass and 0 fail.

- 2026-09-20: second review pass. Every criterion was re-verified against fresh evidence. AC1 fails and its box is unticked. A named character vector goes out as a JSON object rather than an array, because `as.list()` keeps the names and jsonlite writes a named list as an object. Verified this session against the implementation. That is inside the domain AC1 quantifies over, and the repair is a code fix, so the return floor fires. The consistency gate passed. cairn_validate exits 0 with two dispositioned sizing advisories. document() gives no diff and pkgdown is clean. check() gives 0 errors, 0 warnings and 0 notes, and test() gives 460 pass. Both Sonnet lenses reported clean. Eight further findings are recorded in the Review section with recommended dispositions. Second defect return; the three amendment returns stay on their own track.

- 2026-09-20: implement gate on the second return took every recommended disposition. A 200 whose body does not parse aborts with the package class, and no criterion widens to cover it. The four smaller fixes land. The unguarded `model` argument goes to a candidate row.
- 2026-09-20: minor amendment. T12 to T15 added for the second return, and AC1 now maps to T12 in the Coverage lines.
- 2026-09-20: T12 done. `unname()` in `R/embed.R` drops the names `as.list()` carries over, so a named `input` vector goes out as a JSON array. Two probes read the names off the sent body at n = 1 and n = 2. Planting `as.list(input)` back turned three assertions red, and the restore is green.
- 2026-09-20: T13 done. The body parse sits inside a `tryCatch()` and a failed parse aborts with `rlmstudio_bad_response`. `rlm_abort_bad_response()` gained a `hint` argument, and this caller passes its own, because the parse runs before the `simplify` branch and the standing advice cannot help. Three probes cover an HTML page, an unparseable body, and the same body under `simplify = FALSE`. Removing the guard turned them red.
- 2026-09-20: the four new tasks pushed the plan-owned sections to 163 lines against a cap of 150, so the Tasks section was compressed in one pass. The sizing tripwire now reads 15 tasks. Kept as one milestone for the reason already recorded: every task past T7 is a repair the review returned, and each belongs to the criterion it repairs.
- 2026-09-20: T14 and T15 done. The input count is read by exact name. A `data` block of the wrong JSON type now says so rather than claiming there is no block. `NEWS.md` names the two faults it left out. The cassette generator checks its three packages and names them, rather than declaring a development tool in DESCRIPTION for a directory that never ships. The `model` candidate row is on the ROADMAP. The `verify` slot ran clean: document() gave no diff and test() gave 475 pass and 0 fail.

- 2026-09-20: claim audit: 41 claims read, 2 corrected — NEWS.md, R/conditions.R. Both stated the same false thing, in the changelog and on the condition help page. Each said every message of this class names `simplify = FALSE`. T13 made that untrue, because the parse failure passes its own hint and a test asserts the absence. Both now name the exception. The reader also checked the three counting claims and found them right. It did not test the two claims about what LM Studio does with `dimensions` and with `encoding_format`, because that needs a live server.
- 2026-09-20: the second return is repaired and the status goes back to review. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes, and `devtools::test()` gave 475 pass and 0 fail.

- 2026-09-20: third review pass, in progress. Every criterion re-verified
  against fresh evidence and ticked, AC1 included: the named-input repair
  holds and a named character vector now goes out as a JSON array. The
  consistency gate passed. cairn_validate exits 0 with two dispositioned
  sizing advisories. document() gives no diff, pkgdown is clean, check()
  gives 0 errors, 0 warnings and 0 notes, and test() gives 475 pass. Both
  Sonnet lenses reported: the prior-review lens found nothing, the
  blame-history lens returned one finding on the input-check order. The Opus
  diff-bug lens is still running, so the findings list and the approval gate
  are not reached yet.

## Decisions

## Review

_Third pass, 2026-09-20. The second pass returned the milestone on an AC1
failure: a named character `input` went out as a JSON object. Its evidence,
its nine findings and their dispositions are kept below under "Second pass",
unedited, and the first pass below that. Every criterion here rests on
evidence gathered fresh this session against the current branch head._

### Acceptance criteria

- AC1: **Pass.** The failure the second pass returned is closed. Verified
  fresh this session through the shared request recorder, reading the
  serialized bytes off each captured request with `httr2::req_dry_run()`.
  Four calls, each recording exactly one request, method POST, path
  `/v1/embeddings`. Unnamed n = 3 sends
  `{"model":"m","input":["first","second","third"]}`. Unnamed n = 1 sends
  `{"model":"m","input":["only one"]}`, a one-element array and not a bare
  string. **Named** n = 1, `c(doc1 = "only one")`, now sends
  `{"model":"m","input":["only one"]}`, and named n = 2,
  `c(a = "first", b = "second")`, sends
  `{"model":"m","input":["first","second"]}` — arrays in the order given,
  with the names dropped. `unname()` at `R/embed.R:62` is the repair.
  `NAMESPACE` carries `export(lms_embed)` and `man/lms_embed.Rd` exists, so
  the export and documentation clause holds.
- AC2: **Pass.** The reviewer ran all five named cases directly against
  `embed_matrix()` this session over a hand-built response of five fractional
  dimensions. Every one returned a `double` matrix with `NULL` dimnames, the
  right two dimensions, and the rows in input order: n = 1 (1x5), n = 2 in
  arrival orders 0-1 and 1-0 (both 2x5, both rows in input order), n = 3 in
  arrival orders 0-1-2 and 2-0-1 (both 3x5, both in input order). The
  committed tests run the same five through one shared helper. The cassette at
  `tests/testthat/embed_live/` was read directly: three elements, indexes 0, 1
  and 2, 768 numbers each, model `text-embedding-nomic-embed-text-v1.5`. Its
  test passed in the fresh suite run.
- AC3: **Pass.** The reviewer ran `simplify = FALSE` over a ragged body this
  session. The return is `identical()` to `httr2::resp_body_json()` on the
  same body. The same body under the default aborts with class
  `rlmstudio_bad_response`, which is the control showing none of the AC6
  checks run on the raw path.
- AC4: **Pass.** Run fresh this session. A call against a closed port aborts
  with class `rlmstudio_no_server`. A 400 and a 503 each abort with class
  `rlmstudio_api_error` carrying a `status` field of type integer holding that
  status. The wrapper also runs in the shared failure-message table at
  `tests/testthat/test-api-error.R`, which drives it over every body shape at
  both statuses.
- AC5: **Pass.** `names(formals(lms_embed))` is `model`, `input`, `host`,
  `simplify`, `...`, `token`, so `token` sits after the dots. The reviewer
  drove all four token states through `lms_embed()` itself this session and
  read the header off the serialized request. The argument gives
  `Bearer arg-token`. The `rlmstudio.token` option alone gives
  `Bearer option-token`. The `RLMSTUDIO_API_TOKEN` variable alone gives
  `Bearer variable-token`. With none of the three set the request carries no
  `authorization` header at all.
- AC6: **Pass.** The reviewer fired all eleven probes the criterion names
  directly against `embed_matrix()` this session. Every one aborted with class
  `rlmstudio_bad_response`, a `status` field of type integer holding 200, and
  a message naming `simplify = FALSE`. Each fired a distinct branch clause
  except the three embedding-shape probes, which share one clause by design.
  The five further reject branches (body not a JSON object, `data` block sent
  as a JSON object, element not a JSON object, no `data` block, empty
  embedding) were fired too and behave the same. The control passed: an
  accepted block returns its matrix with no condition raised.
- AC7: **Pass.** Run fresh this session. All four values the criterion names
  abort, and all four messages are the same string:
  `` `input` must be a non-empty character vector. `` The committed probes
  match that whole sentence with `fixed = TRUE`.
- AC8: **Pass.** `man/rlmstudio-conditions.Rd` carries the alias
  `rlmstudio_bad_response` beside the two existing aliases and a
  `\section{Malformed response}`. `man/lms_embed.Rd` carries three inherited
  sections, "Server not running", "API failure" and "Malformed response", each
  exactly once. `devtools::document()` run fresh left the tree clean, so
  neither file is hand-edited.
- AC9: **Pass.** `devtools::document()` run fresh this session produced no
  diff. `devtools::test()` run fresh gave 475 pass, 0 fail, 0 warn, 0 skip.

### Consistency gate

Universal cairn-file checks:

- `cairn_validate.py` exits 0 with "all checks passed". Two advisories fire,
  both under `sizing (split tripwires)`: 9 acceptance criteria against a
  tripwire of 7, and 15 tasks against a tripwire of 10. Both are dispositioned
  in the work log, the criteria count on the first pass and the task count on
  each return. Advisories are not gate failures.
- `cairn_impact.py` not run: `git diff main..HEAD -- cairn/DESIGN.md` is
  empty, so this milestone changes no `DESIGN.md` principle.

Toolchain checks, from the `consistency-gate` slot of `cairn/PROFILE.md`:

- `devtools::document()` produces no diff. `git status` is clean after it.
- Generated files not hand-edited: `NAMESPACE`, `man/lms_embed.Rd` and
  `man/rlmstudio-conditions.Rd` all regenerate identically, which the no-diff
  run above is the check for. No `data/*.rda` in this package.
- `README.Rmd` and `README.md` are untouched by this branch, so they are in
  sync.
- `pkgdown::check_pkgdown()` reports "No problems found."
- `NEWS.md` carries three entries for this milestone's user-visible changes,
  in plain user-facing words with no milestone numbers. The second entry now
  names all thirteen abort branches, including the two the second pass found
  missing.
- The only new top-level directory, `data-raw/`, has its `.Rbuildignore`
  entry, `^data-raw$`.
- `devtools::check()` run fresh: Status OK, 0 errors, 0 warnings, 0 notes.

No criterion failed and no gate check failed.


### Second pass (2026-09-20, returned)

_The first pass returned the milestone on two AC6 failures. Its evidence, its
eleven findings and their dispositions are kept below under "First pass",
unedited._

#### Acceptance criteria

- [ ] AC1: **Fail.** The request shape holds for an unnamed input vector and
  breaks for a named one. Verified fresh this session through the shared
  request recorder. With an unnamed vector the wrapper records exactly one
  request, method POST, path `/v1/embeddings`, and a body carrying `model`
  and an `input` array of the strings in the order given. At n = 1 that array
  holds one element rather than a bare string. With a **named** character
  vector the body carries `input` as a JSON object instead:
  `lms_embed("m", c(doc1 = "only one"))` sends
  `{"model":"m","input":{"doc1":"only one"}}`, and
  `c(a = "first", b = "second")` sends `{"a":"first","b":"second"}`.
  `as.list()` keeps the vector's names and jsonlite writes a named list as an
  object. A named character vector is a character vector of n inputs, so this
  is inside the domain AC1 quantifies over, and both of its clauses break: no
  array of n strings in the order given, and at n = 1 neither a one-element
  array nor a bare string. No committed test uses a named input. Reported as
  finding 1 below. `NAMESPACE` carries `export(lms_embed)` and
  `man/lms_embed.Rd` exists, so the export and documentation clause holds.
- AC2: **Pass.** The reviewer ran all five named cases directly against
  `embed_matrix()` this session. Each was asserted for matrix-ness, storage
  mode `double`, `NULL` dimnames, both dimensions, and every row value. The
  cases are n = 1, then n = 2 in arrival orders 0-1 and 1-0, then n = 3 in
  arrival orders 0-1-2 and 2-0-1. All five returned the rows in input order,
  which is the placement promise. The committed tests run the same five
  through one shared helper, so no case asserts less than its neighbours. The
  cassette at `tests/testthat/embed_live/` was read directly: three elements,
  768 numbers each, indexes 0, 1 and 2, model
  `text-embedding-nomic-embed-text-v1.5`. Its test passed in the fresh suite
  run.
- AC3: **Pass.** The reviewer ran `simplify = FALSE` over a ragged body this
  session. The return is `identical()` to `httr2::resp_body_json()` on the
  same body. The same body under the default aborts with class
  `rlmstudio_bad_response`, which is the control showing none of the AC6
  checks run on the raw path.
- AC4: **Pass.** Run fresh this session. A call against a closed port aborts
  with class `rlmstudio_no_server`. A 400 and a 503 each abort with class
  `rlmstudio_api_error` carrying a `status` field of type integer holding that
  status. The wrapper also now runs in the shared failure-message table at
  `tests/testthat/test-api-error.R`, which drives it over every body shape at
  both statuses.
- AC5: **Pass.** `names(formals(lms_embed))` is `model`, `input`, `host`,
  `simplify`, `...`, `token`, so `token` sits after the dots. The reviewer
  drove all four token states through `lms_embed()` itself this session and
  read the header off the recorded request. The argument gives
  `Bearer arg-token`. The `rlmstudio.token` option alone gives
  `Bearer option-token`. The `RLMSTUDIO_API_TOKEN` variable alone gives
  `Bearer variable-token`. With none of the three set there is no
  `authorization` header.
- AC6: **Pass.** The reviewer fired all eleven conditions the criterion names
  directly against `embed_matrix()` this session. Every one aborted with class
  `rlmstudio_bad_response`, a `status` identical to the integer 200, and a
  message naming `simplify = FALSE`. The committed suite runs eighteen probes
  over these eleven conditions and asserts the branch clause in each. A probe
  that fires the wrong branch therefore fails rather than passing on the
  shared class. The passing control confirms the check stays silent on a block
  it accepts.
- AC7: **Pass.** Run fresh this session. All four values the criterion names
  abort, and all four messages are the same string:
  `` `input` must be a non-empty character vector. `` The committed probes
  match that whole sentence with `fixed = TRUE`, and the work log records that
  planting `inputs` in place of `input` turns them red.
- AC8: **Pass.** `man/rlmstudio-conditions.Rd` carries the alias
  `rlmstudio_bad_response` beside the two existing aliases and a
  `\section{Malformed response}`. `man/lms_embed.Rd` carries three inherited
  sections, "Server not running", "API failure" and "Malformed response", each
  exactly once. `devtools::document()` run fresh left the tree clean, so
  neither file is hand-edited.
- AC9: **Pass.** `devtools::document()` run fresh this session produced no
  diff. `devtools::test()` run fresh gave 460 pass, 0 fail, 0 warn, 0 skip.

#### Consistency gate

Universal cairn-file checks:

- `cairn_validate.py` exits 0. Every check passes. Two advisories fire, both
  under `sizing (split tripwires)`: 9 acceptance criteria against a tripwire of
  7, and 11 tasks against a tripwire of 10. Both are dispositioned in the work
  log, the criteria count in the first pass and the task count on the return.
  Advisories are not gate failures.
- `cairn_impact.py` not run: this milestone changes no `DESIGN.md` principle.
  It is listed as touching GP1, GP3 and GP4, and `DESIGN.md` has no diff.

Toolchain checks, from the `consistency-gate` slot of `cairn/PROFILE.md`:

- `devtools::document()` produces no diff. Clean.
- Generated files not hand-edited: `NAMESPACE`, `man/lms_embed.Rd` and
  `man/rlmstudio-conditions.Rd` all regenerate identically, which the no-diff
  run above is the check for. No `data/*.rda` in this package.
- `README.Rmd` and `README.md` are untouched by this branch, so they are in
  sync.
- `pkgdown::check_pkgdown()` reports no problems.
- `NEWS.md` carries three entries for this milestone's user-visible changes,
  in plain user-facing words with no milestone numbers.
- The new top-level `data-raw/` directory has its `.Rbuildignore` entry,
  `^data-raw$`.
- `devtools::check()` run fresh: 0 errors, 0 warnings, 0 notes.

No criterion failed and no gate check failed.

#### Independent review

Surface tier is user-facing, so the full three-lens fan-out ran again, each
lens fresh-context and none having seen the implementation.

**[S] blame-history lens — no findings of concern.** It read `git log` and
`git blame` over the modified lines, the three return commits, `DECISIONS.md`,
`LESSONS.md`, `DESIGN.md` and the archive. It reports that the new helper is
purely additive and leaves `rlm_abort_api()` untouched, that the cassette and
its generator satisfy D-004, that the token table and the shared failure table
both take the wrapper as a normal row, and that `require_httpuv()` is reused
rather than a new dependency added. Its four observations are all already
dispositioned on this milestone: the `NA` input case as a candidate row, the
check-order divergence as the AC7 amendment, the validator asymmetry as D-007,
and the fixed 200 status as D-007's stated coupling.

**[S] prior-review-record lens — no findings.** The GitHub probe returned an
empty list, so no inline review comment exists on this repo and the secondary
surface contributed nothing. On the archive it checked M005, M006, M007 and
M009, the four archived milestones touching these files, and found no
regression against any of them. It also re-checked all eleven first-pass
findings against the current tree and reports each one resolved as its
disposition recorded, with none of the rejected or deferred ones quietly
re-applied.

**[O] diff-bug lens — nine findings.** Recorded below in the lens's own
ranking. The reviewer also reports checking and finding correct: every reject
branch reached by at least one probe and each probe matching its own branch
clause, the index arithmetic and both range edges, the unnamed double matrix
by construction, both first-pass AC6 failures now closed, the three token
sources at `lms_embed()` itself, the cassette holding no token, the shared
failure table green over all 22 body shapes at both statuses, the `...`
non-override, the `simplify = FALSE` passthrough, and AC8's three inherited
sections.

#### Findings

1. **[O] diff-bug.** A named character `input` is sent as a JSON object rather
   than an array. `R/embed.R:60`. `as.list()` keeps the vector's names, and
   jsonlite writes a named list as a JSON object. **Verified this session
   against the implementation:** `lms_embed("m", c(doc1 = "only one"))` sends
   `{"model":"m","input":{"doc1":"only one"}}`, and
   `c(a = "first", b = "second")` sends `{"a":"first","b":"second"}`. Failure
   scenario: `lms_embed(model, setNames(df$text, df$id))`, or any vector whose
   names survived a `vapply()`, sends a body the server rejects. The comment
   at `R/embed.R:56-59` claims `as.list()` keeps a single input an array of
   one. That holds only for an unnamed vector. No committed test uses a named
   input. **Floor-qualifying: AC1 fails.** A named character vector is a
   character vector of n inputs, so the failure is inside the domain AC1
   quantifies over. The repair is a code fix, `as.list(unname(input))`, and
   not a widening of an enumeration.
   **Disposition: fix now on the return, with a test.**

2. **[O] diff-bug.** A 200 response whose body is not parseable JSON raises an
   unclassed error. `R/embed.R:73`. `httr2::resp_body_json()` runs before any
   guard and before the `simplify` branch. **Verified this session:** a 200
   carrying `<html>oops</html>` at `text/html` gives `rlang_error` with
   "Unexpected content type", and a 200 carrying `not json at all` at
   `application/json` gives `simpleError` from the jsonlite lexer. Neither
   carries the class or the `simplify = FALSE` guidance. Passing
   `simplify = FALSE` does not rescue either, because the parse runs first.
   Not an AC failure: AC6 is worded over the `data` block, and a body that
   does not parse has no block. It is the remaining member of the family D-007
   exists for. **Recommended disposition: fix now on the return.**

3. **[O] diff-bug.** `body$input` still reads a field with `$`. `R/embed.R:83`.
   Commit 0f0cbfe added `json_field()` precisely to stop that, and the count
   this line produces drives every AC6 range and length check. **Verified by
   inspection.** Unreachable today, because `input` is a formal argument so the
   key is always exactly `input`, and a test pins that. It is an idiom break
   against the fix just landed. **Recommended disposition: fix now on the
   return.**

4. **[O] diff-bug.** `NEWS.md` omits one of the eleven abort branches. The
   second new bullet lists ten. Missing is `R/embed.R:164-166`, the body that
   is not a JSON object, which fires on a 200 whose body parses to an atomic
   value. **Verified** by enumerating the branches against the bullet. Not an
   AC failure, since no criterion covers changelog wording, and the last claim
   audit rewrote this list and still under-counted it. **Recommended
   disposition: fix now on the return.**

5. **[O] diff-bug.** `model` gets no input check. `R/embed.R:60`. **Verified:**
   `lms_embed(model = c("m1","m2"), input = c("a","b"))` sends
   `{"model":["m1","m2"],...}` and the user gets a server error that does not
   name the mistake. No criterion covers `model`, and `lms_chat_batch()` is
   equally unguarded, so this matches the siblings rather than regressing them.
   **Recommended disposition: candidate row.**

6. **[O] diff-bug.** `NA_character_` inside `input` still goes out as JSON
   `null`. `R/embed.R:47`. **Verified:** `c("a", NA_character_)` sends
   `{"model":"m","input":["a",null]}`. This is first-pass finding 9, which the
   implement gate dispositioned to a candidate row rather than a fix, and that
   row is on the ROADMAP. **Recommended disposition: reject, already routed.**

7. **[O] diff-bug.** The "no `data` block" clause fires for a body that has
   one. `R/embed.R:172-174`. A `data` block sent as a JSON object aborts with
   "the response carries no `data` block", which is not what happened: the
   block exists and is the wrong JSON type. **Verified this session.** The
   guard is correct and needed. Only the wording misdescribes the case, and a
   probe pins the misdescription. **Recommended disposition: fix now on the
   return** — the message and the probe, not the branch.

8. **[O] diff-bug.** `data-raw/record-embed-cassette.R:19` calls `pkgload`,
   which sits in no dependency field. `withr` and `httptest2` are in Suggests.
   **Verified by inspection of DESCRIPTION.** The directory is
   `.Rbuildignore`d, so `R CMD check` is unaffected. It matters to a
   contributor regenerating the fixture. **Recommended disposition: fix now on
   the return** — a one-line change to the generator.

9. **[O] diff-bug.** `@param simplify` is typed "Logical" but any non-`TRUE`
   value takes the raw path. `R/embed.R:11`, code at `:75`. **Verified:**
   `simplify = NA` and `simplify = "yes"` both return the raw list. This is
   first-pass finding 11, rejected there as documented and sibling-consistent.
   **Recommended disposition: reject, same reason.**

#### Outcome

The return floor fires on finding 1. A named character vector is a character
vector of n inputs, so AC1 fails inside the domain its promise quantifies
over, and the repair is a code fix rather than the widening of an
author-recalled enumeration. The widening test therefore does not carve it
out. AC1's box is unticked and its evidence line records the failure.

Status returns to `in-progress`. This is the second defect return on M012. The
two AC2 amendment returns and the AC7 amendment return stay on their own
track and are not counted here, so the thrash rule's third-return threshold is
not reached.

Findings 2 to 9 are recorded above with a recommended disposition for the
implement phase to take at its own gate. Nothing is dropped.

### First pass (2026-09-20, returned)

- AC1: **Pass.** `devtools::test()` run fresh this session: 436 pass, 0 fail, 0 skip.
  In `tests/testthat/test-embed.R`, "lms_embed sends one POST to v1/embeddings
  carrying the inputs" drives the call through the shared request recorder,
  reads exactly one recorded request, and asserts method POST and path
  `/v1/embeddings`. It reads the request's raw bytes rather than the simplified
  parse, so the body's `model` field and an `input` list of the three strings in
  the order given are both asserted. "a single input still travels as an array of
  one" asserts at n = 1 that `input` parses as a list of length one holding the
  string, which is the assertion that goes red if `as.list()` is dropped and
  jsonlite auto-unboxes. The only other network touch on the path is
  `is_server_running()` at `R/serve.R:237`, which opens a TCP socket rather than
  sending an HTTP request, so the one recorded request is the whole HTTP traffic.
  The exported status is confirmed by `NAMESPACE` and by `man/lms_embed.Rd`.
- AC2: **Pass.** All five named cases run in `tests/testthat/test-embed.R`
  through one shared helper, `expect_embedding_matrix()`, which asserts
  matrix-ness, storage mode `double`, both dimensions, `dimnames()` being
  `NULL`, and every row value. The cases are n = 1; n = 2 in arrival orders
  0-1 and 1-0; and n = 3 in arrival orders 0-1-2 and 2-0-1. Because all five
  call the same helper, no case can pass by asserting less than its
  neighbours. The two out-of-order cases return the rows in input order, not
  arrival order, which is the placement promise. The hand-built body carries
  five fractional dimensions, so a coercion that dropped the fraction would
  show. The live cassette in `tests/testthat/embed_live/` supplies the n = 3
  in-order case: its test asserts a 3 x 768 double matrix with `NULL`
  dimnames, one fractional value read off the recorded body, and that all
  three row pairs differ. The AC6 control ("the response check stays silent
  on a block it should accept") confirms the validator does not reject the
  accepted block. The work log records that planting `out[i, ]` in place of
  the index placement turned the n = 2 and n = 3 out-of-order cases red.

- AC3: **Pass.** "simplify = FALSE returns the parsed body unchanged" compares
  the return with `expect_identical()` against `httr2::resp_body_json()` run on
  the same body, so the promise of an unchanged parse is checked by identity
  and not by shape. "simplify = FALSE returns a body the response check
  rejects" runs a ragged body twice: under the default it aborts with class
  `rlmstudio_bad_response`, which is the control, and under
  `simplify = FALSE` it returns that same body identically. That pair is what
  shows none of the AC6 checks run on the raw path. The code path agrees:
  `R/embed.R` returns `resp_data` before `embed_matrix()` is reached whenever
  `simplify` is not `TRUE`.

- AC4: **Pass.** "lms_embed aborts with class rlmstudio_no_server" mocks the
  server probe to `FALSE` and asserts the class. "a failed response aborts
  with class rlmstudio_api_error" loops over statuses 400 and 503, catches the
  condition, and asserts the S3 class, that `status` is identical to the
  integer sent, and that the server's message text reaches the user. The
  wrapper reaches that abort through `rlm_abort_api()` on any status other
  than 200, so the two probed statuses exercise the same single branch.

- AC5: **Pass.** Argument position: the formals test in
  `tests/testthat/test-token-wrappers.R` asserts for every wrapper in the
  table, `lms_embed` now among them, that `token` is present and that where
  the function takes `...` the `token` argument sits after it, so it can only
  be matched by full name. Header present: `test-embed.R` asserts
  `Authorization: Bearer embed-token` on the request when the token comes
  from the argument, and the table-wide test asserts the same for `lms_embed`
  with the option and the variable both cleared. Header absent:
  `test-embed.R` and the table-wide negative test both assert no
  `authorization` header when none of the three sources holds a value. The
  option and variable sources were not driven through `lms_embed()` by any
  committed test, only through `lms_client()` in `test-token.R`, so the
  reviewer ran that probe directly this session: with only
  `options(rlmstudio.token=)` set the request carried `Bearer option-token`;
  with only `RLMSTUDIO_API_TOKEN` set it carried `Bearer variable-token`;
  with neither set it carried no header. All three sources therefore verified
  at `lms_embed()` itself.

- AC6: **Pass.** `test-embed.R` runs twelve probes, one more than the eleven
  the criterion names: the eleven listed, plus a body carrying no `data`
  block at all. Each probe asserts the S3 class `rlmstudio_bad_response`,
  that `status` is identical to the integer 200, that the message matches the
  clause of the branch it means to fire, and that the message names
  `simplify = FALSE`. Matching on the branch clause is what keeps a probe
  from passing on the shared class after firing the wrong branch. The
  validator in `R/embed.R` checks, in order: the `data` block is a list; its
  length equals the count of inputs the request sent; every `index` is one
  non-NA number; every index is whole; no index repeats; no index falls
  outside 0 to n-1; every `embedding` is a non-empty list whose elements are
  each one number; and all embeddings share one length. The passing control
  test confirms the check stays silent on a block it accepts.

- AC7: **Pass.** "lms_embed aborts on an input that is not a character vector"
  fires four cases and matches the message in each: an integer vector, a
  list, `NULL`, and `character(0)`. The abort in `R/embed.R` is the same
  shape as the one `lms_chat_batch()` raises at `R/chat.R:382-387`, down to
  the wording "must be a non-empty character vector" and `call = NULL`. One
  ordering difference from the sibling, verified and not a criterion breach:
  `lms_embed()` runs the input check before `stop_if_no_server()`, while
  `lms_chat_batch()` runs the server check first. A test pins the
  `lms_embed()` order, so a bad input reports the caller's mistake even with
  no server running.

- AC8: **Pass.** `man/rlmstudio-conditions.Rd` carries the alias
  `rlmstudio_bad_response` beside the two existing aliases and a
  `\section{Malformed response}` naming the class and its `status` field,
  with a `tryCatch()` example that handles it. `man/lms_embed.Rd` carries
  three inherited sections, "Server not running", "API failure", and
  "Malformed response", each once. Both files regenerate from roxygen with no
  diff, so the sections are not hand-edited.

- AC9: **Pass.** `devtools::document()` run fresh this session left the
  working tree clean, so no generated file is out of step with its roxygen
  source. `devtools::test()` run fresh gave 436 pass, 0 fail, 0 warn, 0 skip.

#### First-pass consistency gate

Universal cairn-file checks:

- `cairn_validate.py` exits 0. Every check passes. One advisory fires,
  `sizing (split tripwires)`: 9 acceptance criteria against a tripwire of 7.
  The work log already dispositioned it, keeping the wrapper and its response
  validator in one milestone so no silent matrix-corruption path sits on the
  default branch between two milestones. Advisories are not gate failures.
- `cairn_impact.py` not run: this milestone changes no `DESIGN.md` principle.
  It is listed as touching GP1, GP3, and GP4, and `DESIGN.md` has no diff.

Toolchain checks, from the `consistency-gate` slot of `cairn/PROFILE.md`:

- `devtools::document()` produces no diff. Clean.
- Generated files not hand-edited: `NAMESPACE`, `man/lms_embed.Rd`, and
  `man/rlmstudio-conditions.Rd` all regenerate identically, which the no-diff
  run above is the check for. No `data/*.rda` in this package.
- `README.Rmd` and `README.md` are untouched by this branch and were last
  written by the same commit, so they are in sync.
- `pkgdown::check_pkgdown()` reports no problems. `lms_embed` sits under a
  new "Embeddings" title in `pkgdown/_pkgdown.yml`.
- `NEWS.md` carries three entries for this milestone's user-visible changes,
  in plain user-facing words with no milestone numbers.
- New top-level directory `data-raw/` has its `.Rbuildignore` entry,
  `^data-raw$`.
- `devtools::check()` reports Status: OK. 0 errors, 0 warnings, 0 notes.

No criterion failed and no gate check failed.

#### First-pass independent review

Surface tier is user-facing, so the full three-lens fan-out ran, each lens
fresh-context and each on its own evidence base.

**[S] blame-history lens — no findings of concern.** It read `git log` and
`git blame` over every modified line, plus `DECISIONS.md`, `LESSONS.md`, and
`DESIGN.md`. It reports that the wrapper follows the sibling pattern exactly,
that the separate `rlmstudio_bad_response` class matches D-007's stated
rationale, that the `rlmstudio_bad_response` alias satisfies the M007 lesson,
and that the cassette generator satisfies the D-004 provenance rule. One
low-confidence observation, reported as not a defect: the
`rlmstudio_bad_response` section says "Today the status is always 200", which
holds only while `lms_embed()` is the sole raiser. D-007 already records that
coupling as accepted.

**[S] prior-PR-comments lens — one finding.** Recorded below as finding 1. It
found no prior-review regression on any other touched file, checking
specifically against M007's missing-alias and delegation findings, M007's
roxygen/DESCRIPTION failure, and M009's silently-discarded-token finding.

**[O] diff-bug lens — ten findings.** Recorded below as findings 2 to 11, in
the lens's own ranking. The reviewer also reports checking and finding correct:
the index arithmetic and both range edges, the double coercion, the n = 1
matrix shape, the `simplify = FALSE` passthrough, that `...` cannot override
`model` or `input`, the token plumbing, AC8, AC9, and that the cassette holds
no token.

#### First-pass findings

1. **[S] prior-PR-comments.** `lms_embed()` calls `rlm_abort_api()` but was
   not added to the `api_error_callers` table in
   `tests/testthat/test-api-error.R`, which has no diff on this branch.
   `cairn/milestones/archive/M006-list-models-abort-path.md` records that
   table as the pattern for every wrapper that calls `rlm_abort_api()`: it
   drives eight wrappers over 22 body shapes at two statuses, and M008 added
   a per-request host assertion to the same loop. `lms_embed()` instead gets
   a one-off test over one body shape at two statuses. Failure scenario: a
   later change to the message extraction in `rlm_abort_api()` breaks for the
   body shapes `lms_embed()` sees and the shared table does not catch it.
   Verified against the implementation: the table has eight entries and
   `lms_embed` is absent; `R/embed.R` does call `rlm_abort_api()`; and the
   harness would take a `lms_embed` entry unchanged. **Disposition: pending
   at the approval gate.**

2. **[O] diff-bug.** A 200 response whose body is not a list, or whose `data`
   holds non-object elements, raises an unclassed `simpleError` instead of
   `rlmstudio_bad_response`. `R/embed.R:148` (`data <- resp_data$data`) and
   `:163`/`:180` (`el$index`, `el$embedding`). `$` on an atomic vector is an
   error in R, and neither `resp_data` nor each `el` is type-checked before it
   is subset. `api_error_message()` at `R/utils-api-error.R:47` already guards
   this way with a comment saying why, so it is an idiom break as well.
   **Verified this session against the implementation.** A body of `"hello"`
   and a body of `{"data": ["a"]}` at n = 1 both give
   `simpleError | $ operator is invalid for atomic vectors`. (The reviewer's
   `{"data": [1, 2]}` example at n = 1 actually reaches the count branch and
   aborts correctly; the defect is real but reaches it through the atomic-element
   path, which the string case shows.) **Floor-qualifying: AC6 fails.** AC6
   promises that a block failing any of its conditions aborts with class
   `rlmstudio_bad_response`; a block of atomic elements carries no `index` and
   so fails a named condition, and the abort carries neither the class nor the
   `simplify = FALSE` guidance.

3. **[O] diff-bug.** `$` partial matching makes the validator read the wrong
   field. `R/embed.R:148`, `:163`, `:181`. A body with no `data` but with, say,
   `database` is silently read as the data block; the same holds for `indexes`
   and `embeddings` on an element. `[["data"]]` / `[["index"]]` /
   `[["embedding"]]` would close this and part of finding 2. **Verified this
   session:** `{"database": [{"index":0,"embedding":[0.1,0.2]}]}` at n = 1
   returns a 1 x 2 matrix built from a field that is not `data`. **Floor-
   qualifying: AC6 fails.** The response carries no `data` block, which is a
   failing condition, and instead of aborting the wrapper returns a matrix.
   This is exactly the silent-wrong-matrix outcome D-007 records the class as
   existing to prevent.

4. **[O] diff-bug.** The help page names two `...` examples that do not work as
   a reader would expect. `R/embed.R:14-15`, rendered at `man/lms_embed.Rd`.
   `encoding_format = "base64"` is a supported OpenAI field, and passing it
   makes the default path abort every time — it is the base64 probe in
   `test-embed.R`. `dimensions` is, by this milestone's own work log, silently
   ignored by LM Studio. So both named examples are respectively fatal and a
   no-op, and nothing on the page says so. D-003 accepts silently ignoring
   unknown fields, but it does not cover the help page recommending a field
   that guarantees an abort. **Verified:** the work-log entry of 2026-09-20
   records the `dimensions` behavior, and the base64 probe records the abort.
   **Recommended disposition: fix now on the return** — a documentation fix,
   no AC covers the `...` examples.

5. **[O] diff-bug.** A `data` block that is a JSON object rather than an array
   is accepted. `R/embed.R:149` (`!is.list(data)`). A parsed JSON object is
   also a list, and `length()` counts its members rather than array elements.
   **Verified this session:** `{"data": {"a": {"index":0,"embedding":[0.1,0.2]}}}`
   at n = 1 returns a 1 x 2 matrix. **Recommended disposition: fix now on the
   return**, with the same type guard findings 2 and 3 need.

6. **[O] diff-bug.** An empty `embedding` array is reported with a misleading
   clause. `R/embed.R:182` folds `length(embedding) == 0L` into the "carries no
   list of numbers" branch, but `[]` is a list of numbers, of zero of them. AC6
   does not name the zero-length case at all, so the branch is unexercised by
   any of the twelve probes. **Verified this session:**
   `{"data": [{"index":0,"embedding":[]}]}` aborts with
   `rlmstudio_bad_response` and the clause "carries no list of numbers".
   **Recommended disposition: fix now on the return** — the guard is needed,
   since `ncol = 0` would otherwise be built, so the repair is the message
   wording and a probe, not the branch.

7. **[O] diff-bug.** Dead statement. `R/embed.R:183` (`dimnames(out) <- NULL`).
   `out` comes from `matrix(0, nrow, ncol)`, whose dimnames are already `NULL`,
   and every value assigned into it is stripped of names by
   `unlist(embedding, use.names = FALSE)`. The line can never change anything,
   so AC2's absent-names promise is enforced by the matrix constructor rather
   than by the line that looks like it enforces it. **Verified by inspection.**
   **Recommended disposition: fix now on the return** — remove the line, or
   keep it with a comment saying it is a belt-and-braces assertion.

8. **[O] diff-bug.** AC7's cross-reference to `lms_chat_batch()` does not
   describe what was built. `R/embed.R:57-62` against `R/chat.R:380-388`.
   `lms_chat_batch()` calls `stop_if_no_server(host)` before the input check;
   `lms_embed()` does the opposite, and a test pins the new order. **Verified
   this session and already recorded in the AC7 evidence line above.** The embed
   order is the better one. **Recommended disposition: amendment to AC7's
   wording on the return**, through the gated protocol, since the divergence is
   deliberate and the criterion's words are what no longer fit.

9. **[O] diff-bug.** `NA_character_` inside `input` passes the contract check
   and goes out as JSON `null`. `R/embed.R:57`. `is.character(c("a", NA))` is
   `TRUE`. **Verified this session:** the request body sent for
   `c("a", NA_character_)` is `{"model":"m","input":["a",null]}`. The user then
   gets either a server error about the request or a count mismatch, and
   neither names the `NA`. AC7 covers type and length only, so this is a gap in
   the criterion as much as in the code. **Recommended disposition: fix now on
   the return, with an AC7 amendment** naming the `NA` case.

10. **[O] diff-bug.** A work-log claim the test does not support. The entry of
    2026-09-20 for T5 says "The test reads it with the server stopped and the
    token unset". The live-cassette test mocks `is_server_running` but never
    unsets `RLMSTUDIO_API_TOKEN` or the `rlmstudio.token` option. **Verified
    this session:** `test-embed.R` clears the token only at lines 428-429, in
    the negative token test. The test passes either way because httptest2
    matches on URL and body rather than headers, so the claim is harmless but
    untrue, and this machine normally has `RLMSTUDIO_API_TOKEN` set.
    **Recommended disposition: fix now on the return** — correct the work-log
    claim, or make the test clear the token so the claim becomes true.

11. **[O] diff-bug.** `@param simplify` is typed "Logical" but any non-`TRUE`
    value silently takes the raw path. `R/embed.R:10-12`, code at `:88`
    (`!isTRUE(simplify)`). **Verified by inspection.** The help text already
    says "Any other value returns the parsed response body unchanged", and the
    behavior matches `lms_chat_openresponses()`. **Recommended disposition:
    reject** — documented, and consistent with the sibling wrappers.

#### First-pass outcome

The return floor fires. Findings 2 and 3 each demonstrate AC6 failing inside
the domain its promise quantifies over, and the repair for both is a code fix
rather than the widening of an author-recalled enumeration, so the widening
test does not carve them out. Finding 3 is the more serious of the two: it
returns a silently wrong matrix rather than aborting, which is the outcome
D-007 records the condition class as existing to prevent.

Status returns to `in-progress`. This is the first defect return on M012; the
two amendment returns the work log records for AC2 stay on their own track and
are not counted here, so the thrash rule does not fire.

Every other finding is recorded above with a recommended disposition for the
implement phase to take at its own gate. Nothing has been triaged as rejected
by this review except where marked, and no finding has been dropped.

