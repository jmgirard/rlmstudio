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

- [x] AC1: Every exported function whose `formals()` carry `model` or `job_id`
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
- [x] AC2: `lms_embed()` and `lms_chat_batch()` abort when `input` or `inputs`
      is not a character vector, has length zero, or holds an `NA`, with probes
      for a length-one `NA_character_` and for an `NA` first, last, and alone
      among several values. `lms_chat()`, `lms_chat_openresponses()`, and
      `lms_chat_native()` abort when `input` is a character vector holding an
      `NA`, and pass a non-character value through unchanged, so a structured
      OpenResponses message list still reaches the server. Each abort message
      names its own argument.
- [x] AC3: No HTTP request leaves the process for any abort in AC1 or AC2. The
      probes run with `httr2::req_perform` mocked through
      `tests/testthat/helper-mock-http.R` to raise on any request, and each
      call aborts naming its argument rather than raising from that mock or
      from the missing server.
- [x] AC4: The help page of each function named in AC1 and AC2 states the rule
      for its guarded argument, and `devtools::document()` leaves no diff.
- [ ] AC5: `devtools::test()` is clean, and the three `R-CMD-check.yaml` jobs
      pass on this milestone's pull request with zero errors and zero warnings.
      Any NOTE is written into the Review section with its cause.
- [x] AC6: `NEWS.md` carries an entry for the new argument checks, with no
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
- 2026-09-20: review ran. Three lenses reported 25 findings. Eleven were fixed on the branch, one became a candidate row, seven were rejected with reasons, and six were verified non-findings. One rejection is a refutation: `lms_unload_all()` already filters NA and empty keys before the loop. The return floor did not fire.
- 2026-09-20: step-7 approval: m013-argument-guards approved for merge.
- 2026-09-20: the eleven gate repairs landed. Suite 1186 pass, 0 fail, 0 skip, against 1017 before them. `devtools::document()` idempotent. `air format --check` clean on every file this branch touched. Four planted defects each turned the suite red, so the new checks discriminate.

## Decisions

## Review

Run on 2026-09-20 against `m013-argument-guards` at c1eec6a. The default branch
had not moved under the branch.

### Criterion evidence

- AC1: met after the gate repairs below. On the first pass it was not met as
  worded. The ten named probes all aborted, on all ten functions the NAMESPACE
  read returns, supplied by name and supplied first and positionally. The
  domain assertion named the same ten functions. What failed was the rule the
  criterion states, not the probe set it enumerates. The strings `"\f"` and
  `"\v"` hold no non-whitespace character under R's `[[:space:]]` class.
  `rlm_check_id()` passed both, because `trimws()` strips only space, tab,
  carriage return, and line feed. A one-by-one character matrix passed as
  well. See findings D5 and D6 below. The string `" "` never broke the
  rule. R does not class a non-breaking space as whitespace here, so that
  string holds a non-whitespace character. After the repairs, all thirteen
  identifier probes abort on all ten functions.
- AC2: met. 532 assertions ran across `test-arg-guards.R` and
  `test-utils-args.R`, with 0 failed and 0 skipped. The strict pair rejects a
  non-character value, a zero-length value, and an `NA`. The `NA` probes place
  it alone, first, in the middle, last, and doubled. The three chat wrappers
  reject the same `NA` positions. They pass a structured list through, which
  proves itself by reaching the raising request mock. Each abort names its own
  argument.
- AC3: met. Every probe runs under `local_guard_only()`. That helper forces
  `is_server_running()` to `TRUE`. It also mocks `httr2::req_perform` through
  `local_no_request_allowed()` in `tests/testthat/helper-mock-http.R`, which
  raises on any request. No probe raised from that mock.
- AC4: met. All ten help pages state the rule for their guarded argument. The
  rules were read out of `man/*.Rd` rather than out of the roxygen source.
  Nine pages state the `model` rule, `lms_download_status` states the `job_id`
  rule, and the five text functions state the `input` or `inputs` rule.
  `devtools::document()` left `git status` clean.
- AC5: the local half is met and the CI half is pending. `devtools::test()`
  reports 1017 pass, 0 fail, 0 warn, and 0 skip. `devtools::check()` reports 0
  errors, 0 warnings, and 0 notes, so no NOTE is owed a cause here. The three
  `R-CMD-check.yaml` jobs run only on a pull request. This repo opens the pull
  request after the merge approval, so the CI half is verified at the green-CI
  requirement that comes before the merge.
- AC6: met. `NEWS.md` carries three entries for the argument checks under the
  development heading. No milestone number appears anywhere in the file. The
  first entry overclaims one fact about old behavior. See finding D2 below.

### Consistency gate

`cairn_validate.py` exited 0. Every check returned PASS and every advisory
returned OK. That includes `coverage complete` and `binding criteria`. The
`release window` advisory did not fire. No `DESIGN.md` principle changed on
this branch, so `cairn_impact.py` was skipped.

