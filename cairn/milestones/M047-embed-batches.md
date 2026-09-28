# M047: The embedding function sends a long input in batches

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP2, GP3, GP4, GP6
- **Resolves:** —
- **Surface tier:** user-facing — it adds two arguments and changes the `simplify = FALSE` return of an exported function
- **Branch/PR:** m047-embed-batches

## Goal

`lms_embed()` splits its input into requests of at most `batch_size` texts and shows progress across them.

## Scope

**In:** `batch_size = 100` and `quiet = NULL` on `lms_embed()`, both after `...` (LESSONS, M017). Consecutive
inputs go out in order, one request per batch, and each batch's `index` values map back to input positions. A
server probe runs before each request, as `lms_chat_batch()` does through `lms_chat()`. Failures follow the chat
batch: a failed request leaves its rows `NA` and the call goes on (D-011), and a 401, 403, or 404 aborts at once
(D-019). A progress bar that honors `quiet`. With `simplify = FALSE`, a list of parsed bodies, one per request.
Help pages and a NEWS entry. The pre-1.0 waiver (D-001) covers the new `simplify = FALSE` shape.

The research behind the default ran on 2026-09-28 with nomic-embed-text-v1.5 on this machine. 1024 texts of 30
words took 12.2 s at 1 per request and 5.8 s at 8. They took 5.4 s at 32 and at 128, and 5.3 s in one request.
8000 texts in one request took 40.8 s with no error and no progress output. Vectors from batches of 1, 2, and 5
were identical to one request. LangChain (1000), the R `text` package (100), and LlamaIndex (10) all batch by a
count of texts.

**Out:** a text longer than the model's context. A 5000-word text against a 2048-token context returned a vector
with no error, and `usage` reported 0 tokens (observed 2026-09-28). Splitting such a text is a new candidate row.
Batching by token count rather than text count: no library surveyed does it, so nothing records it. Parallel
requests: none were asked for, so nothing records them.

## Acceptance criteria

- [ ] AC1: With `batch_size = 100`, a call with 250 named inputs sends three requests in order. They carry inputs
      1 to 100, 101 to 200, and 201 to 250. Each body carries `model`, `ttl`, a field from `...`, and `input` as a
      JSON array. Row `i` of the returned matrix holds the vector served for input `i`. A test through
      `local_request_sequence()` in `tests/testthat/helper-mock-http.R` asserts the three bodies and every row,
      and serves the second batch out of index order. A live test that skips without LM Studio finds the matrix
      from `batch_size = 2` for five texts equal to the one-request matrix within 1e-6.
- [ ] AC2: A bad `batch_size` aborts before the server probe, with a message naming `batch_size` and no condition
      class. A good value is one whole number from 1 to `.Machine$integer.max`. A test fires `NULL`, `NA`,
      `NA_real_`, `TRUE`, `"10"`, `c(1, 2)`, `0`, `-1`, `1.5`, `Inf`, and `2^31`. It asserts the message for each
      and asserts that the probe was not called.
- [ ] AC3: Some failed requests leave the rows of their inputs `NA`, and the call goes on. These are an
      `rlmstudio_bad_response` and an `rlmstudio_api_error` at a status other than 401, 403, or 404. The call then warns once
      and names the failed input positions. With `quiet = TRUE`, the warning still shows. When every request
      fails, the call aborts with the first failed condition, gives no warning, and adds no `results` field. A
      test covers each class, the positions in the warning, the `quiet = TRUE` warning, and the all-failed abort.
- [ ] AC4: Three aborts after a successful request carry a `results` field. The first is a lost server found by the
      probe before a later request. The second is a 401, 403, or 404. The third is a later request whose vectors
      differ in width from earlier ones, which aborts with `rlmstudio_bad_response`. `results` holds the matrix so far, with `NA` rows
      for the inputs not embedded. A test fires each of the three after one successful request and asserts the
      class and every row of `results`.
- [ ] AC5: With `simplify = FALSE`, the call returns a list of parsed bodies, one per request, in request order.
      The slot of a failed request holds its condition. The warning and the aborts of AC3 and AC4 apply, and an
      abort's `results` holds the list so far. A test asserts a list of three for 250 inputs at `batch_size = 100`,
      a list of one for three inputs, and the condition in a failed slot.
- [ ] AC6: `quiet = NULL` reads the option `rlmstudio.quiet`. When more than one request goes out and the call is
      not quiet, the call shows a progress bar. Its total is the number of inputs, and it moves once per request. A test mocks `cli::cli_progress_bar()` and `cli::cli_progress_update()`. It asserts one bar with
      a total of 250 and three updates for 250 inputs. It asserts no bar with `quiet = TRUE`, with the option set,
      or with one request.
