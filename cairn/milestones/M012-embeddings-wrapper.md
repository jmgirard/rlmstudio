# M012: The package can turn text into embedding vectors

- **Status:** in-progress
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
- [x] AC7: `lms_embed()` aborts when `input` is not a character vector or has
      length zero, as `lms_chat_batch()` does at `R/chat.R:385`.
- [x] AC8: `rlmstudio_bad_response` has its own section and alias on the
      `rlmstudio-conditions` help page, and that section is inherited onto the
      `lms_embed()` help page.
- [x] AC9: The `verify` slot of `cairn/PROFILE.md` is clean: `devtools::document()`
      produces no diff and `devtools::test()` passes.

## Coverage

- AC1 → T1, T4
- AC2 → T1, T2, T4, T5
- AC3 → T1, T4
- AC4 → T1, T4
- AC5 → T1, T4, T6
- AC6 → T2, T4
- AC7 → T1, T4
- AC8 → T3
- AC9 → T3, T4

## Tasks

- [x] T1: Write `R/embed.R`. `lms_embed(model, input, host =
      "http://localhost:1234", simplify = TRUE, ..., token = NULL)`: the AC7
      input check, `stop_if_no_server(host)`, a body of `model` and
      `as.list(input)` merged with `...`, POST to `v1/embeddings` through
      `lms_client()`, `req_error(is_error = \(resp) FALSE)`, a non-200 to
      `rlm_abort_api(resp, "Embeddings Failed", !is.null(rlm_token(token)))`.
      Follow `lms_chat_openresponses()` at `R/chat.R:123`.
- [x] T2: Write the `data`-block validator and the matrix assembly. Raise
      `rlmstudio_bad_response` from a new helper beside `rlm_abort_api()` in
      `R/utils-api-error.R`. `resp_body_json()` parses with
      `simplifyVector = FALSE` (LESSONS, M005), so each embedding arrives as a
      list and `do.call(rbind, ...)` over those lists builds a list matrix, not
      a double one. Coerce per element.
- [x] T3: Add the third `@section` and the `@aliases` entry to `R/conditions.R`,
      put the two `@inheritSection` tags on `lms_embed()`, and run
      `devtools::document()`. The tag must stay on one physical line and the
      title must match character for character (LESSONS, M007).
- [x] T4: Write `tests/testthat/test-embed.R` against
      `local_request_recorder()` in `tests/testthat/helper-mock-http.R`: the
      request shape at n = 3 and n = 1, the permutation, `simplify = FALSE`,
      the two condition classes, the eleven AC6 probes, and the input contract.
- [x] T5: Record the happy-path cassette. Load an embedding model, run one
      `lms_embed()` call under `httptest2::with_mock_dir()`, and commit the
      cassette with a `data-raw/` generator naming the model, the host, and the
      date, per the fixture-provenance rule in `cairn/PROFILE.md`.
- [x] T6: Add `lms_embed` to the wrapper table at
      `tests/testthat/test-token-wrappers.R:26` and change the name-list test
      at `test-token-wrappers.R:138` from twelve names to thirteen.
- [x] T7: Add `lms_embed` to `pkgdown/_pkgdown.yml` under a new "Embeddings"
      title, write the `NEWS.md` entry in plain user-facing words, and replace
      the "No wrapper exists" note on the `/v1/embeddings` row of
      `cairn/references/lmstudio-api-surface.md:40`.

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

## Decisions

## Review

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

### Consistency gate

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

### Independent review

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

### Findings

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

### Outcome

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