The toolchain slot ran as follows. `devtools::document()` produced no diff. No
generated file was hand-edited. The branch never touched `README.Rmd`, and it
added no export, so no re-knit is owed. `pkgdown::check_pkgdown()` reports no
problems. `NEWS.md` carries the changelog entry. The three added files are not
top-level, so no `.Rbuildignore` entry is owed. `devtools::check()` is clean.

One deviation from the Air convention stands. `air format --check` names the
three files this branch adds as unformatted. The reformatting is line wrapping
alone. The same command names five files the branch never touched, so the drift
predates this branch.

### Independent review

Three fresh-context reviewers ran on distinct evidence bases. The prior-review
lens found no archived `## Review` finding on the touched files that this diff
regresses. Its GitHub probe returned no inline review comments at all, so that
lens contributed no findings. The other two lenses reported 25 findings between
them. Each one is logged below with its disposition. The D numbers are the
diff-bug lens. The H numbers are the blame-history lens.

- D1 fix now. `R/chat.R:51`. When `api_type` is `"openai"`, the
  `rlm_check_no_na(input, "input")` call in `lms_chat()` is the only `NA` check
  on that path, because `lms_chat_openai()` guards `model` alone. No probe in
  `test-arg-guards.R` ever sets `api_type`, so deleting that line leaves the
  file green. Confirmed two ways. The test file holds no occurrence of
  `api_type`, and the call does abort today.
- D5 fix now. `R/utils-args.R:56`. `trimws()` strips only space, tab, carriage
  return, and line feed. A string of form feeds or vertical tabs therefore
  passes a rule worded as "at least one non-whitespace character". Confirmed by
  call. This finding is what leaves AC1 unmet.
- D6 fix now. `R/utils-args.R:45`. The test `length(value) != 1L` does not read
  `dim(value)`. So `matrix("a-model")` passes, and `jsonlite` then writes
  `{"model":[["a-model"]]}`. Confirmed by call.
- D11 fix now. `R/utils-args.R:42`. The article is fixed at "a". An integer
  argument therefore reports "You gave a integer value." Confirmed by call.
- D8 fix now. `tests/testthat/test-arg-guards.R:165`. The omitted-argument test
  asserts only that the message names the argument. R's own missing-argument
  error already satisfies that, so the test proves nothing about the guards
  while its title says otherwise. The work log already corrected the comment in
  `local_guard_only()` to admit this, and left the title standing.
- D15 fix now. `tests/testthat/test-arg-guards.R:200`. The strict-text probes
  omit a factor. A factor is the likeliest real accident, and the identifier
  probes do include one.
- D16 fix now. `R/utils-args.R:14`. The code passes `fault` as a literal
  bullet. That is brace-safe only because the detail never embeds the caller's
  value. Interpolating the detail instead makes the safety structural.
- D2 fix now. `NEWS.md:4`. The closing sentence says that a two-name vector
  "sent both to the server" on all eight unguarded functions. That holds for
  `lms_load()` when no model is loaded, and when `force` is `TRUE`. It does not
  hold when a model is loaded. `model %in% active_models$key` then feeds a
  length-two logical to `&&`, and R raises its own coercion error first. The
  sentence narrows.
- D17 fix now. `NEWS.md:4`. The opening sentence reads wider than the code.
  `lms_chat_openai(messages)` is out of scope, and a zero-length character
  `input` still goes out on the three chat wrappers. Both gaps carry candidate
  rows. The sentence fences them off.
- D3 and H1 fix now, as one repair. `R/conditions.R:9` says that functions
  which call the REST API "first open a TCP connection". That section is
  inherited onto all ten guarded help pages. Every guard now runs above
  `stop_if_no_server()`. A bad argument sent while the server is down therefore
  raises an unclassed error rather than `rlmstudio_no_server`. The plan gate
  traded GP3 knowingly, but nothing shipped pins the new order. The text is now
  false, and `local_guard_only()` forces the server probe to succeed, so no
  test covers the new order. Fix the section and add a test that pins the
  order.
- D4 and H2 fix now, as one repair. D-007 rejected a bespoke unclassed abort,
  because a caller catches by class. M013 chose an unclassed abort. M013 also
  reversed the order that M001 set deliberately, which put
  `stop_if_no_server()` first. Both choices sit only in this milestone's work
  log. Once the file is archived, DECISIONS.md holds no record of either.
  Append a D-entry.
- Air formatting, fix now. The three added files fail `air format --check` on
  line wrapping alone, against a stated DESIGN convention. The repair is scoped
  to those three files. The five pre-existing failures are not this branch's
  work.
