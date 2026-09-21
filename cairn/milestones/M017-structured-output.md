# M017: The OpenAI chat call takes a JSON schema and returns the parsed answer

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1, GP1, GP2, GP4
- **Resolves:** —
- **Surface tier:** user-facing — new argument and return shape on three exported chat functions
- **Branch/PR:** m017-structured-output

## Goal

`lms_chat_openai()` takes a JSON schema, sends the structured-output request
that LM Studio documents, and returns the reply as a parsed R value.

## Scope

**In:** A `schema` argument on `lms_chat_openai()` and `lms_chat()`, which
`lms_chat_batch()` forwards. The `response_format` body. The parse of the
reply content with `jsonlite::parse_json()`. An `rlmstudio_bad_response` abort
on content that does not parse. A form check on `schema`, and a check against
a clashing `response_format` in `...`. The `api_type` check in `lms_chat()`.
Batch output for each `format`. A recorded live cassette and its generator.
Docs, NEWS, and the DESIGN contract-boundary line that D-009 narrows.

**Out:** Structured output on `/v1/responses` and `/api/v1/chat`. The LM
Studio docs describe it for neither endpoint, so it is a candidate row. Parsed
batch replies bound into data-frame columns are a candidate row. A check of
the schema content stays with the server (D-003).

## Acceptance criteria

- [x] AC1: `lms_chat_openai()` gains a `schema` argument after `...`. With
      `schema` set, the body sent to `v1/chat/completions` carries
      `response_format`. It has `type` `"json_schema"` and a `json_schema`
      object. That object holds `name` `"response"`, `strict` `true`, and the
      given schema as `schema`. With `schema = NULL`, the body has no
      `response_format` key. Tests in `tests/testthat/test-chat-schema.R`
      assert both bodies on the raw request bytes. One test gives `required`
      as `list("score")` and asserts that it arrives as a JSON array.
- [x] AC2: With `schema` set, `simplify = TRUE`, and `logprobs = FALSE`,
      `lms_chat_openai()` returns the value of
      `jsonlite::parse_json(content, simplifyVector = TRUE)`. Here `content`
      is `choices[[1]]$message$content`. With `simplify = FALSE`, it returns
      the parsed response list, and the content stays a string. With
      `logprobs = TRUE`, it returns an `lms_chat_result` whose `text` is the
      unparsed string. A recorded live response covers the first two cases.
      Mocked responses cover a JSON object, array, and scalar reply, and the
      `logprobs = TRUE` case.
- [x] AC3: With `schema` set, `simplify = TRUE`, and `logprobs = FALSE`,
      `lms_chat_openai()` aborts on content that is not a single string. It
      also aborts on content that `jsonlite::parse_json()` fails to parse.
      The abort has class `rlmstudio_bad_response` and an integer `status` of
      200. Tests fire it for invalid text, an empty string, a JSON `null` in
      the content field, and a URL string. Each test asserts the class and
      the field. The string `"null"` is valid JSON, so the call returns
      `NULL` for it, and a test pins that.
- [x] AC4: A `schema` fails the form check unless it is `NULL`, an empty
      list, or a list that is not a data frame and has a non-empty,
      non-missing name on every element. A failed form check makes `lms_chat_openai()`,
      `lms_chat()`, and `lms_chat_batch()` abort before the server probe, with
      no package condition class. A `schema` passed with a `response_format`
      in `...` aborts the same way. Tests in
      `tests/testthat/test-arg-guards.R` cover each of the three functions.
      They fire a string, an unnamed list, a partly named list, a list with
      an `NA` name, a data frame, and the `response_format` clash. A server probe stub counts its calls,
      and each test asserts a count of zero.
- [x] AC5: `lms_chat()` takes `schema` and forwards it to
      `lms_chat_openai()`. A valid `schema` with `api_type` set to
      `"openresponses"` or `"native"` makes `lms_chat()` abort before the
      server probe. The message names `api_type = "openai"`. The AC4 form
      check runs first. `lms_chat_batch()` runs the same check before its own
      server probe. In both functions, tests fire the abort for each of the two
      values and for the default `api_type`. A server probe stub counts its
      calls in each. One test shows that an invalid `schema` with the
      default `api_type` raises the form fault.
