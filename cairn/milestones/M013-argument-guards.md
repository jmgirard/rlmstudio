# M013: A bad model or text argument aborts with a message that names the mistake

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — the guards change what ten exported functions do with a bad argument
- **Branch/PR:** m013-argument-guards

## Goal

Give every exported function that takes a model name, a job id, or a text input
a guard that names the faulty argument instead of passing the value to the
server.

## Scope

**In:** two internal guard helpers in `R/utils-args.R`; the character-scalar
rule wired into the nine functions with a `model` formal and into
`lms_download_status(job_id)`, replacing the two `||` guards in `R/download.R`
that themselves error on a length-two vector; the text rule wired into
`lms_embed()`, `lms_chat_batch()`, `lms_chat()`, `lms_chat_openresponses()`,
and `lms_chat_native()`; a test that reads the domain from NAMESPACE rather
than from a hand-written list; help-page and `NEWS.md` text.

**Out:** a guard on `lms_chat_openai(messages)`, whose argument is a list →
candidate row. A length rule on the chat wrappers' `input`, which today sends
a length-two vector as a JSON array → candidate row. Chunked embedding
requests → the existing `chunk_size` candidate row. A condition class for
argument faults → rejected at the plan gate, not deferred.

## Acceptance criteria

- [ ] AC1: Every exported function whose `formals()` carry `model` or `job_id`
      aborts when that argument is not one character value holding at least one
      non-whitespace character. The probe set is a length-two character vector,
      a zero-length character vector, `NA_character_`, `""`, `"  "`, `NULL`, a
      number, `TRUE`, a list, and a factor; each aborts with a message naming
      the argument and the rule it broke, whether the argument is supplied
      positionally or by name. The domain is fixed by a test that reads the
      exports from NAMESPACE and keeps the names whose `formals()` carry
      `model` or `job_id`; that test builds each call from a placeholder table
      and raises a failure, never a skip, when an enumerated function has a
      required formal the table holds no placeholder for.
- [ ] AC2: `lms_embed()` and `lms_chat_batch()` abort when `input` or `inputs`
      is not a character vector, has length zero, or holds an `NA`, with probes
      for a length-one `NA_character_` and for an `NA` first, last, and alone
      among several values. `lms_chat()`, `lms_chat_openresponses()`, and
      `lms_chat_native()` abort when `input` is a character vector holding an
      `NA`, and pass a non-character value through unchanged, so a structured
      OpenResponses message list still reaches the server. Each abort message
      names its own argument.
- [ ] AC3: No HTTP request leaves the process for any abort in AC1 or AC2. The
      probes run with `httr2::req_perform` mocked through
      `tests/testthat/helper-mock-http.R` to raise on any request, and each
      call aborts naming its argument rather than raising from that mock or
      from the missing server.
- [ ] AC4: The help page of each function named in AC1 and AC2 states the rule
      for its guarded argument, and `devtools::document()` leaves no diff.
- [ ] AC5: `devtools::test()` is clean, and the three `R-CMD-check.yaml` jobs
      pass on this milestone's pull request with zero errors and zero warnings.
      Any NOTE is written into the Review section with its cause.
- [ ] AC6: `NEWS.md` carries an entry for the new argument checks, with no
      milestone number in the user-facing text.

## Coverage

- AC1 → T1, T2, T4
- AC2 → T1, T3, T5
- AC3 → T4, T5
- AC4 → T6
- AC5 → T4, T5, T6
- AC6 → T6

## Tasks

- [x] T1: Add `R/utils-args.R` with two internal helpers: one for the
      character-scalar identifier rule and one for the text-vector rule. Each
      takes the value and the argument name and aborts through
      `cli::cli_abort(call = NULL)`, matching the guards at `R/embed.R:48` and
      `R/chat.R:383`. The aborts carry no condition class (plan gate). Add
      direct tests for every branch of both helpers.
- [x] T2: Call the identifier helper above `stop_if_no_server()` in the nine
      functions with a `model` formal — `lms_embed`, `lms_chat`,
      `lms_chat_openresponses`, `lms_chat_openai`, `lms_chat_native`,
      `lms_chat_batch`, `lms_load`, `lms_download`, `lms_unload` — and in
      `lms_download_status`. Delete the `||` guards at `R/download.R:44` and
      `R/download.R:140`.
- [x] T3: Wire the text helper: the strict form into `lms_embed()` and
      `lms_chat_batch()`, replacing today's guards, and the NA-only form into
      `lms_chat()`, `lms_chat_openresponses()`, and `lms_chat_native()`,
      applied only when the value is a character vector.
