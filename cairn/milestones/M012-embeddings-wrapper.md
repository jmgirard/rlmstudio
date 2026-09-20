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

- [ ] AC1: `lms_embed()` is exported and documented. A call with a character
      vector of n inputs, passing no `model` or `input` through `...`, sends
      exactly one HTTP request: a POST to the `v1/embeddings` path of `host`,
      whose JSON body carries `model` and an `input` array holding those n
      strings in the order given. At n = 1 the body carries a one-element
      array and not a bare string.
- [ ] AC2: With `simplify = TRUE` (the default), on a response whose `data`
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
- [ ] AC3: With `simplify = FALSE`, `lms_embed()` returns the parsed response
      body unchanged, identical to what `httr2::resp_body_json()` produced for
      that body, and runs none of the AC6 checks: a body AC6 rejects still
      returns under `simplify = FALSE`.
- [ ] AC4: `lms_embed()` aborts with condition class `rlmstudio_no_server` when
      the server check fails, and with class `rlmstudio_api_error` carrying an
      integer `status` field at the statuses the failure test sends, which are
      400 and 503.
- [ ] AC5: `lms_embed()` takes a `token` argument positioned after `...`. Every
      request it issues carries an `Authorization: Bearer <token>` header when
      a token resolves from the argument, the `rlmstudio.token` option, or the
      `RLMSTUDIO_API_TOKEN` environment variable, and carries no
      `Authorization` header when none of the three holds a value.
- [ ] AC6: Before building the matrix, `lms_embed()` checks the response `data`
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
- [ ] AC7: `lms_embed()` aborts when `input` is not a character vector or has
      length zero, as `lms_chat_batch()` does at `R/chat.R:385`.
- [ ] AC8: `rlmstudio_bad_response` has its own section and alias on the
      `rlmstudio-conditions` help page, and that section is inherited onto the
      `lms_embed()` help page.
- [ ] AC9: The `verify` slot of `cairn/PROFILE.md` is clean: `devtools::document()`
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
- 2026-09-20: the sizing tripwire fired at 9 acceptance criteria. Kept as one milestone: the only split line runs between the wrapper and its response validator, and shipping the wrapper first would put a silent matrix-corruption path on main for the length of a second milestone. The seven tasks each stay under one session.

## Decisions

## Review