- [x] AC6: `lms_chat_batch()` forwards `schema` to `lms_chat()`. The rest of
      this criterion holds with `schema` set, `simplify = TRUE`, and
      `logprobs = FALSE`. `format = "list"` returns one parsed value per
      input. With `format = "vector"`, it warns and returns that list for
      every reply type. With `format = "data.frame"`, the `output` column is
      a list of parsed values. A test covers each format. The vector test
      runs once with an object reply and once with a scalar reply.
- [x] AC7: The `rlmstudio-conditions` help page describes both raisers of
      `rlmstudio_bad_response`. `lms_chat_openai()` inherits the "Malformed
      response" section. `NEWS.md` has an entry for the `schema` argument.
      `devtools::document()` produces no diff, and `devtools::test()` is
      clean. `devtools::check()` reports 0 errors and 0 warnings.

## Coverage

- AC1 → T2
- AC2 → T2, T3
- AC3 → T2
- AC4 → T1
- AC5 → T1, T4
- AC6 → T5
- AC7 → T6

## Tasks

- [x] T1: Add `rlm_check_schema()` to `R/utils-args.R`. It holds the form
      check and the `response_format` clash as unclassed aborts (D-008). Call
      it above the server probe in `lms_chat_openai()` and `lms_chat()`.
      In `lms_chat_batch()`, read `list(...)[["schema"]]`, because `$` matches
      partial names. Run the form check and the `api_type` check of T4 above
      its probe.
      Extend `tests/testthat/test-arg-guards.R` with a counting probe stub
      (LESSONS, M015).
- [x] T2: In `lms_chat_openai()` (`R/chat.R:246`), build `response_format`
      from `schema`. Parse the content with `jsonlite::parse_json()`. Do not
      use `fromJSON()`, because it fetches a reply that looks like a URL and
      reads a reply that names a file. Abort through
      `rlm_abort_bad_response()` (`R/utils-api-error.R:127`). Write
      `tests/testthat/test-chat-schema.R` on the shared recorder. Read the
      raw body bytes as `test-embed.R` does.
- [x] T3: Write `data-raw/record-schema-cassette.R` on the model of
      `data-raw/record-embed-cassette.R`. Record one structured reply from a
      live LM Studio into a new cassette directory. Add the recorded tests for
      AC2. The live run needs `RLMSTUDIO_API_TOKEN` set (LESSONS, M009).
- [x] T4: Add `schema` to `lms_chat()`, the `api_type` check after the form
      check, and the forward to `lms_chat_openai()`. Probe the abort route,
      which has no delegate (LESSONS, M013).
- [x] T5: When `schema` is set, make `lms_chat_batch()` warn and return a
      list for `format = "vector"`. Make it return an `output` list-column for
      `format = "data.frame"`. Add a test per format.
- [x] T6: Document `schema`. A one-element array is written as `list()` or
      `I()`, because `req_body_json()` unboxes a vector of length one. Rewrite
      the conditions page for two raisers. Add the `@inheritSection` to
      `lms_chat_openai()` and the raiser note to `lms_chat()` and
      `lms_chat_batch()`. Update the DESIGN contract-boundary line to cite
      D-009. Add the NEWS entry. Run `document()`, `test()`, and `check()`.

## Work log