- [ ] AC7: The `lms_embed()` help page no longer says the whole input travels in one request. It documents
      `batch_size`, `quiet`, the `NA` rows, the warning, the aborts, and the `simplify = FALSE` list. The
      conditions help page names `lms_embed()` among the functions whose abort carries `results`, and says that
      its `results` is a matrix or a list. NEWS.md has an entry that names the new `simplify = FALSE` shape.
      `devtools::document()` leaves no diff, `devtools::test()` is clean, and `devtools::check()` with
      `RLMSTUDIO_API_TOKEN` set reports no errors, warnings, or notes.

## Coverage

- AC1 → T2, T5
- AC2 → T1
- AC3 → T3
- AC4 → T2, T3
- AC5 → T4
- AC6 → T1, T4
- AC7 → T6

## Tasks

- [x] T1: Add `batch_size = 100` and `quiet = NULL` after `...` in `lms_embed()` (`R/embed.R`). Add a
      `rlm_check_batch_size()` in `R/utils-args.R` modeled on `rlm_check_ttl()`, but with no `NULL`. Call it
      before `stop_if_no_server()`. Tests first (AC2).
- [x] T2: Split `input` into consecutive batches and send one request per batch. Build each batch's rows with
      `embed_matrix()` against that batch's length, then place them at the batch's input positions. Abort on a
      width that differs from an earlier batch. Tests first (AC1, the width case of AC4).
- [x] T3: Probe the server before each request. Store a per-request `rlmstudio_bad_response` or
      `rlmstudio_api_error` outside 401, 403, and 404, fill its rows with `NA`, and warn once past `quiet`. Abort
      at once on 401, 403, or 404 and on a lost server, with `results`, as `lms_chat_batch()` does. If all
      requests fail, abort with the first condition. Tests first (AC3, AC4).
- [ ] T4: Return the list of parsed bodies under `simplify = FALSE`. For more than one request, add the progress
      bar through `is_quiet()`. Tests first (AC5, AC6).
- [ ] T5: Add the live test of AC1 that compares `batch_size = 2` with one request.
- [ ] T6: Rewrite the `lms_embed()` roxygen, update the `results` text in `R/conditions.R`, and add the NEWS
      entry. Run `devtools::document()`, `devtools::test()`, and `devtools::check()` with the token (AC7).

## Work log

- 2026-09-28: created by /milestone-plan.
- 2026-09-28: full criteria audit by a fresh [O] reader returned 11 findings, all fixed in the draft. They were a missing `quiet` argument, a width abort in conflict with AC3, no `results` rule, missing probe values, a recorder with one reply, unchecked body fields, an untested bar total, the conditions page, an unmapped live test, and D-019's early abort.
- 2026-09-28: plan chose batching by a count of texts over a token budget because every library surveyed counts texts and count needs no tokenizer. Falsified by a live request that fails on total tokens while each text fits.
- 2026-09-28: plan gate chose the name `batch_size` over `chunk_size` because "chunk" in embedding work names splitting one long text. Falsified by users who look for `chunk_size` and miss the argument.
- 2026-09-28: plan gate chose a default of 100 over one request by default because speed was flat from 8 texts per request upward. Falsified by a server or model on which 100 texts per request is measurably slower than one request.
- 2026-09-28: plan gate chose to keep going past a failed batch over stopping at the first failure because it follows D-011 and D-019 and keeps finished rows. Falsified by a user who needs the call to stop at the first failed batch.
- 2026-09-28: implement started on m047-embed-batches. No gate questions were open, because the plan gate settled the name, the default, and the failure rule.
- 2026-09-28: T1 done. `rlm_check_batch_size()` reuses `ttl_fault()` and rejects `NULL`. The eleven-value test went red with the check moved after the probe.
- 2026-09-28: T2 done. The loop in `R/embed.R` also carries the T3 and T4 code, because they share it. The two `simplify = FALSE` tests now expect a list of one. Four planted defects each turned `test-embed.R` red: overlapping batches, no width check, a named `input`, and rows placed by batch rank.
- 2026-09-28: T3 done. Tests cover a bad reply and an API failure mid-call, the warning under `quiet`, the all-failed abort, a lost server, and 401, 403, and 404 after a success and before one. Five planted defects each turned the file red. A 401 before any success carries no `results` field, the reading of AC4 that says the field follows a successful request.

## Decisions

## Review