- D7 follow-up. `tests/testthat/test-arg-guards.R:135`. An `expect_error()`
  whose call raises a non-matching error aborts the enclosing `test_that()`. So
  deleting all ten guards reports one failure at `lms_chat` and never probes
  the other nine. The file still turns red. Only the diagnostics are coarse.
- D9 rejected. The extra `expect_error(do.call(fn, bad), target)` is weak,
  because "input" matches "inputs" and "model" appears in unrelated messages.
  The `probe$match` assertion on the same inputs already carries the
  discrimination. This is redundancy, not a defect.
- D10 rejected. The NAMESPACE read catches only a formal spelled `model`,
  `job_id`, `input`, or `inputs`. AC1 scopes the domain to exactly those
  spellings. This is the criterion's stated reach, not a gap below it.
- D12 rejected, refuted. `lms_unload_all()` already drops `NA` and empty keys at
  `R/unload.R:143`. That filter runs before the loop that calls `lms_unload()`,
  so no server-reported bad key reaches the new guard mid-sweep.
- D13 rejected. Validating each batch item at three frames is redundant and
  cheap. That redundancy is why D1 exists, and D1 is the repair.
- D14 rejected. `lms_chat()` runs `match.arg()` before its guards, and
  `lms_chat_batch()` runs it after. The two therefore report different
  arguments when both are wrong. Each one reports a real fault, so neither is
  wrong.
- D18 not a finding. AC5's CI half cannot be judged locally, and the Review
  section was empty when the lens read it. Both points are answered above.
- H3 rejected. The two `R/download.R` messages changed text. The change is
  intentional, it is disclosed in `NEWS.md`, and D-001 waives the deprecation
  cycle before 1.0. No test on the default branch asserted either string.
- H4 rejected. The `already_downloaded` shortcut in `lms_download_status()`
  still sits after `stop_if_no_server()`, exactly as before. Only the `job_id`
  check moved ahead of both. The lens also quoted the new call as
  `rlm_check_id(job_id, "model")`. The code reads `rlm_check_id(job_id,
  "job_id")`.
- H5, H6, and H7 need no action. All three are verified non-findings.
  `rlm_check_text()` keeps the message that `test-embed.R` asserts, and it
  keeps the guard-before-server order that `lms_embed()` and `lms_chat_batch()`
  already had. `local_no_request_allowed()` follows the same
  `.package = "httr2"` pattern as the existing recorder, and it touches nothing
  that D-004, D-005, or D-006 governs. The brace probe reaches the length
  branch, so no caller value is interpolated.

No actioned finding shows an acceptance criterion failing inside the domain of
the procedure that criterion names. The return floor therefore does not fire,
and the milestone stays in review. AC1's rule is falsified only outside its
enumerated probe set, which is the shape of an amendment return. The criterion
is kept as written and the code is repaired to meet it. The repair is a
one-line widening of the whitespace test, not a promise the code cannot keep.

### Repairs made at the gate

The maintainer accepted the whole fix-now list at the triage gate on
2026-09-20. All eleven landed on the branch. D7 became a candidate row.

- `R/utils-args.R` reads the whole `[[:space:]]` class in place of `trimws()`,
  rejects a value carrying a `dim` attribute, and picks the article from the
  class name. The fault detail is now interpolated as a value rather than
  passed as a literal bullet, so braces inside it cannot reach cli as markup.
- `R/conditions.R` states that a function which checks its own arguments does
  that before it opens the connection, and that such an abort carries no
  condition class even when the server is down.
- `tests/testthat/test-arg-guards.R` gains a form feed, a vertical tab, and a
  one-by-one matrix in the identifier probes, a factor in the strict-text
  probes, four probes on the `openai` route of `lms_chat()`, and a test that
  runs every identifier probe with the server probe forced to fail. The
  omitted-argument test is retitled to the weaker fact it actually pins.
- `tests/testthat/test-utils-args.R` gains direct probes for the three widened
  branches, for the article, and for a class name carrying braces.
- `NEWS.md` narrows two sentences. The first now names `lms_load()` as the
  exception that raised a bare R error, and the second now names the two
  paths that stay unchecked.
- `cairn/DECISIONS.md` gains D-008, which records the unclassed abort and the
  order against the server probe, and names what falsifies each.
- Air formatted the four files this branch touched.

Four planted defects each turned the suite red, so the new checks discriminate.
Deleting the `NA` check from `lms_chat()` breaks the `openai` probes. Putting
`trimws()` back breaks the form-feed probe. Dropping the `dim` test breaks the
matrix probe. Moving `stop_if_no_server()` back above the guard in
`lms_unload()` breaks the server-down test.

AC1 now holds as written, so its box is ticked. The re-run reports 1186 pass, 0
fail, 0 warn, and 0 skip, against 1017 before the repairs. `devtools::check()`
and `air format --check` results are recorded in the work log.