- 2026-09-21: created by /milestone-plan.
- 2026-09-21: criteria audit (full mode, fresh [O] reader) returned 12 findings. Eight were fixed in the draft. Four fixes were parse_json over fromJSON, the response_format clash, raw-byte body assertions, and the batch guard. The other four were check order, AC3 scope, the conditions-page rewrite, and the `schema` position and name. Four went to the gate or were narrowed: the boundary, the schema form, the per-type return, and the batch vector warning.
- 2026-09-21: re-audit (full mode, same fresh reader) of the revised wording returned five findings, all fixed. AC6 was narrowed to `simplify = TRUE`, the vector test gained a scalar reply, and batch runs the `api_type` check. The form check refuses an `NA` name, and AC3 names the JSON `null` field.
- 2026-09-21: plan gate chose to parse the reply over returning the JSON string, because a scoring run wants one value per item. Falsified by users who need the raw string where `simplify = FALSE` does not serve.
- 2026-09-21: plan gate chose an abort in `lms_chat()` on a non-openai `api_type` over a silent route to the OpenAI endpoint. With that route, the default depends on another argument. Falsified by LM Studio documenting structured output on `/v1/responses`.
- 2026-09-21: plan chose a fixed `json_schema$name` of `"response"` over a `schema_name` argument, because the name does not change the output. Falsified by a server that rejects the name or uses it.
- 2026-09-21: implement started on `m017-structured-output`. The question gate was skipped, because the plan left no choice open and no dependency changes.
- 2026-09-21: T1 done. `rlm_check_schema()` and `rlm_check_schema_route()` run above the probe in all three functions. With the batch check removed, the form and clash tests went red with `rlmstudio_no_server`.
- 2026-09-21: T2 done. An empty schema is sent as `{}` with empty names, because jsonlite writes `list()` as `[]`. A reply that names a temp file holding JSON is the probe that separates `parse_json()` from `fromJSON()`. With `fromJSON()` planted, only that probe failed. Suite: 244 tests, 0 failed, 0 skipped.
- 2026-09-21: T3 done. The cassette `chat_schema_live` was recorded from `google/gemma-3-1b` at temperature 0 and holds the reply `{ "score": 3 }` with no auth header. The recorded test passed with the server stopped, so the cassette served it.
- 2026-09-21: T4 done. `lms_chat()` forwards `schema` on the openai route. With either route check removed, the route test went red with `rlmstudio_no_server`. Suite: 248 tests, 0 failed, 0 skipped.
- 2026-09-21: T5 done. With `has_parsed` planted as FALSE, the vector and data-frame batch tests failed six expectations. Suite: 251 tests, 0 failed, 0 skipped.
- 2026-09-21: T6 done. Roxygen, the conditions page, the DESIGN boundary line (D-009), and NEWS are written. The "Server not running" section now names `schema`, so every page that inherits it changed. `document()` leaves no diff. `devtools::check()` with the token set: 0 errors, 0 warnings, 0 notes.
- 2026-09-21: claim audit: 78 claims read, 5 corrected — R/chat.R, NEWS.md, data-raw/record-schema-cassette.R
- 2026-09-21: the claim audit found that a top-level `on.exit()` never runs under Rscript, so the recorder script left the model loaded. It now unloads in a `finally` clause. The same reader re-read the five corrections and found all of them matching.
- 2026-09-21: implement complete. Suite: 251 tests, 0 failed, 0 skipped. `devtools::check()`: 0 errors, 0 warnings, 0 notes. Status set to review.

## Decisions

## Review

Fresh run 2026-09-21 on `m017-structured-output` at 283999a, level with `origin/main` (4ea6395). `devtools::test()` with the token set: 251 test blocks, 1536 expectations, 0 failed, 0 skipped. The 30 blocks in `test-chat-schema.R` and `test-arg-guards.R` pass.

