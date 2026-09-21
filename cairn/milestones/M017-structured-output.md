# M017: The OpenAI chat call takes a JSON schema and returns the parsed answer

- **Status:** in-progress
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

- [ ] AC1: `lms_chat_openai()` gains a `schema` argument after `...`. With
      `schema` set, the body sent to `v1/chat/completions` carries
      `response_format`. It has `type` `"json_schema"` and a `json_schema`
      object. That object holds `name` `"response"`, `strict` `true`, and the
      given schema as `schema`. With `schema = NULL`, the body has no
      `response_format` key. Tests in `tests/testthat/test-chat-schema.R`
      assert both bodies on the raw request bytes. One test gives `required`
      as `list("score")` and asserts that it arrives as a JSON array.
- [ ] AC2: With `schema` set, `simplify = TRUE`, and `logprobs = FALSE`,
      `lms_chat_openai()` returns the value of
      `jsonlite::parse_json(content, simplifyVector = TRUE)`. Here `content`
      is `choices[[1]]$message$content`. With `simplify = FALSE`, it returns
      the parsed response list, and the content stays a string. With
      `logprobs = TRUE`, it returns an `lms_chat_result` whose `text` is the
      unparsed string. A recorded live response covers the first two cases.
      Mocked responses cover a JSON object, array, and scalar reply, and the
      `logprobs = TRUE` case.
- [ ] AC3: With `schema` set, `simplify = TRUE`, and `logprobs = FALSE`,
      `lms_chat_openai()` aborts on content that is not a single string. It
      also aborts on content that `jsonlite::parse_json()` fails to parse.
      The abort has class `rlmstudio_bad_response` and an integer `status` of
      200. Tests fire it for invalid text, an empty string, a JSON `null` in
      the content field, and a URL string. Each test asserts the class and
      the field. The string `"null"` is valid JSON, so the call returns
      `NULL` for it, and a test pins that.
- [ ] AC4: A `schema` fails the form check unless it is `NULL`, an empty
      list, or a list that is not a data frame and has a non-empty,
      non-missing name on every element. A failed form check makes `lms_chat_openai()`,
      `lms_chat()`, and `lms_chat_batch()` abort before the server probe, with
      no package condition class. A `schema` passed with a `response_format`
      in `...` aborts the same way. Tests in
      `tests/testthat/test-arg-guards.R` cover each of the three functions.
      They fire a string, an unnamed list, a partly named list, a list with
      an `NA` name, a data frame, and the `response_format` clash. A server probe stub counts its calls,
      and each test asserts a count of zero.
- [ ] AC5: `lms_chat()` takes `schema` and forwards it to
      `lms_chat_openai()`. A valid `schema` with `api_type` set to
      `"openresponses"` or `"native"` makes `lms_chat()` abort before the
      server probe. The message names `api_type = "openai"`. The AC4 form
      check runs first. `lms_chat_batch()` runs the same check before its own
      server probe. In both functions, tests fire the abort for each of the two
      values and for the default `api_type`. A server probe stub counts its
      calls in each. One test shows that an invalid `schema` with the
      default `api_type` raises the form fault.
- [ ] AC6: `lms_chat_batch()` forwards `schema` to `lms_chat()`. The rest of
      this criterion holds with `schema` set, `simplify = TRUE`, and
      `logprobs = FALSE`. `format = "list"` returns one parsed value per
      input. With `format = "vector"`, it warns and returns that list for
      every reply type. With `format = "data.frame"`, the `output` column is
      a list of parsed values. A test covers each format. The vector test
      runs once with an object reply and once with a scalar reply.
- [ ] AC7: The `rlmstudio-conditions` help page describes both raisers of
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
- [ ] T3: Write `data-raw/record-schema-cassette.R` on the model of
      `data-raw/record-embed-cassette.R`. Record one structured reply from a
      live LM Studio into a new cassette directory. Add the recorded tests for
      AC2. The live run needs `RLMSTUDIO_API_TOKEN` set (LESSONS, M009).
- [ ] T4: Add `schema` to `lms_chat()`, the `api_type` check after the form
      check, and the forward to `lms_chat_openai()`. Probe the abort route,
      which has no delegate (LESSONS, M013).
- [ ] T5: When `schema` is set, make `lms_chat_batch()` warn and return a
      list for `format = "vector"`. Make it return an `output` list-column for
      `format = "data.frame"`. Add a test per format.
- [ ] T6: Document `schema`. A one-element array is written as `list()` or
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

## Decisions

## Review