- [x] T4: Write `tests/testthat/test-arg-guards.R`: read the exports from
      NAMESPACE, keep the `model` and `job_id` formals, build each call from a
      placeholder table, fail when a required formal has no placeholder, and
      run the AC1 probe set under a `req_perform` mock that raises on any
      request.
- [x] T5: Extend that file with the AC2 probes, including the NA positions and
      the pass-through case for a list `input`.
- [x] T6: Update the `@param` text on every touched help page, run
      `devtools::document()`, add the `NEWS.md` entry, and run
      `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-20: created by /milestone-plan.
- 2026-09-20: criteria audit ran in full mode (surface tier user-facing) and returned eleven findings. Seven had one clear answer and were fixed here: the whitespace rule contradicted its own case list; "any non-character value" quantified over every R type with nothing enumerating it; the placeholder-table criterion bound a test harness rather than the package; a local `devtools::check()` contradicted D-002 and D-005; "every NOTE justified" was unfalsifiable; the server-ordering probe tested a proxy; and the probe axes left positional supply and NA position unvaried. Three became gate questions and one was low-stakes wording.
- 2026-09-20: T2 and T3 landed in one commit, because their edits interleave in the same files. Every guard sits above `stop_if_no_server()`. The two `||` guards in `R/download.R` are gone, and `lms_download_status()` now checks `job_id` before the `already_downloaded` shortcut. Suite 517 pass, 0 fail; no existing test asserted the two deleted messages.
- 2026-09-20: T4 done. `tests/testthat/test-arg-guards.R` reads the domain from `getNamespaceExports()` and `formals()`, and `local_guard_only()` forces the server probe to succeed while `local_no_request_allowed()` raises on any request, so an abort naming the argument can only have come from the guard. Deleting the guard in `R/unload.R` turns the file red, so it is load-bearing. `baseline_args()` takes its table as an argument, following D-006's pattern, and a test drives the missing-placeholder branch to prove it fails rather than skips.
- 2026-09-20: T5 done. The AC2 probes cover a non-character and a zero-length value on the strict pair, an NA alone, first, middle, last, and doubled on all five, and the structured-list pass-through on the three chat wrappers, which proves itself by reaching the raising request mock. A test asserts the strict and loose lists together equal the NAMESPACE-read text domain, so a sixth `input` formal turns it red. Deleting the guard from `lms_chat_native()` and from `lms_embed()` each turned the file red.
- 2026-09-20: T6 done. The `@param` text on all ten functions states its rule, `NEWS.md` carries three entries including the two changed messages in `R/download.R`, `devtools::document()` is idempotent, and `devtools::check()` reports 0 errors, 0 warnings, 0 notes.
- 2026-09-20: claim audit: 43 claims read, 3 corrected — NEWS.md, tests/testthat/test-arg-guards.R, tests/testthat/test-utils-args.R. The NEWS sentence overclaimed that a two-name vector used to reach the server on every function, when the two `R/download.R` guards raised a base R coercion error instead; the `local_guard_only()` comment claimed an abort naming the argument could only come from the guard, when the omitted-argument test matches R's own missing-argument error; and the brace probe in `test-utils-args.R` passed a valid value, so `cli_abort()` never ran and nothing was proved. The re-read confirmed all three, and took the reader's smaller wording fix on the first.
- 2026-09-20: plan gate chose unclassed aborts over a new `rlmstudio_bad_argument` condition class because a bad argument is a programming error a batch caller cannot recover from at runtime; falsified by a user who needs to catch an argument fault by class in a pipeline.
- 2026-09-20: plan gate chose a text rule split by semantics over one character-only rule for all five functions because `input` is a named formal that GP4's dots cannot reach, so a type check there is a permanent API restriction; falsified by evidence that LM Studio rejects the structured OpenResponses input form.
- 2026-09-20: plan gate chose to fold `lms_download_status(job_id)` into this scope over a candidate row because it carries the identical broken `||` guard; falsified by the two guards needing different rules.
- 2026-09-20: plan chose a NAMESPACE-driven enumerating test over nine per-function tests because a hand-written list is a proxy that a tenth wrapper escapes; falsified by the placeholder table growing harder to maintain than the guards it covers.
- 2026-09-20: T1 done. `R/utils-args.R` holds `rlm_check_id()`, `rlm_check_text()`, and `rlm_check_no_na()`; `id_fault()` returns plain text rather than a cli string, so a name carrying braces cannot reach cli as a format string (LESSONS, M012). 32 direct tests in `tests/testthat/test-utils-args.R`; suite 517 pass, 0 fail.
- 2026-09-20: plan chose to place each guard above `stop_if_no_server()` over leaving the server probe first because an argument fault is knowable without a server; falsified by a caller who relies on the server abort firing first (GP3).

## Decisions

## Review