- AC1: `test-chat-schema.R` "a schema is sent as the documented response_format" reads the raw request bytes through `req_dry_run()`. It asserts the path `/v1/chat/completions`, `type` `"json_schema"`, `name` `"response"`, `strict` `TRUE`, and the schema. It also asserts the literal `"required":["score"]` for `required = list("score")`. "no schema sends no response_format" asserts the key is absent. Both pass.
- AC2: "the reply is parsed with jsonlite::parse_json() and simplified" covers mocked object, array, scalar, array-of-objects, and `"null"` replies. It states `list(score = 3L)` apart from the parser. Two more tests cover `simplify = FALSE` and `logprobs = TRUE`. Each gets the reply as an unparsed string. The recorded test runs the `chat_schema_live` cassette twice. With `simplify = TRUE` it gets `list(score = 3L)`, and with `FALSE` it gets a string. All pass.
- AC3: One test fires the abort for invalid text, an empty string, a JSON `null` content field, and a URL. Each case asserts the class `rlmstudio_bad_response` and `status` 200L. The `"null"` string returns `NULL` in the AC2 parse test. A file-path reply also aborts, which separates `parse_json()` from `fromJSON()`. All pass.
- AC4: In `test-arg-guards.R`, "a schema in the wrong form aborts before the server probe" runs all three functions. Each gets a string, an unnamed list, a partly named list, an `NA` name, and a data frame. Each abort has no `rlmstudio_` class, and the counting probe reads 0 calls. The `response_format` clash test does the same for all three. A third test shows that a named list, `list()`, and `NULL` pass and reach the probe. All pass.
- AC5: "lms_chat() forwards a schema on the openai route" gets `list(score = 4L)` and finds the schema in the sent body. The route test runs `lms_chat()` and `lms_chat_batch()` with `"openresponses"`, `"native"`, and the default `api_type`. Each abort message holds `api_type = "openai"`, and the probe reads 0 calls. "the form check runs before the route check" gives `schema = "object"` with the default route and gets the form fault in both functions. All pass.
- AC6: Three batch tests run two inputs through `lms_chat_batch(api_type = "openai", schema = ...)`. The `"list"` format returns two `list(score = 3L)` values. The `"vector"` format warns and returns the list, once for an object reply and once for the scalar `3`. The `"data.frame"` format has an `output` list-column of parsed values. All pass.
- AC7: `man/rlmstudio-conditions.Rd` names `lms_embed()` and `lms_chat_openai()` as the two raisers of `rlmstudio_bad_response`. `man/lms_chat_openai.Rd` carries the "Malformed response" section. `NEWS.md` has three `schema` entries. `devtools::document()` left `git status` clean. `devtools::check()` with the token set: 0 errors, 0 warnings, 0 notes.
- Consistency gate: `cairn_validate.py` passed, exit 0. No DESIGN principle changed, so `cairn_impact` was skipped. README.md and README.Rmd are untouched and share one commit. The repo has no `_pkgdown.yml`. The branch adds no top-level file, and `data-raw/` is already in `.Rbuildignore`.

Independent review, three fresh reviewers. The blame-history reader found nothing that undoes a past milestone or a D-entry. The prior-review reader checked the M013 findings on the same files and found none reintroduced. GitHub holds no human review comments. The diff reader reported 13 findings, ranked most severe first. Proposed dispositions, pending the gate:

- R1: `lms_chat_batch()` reads `args[["api_type"]]` by exact name, but `lms_chat()` matches a shortened name such as `api = "openai"`. The batch then aborts on a call that `lms_chat()` accepts. Proposed: fix now.
- R2: `args$logprobs` in the batch misses a shortened `log = TRUE` that `lms_chat()` matches. The `output` column then holds `lms_chat_result` objects. The logprobs read predates the branch. Proposed: fix now with R1.
- R3: The default `format = "vector"` warns on every batch call with a schema. AC6 plans this. Proposed: reject, planned behavior.
- R4: The `lms_chat()` `@return` still says `simplify = TRUE` with `logprobs = FALSE` returns one string. With a schema it returns a parsed value. Proposed: fix now.
- R5: One reply that fails to parse aborts the whole batch and loses the results so far. A reply cut off by `max_tokens` shows as "not valid JSON" with no mention of `finish_reason`. Proposed: follow-up candidate row.
- R6: The abort hint says to call again with `simplify = FALSE`, but a second call to a model can return a different reply. Proposed: follow-up, folded into the R5 row.
- R7: Only a top-level empty schema becomes `{}`. A nested `properties = list()` goes out as `[]`. Proposed: follow-up candidate row.
- R8: A `schema` given by position falls into `...` without a name and `modifyList()` drops it without a message. This is how `...` already behaved. Proposed: reject, pre-existing.
- R9: Duplicate names and a classed list pass the form check. The server judges schema content (D-003). Proposed: reject.
- R10: An empty or missing `choices` fails with a subscript error and no package class. The NEWS line about bad content reads broader than that. Proposed: follow-up candidate row.
- R11: Some expected values come from `parse_json()` itself, batch tests send one reply to every input, and the `NULL` case in the valid-schema test cannot fail. Fixed values are stated apart for the object and `"null"` replies, which meets the check-discrimination rule. Proposed: reject, mixed-batch coverage folded into the R5 row.
- R12: NEWS adds a blank line between the new bullets and the older ones, and one roxygen line in `R/conditions.R` runs long. The vector-format NEWS claim is already qualified by `logprobs = FALSE`. Proposed: fix the blank line now, reject the rest as style.
- R13: The recorder script deletes the old cassette before `lms_load()` runs. If the load or the recording fails, the cassette is gone with no replacement. Proposed: fix now.
