# M037: The chat functions refuse a stream field before any request

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3, GP4
- **Resolves:** —
- **Surface tier:** user-facing — five exported chat functions start to reject an argument value that they sent before
- **Branch/PR:** m037-chat-stream-guard

## Goal

A chat call with a `stream` in `...` other than `FALSE` or `NULL` aborts
before the server probe. Today it fails as a bad response after the request.

## Scope

**In:** a check on every `stream` field in the `...` of
`lms_chat_openresponses()`, `lms_chat_openai()`, `lms_chat_native()`, and
`lms_chat_batch()`. The check runs above `stop_if_no_server()` (D-008). `lms_chat()`
gets the check through the function it calls. The abort has no condition
class. Help text at `...` of all five functions, a NEWS entry, and D-023.

**Out:** streaming support over Server Sent Events stays the `[low]`
candidate row. The length rule on `input` stays its own candidate row. Checks
on other `...` fields stay with the server (D-003).

## Acceptance criteria

- [x] AC1: For every export whose name starts with `lms_chat`, as
      `getNamespaceExports("rlmstudio")` lists them, a `stream` in `...`
      with any of the values `TRUE`, `1`, `0`, `"true"`, `"false"`, `NA`,
      `logical(0)`, or `c(FALSE, TRUE)` aborts with an error. No class of
      that error starts with `rlmstudio_`, and its message names `stream`. So does `stream = FALSE, stream = TRUE`.
      `lms_chat()` and `lms_chat_batch()` show this for each of the three
      `api_type` values. A test in `tests/testthat/test-arg-guards.R` runs
      each case with `is_server_running()` mocked to return `FALSE`. It also
      mocks `httr2::req_perform()` to fail on any call. The test sees the
      stream abort, not `rlmstudio_no_server` and not a request.
- [x] AC2: Take each export that AC1 enumerates, and `lms_chat()` and
      `lms_chat_batch()` on each `api_type`. A call with `stream = FALSE`
      or `stream = NULL` in `...` does not abort, and it sends its request.
      With `FALSE`, every request body sent holds `"stream":false`. With
      `NULL`, no request body sent holds a `stream` field.
- [x] AC3: The help page in `man/` of each export that AC1 enumerates says,
      at its `...` argument, that the package checks a `stream` there, and
      that a `stream` other than `FALSE` or `NULL` aborts before the server
      probe.
- [x] AC4: `devtools::test()` passes with no failures, and
      `devtools::check()` gives 0 errors and 0 warnings.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T2
- AC3 → T3
- AC4 → T3

## Tasks

- [x] T1: Append D-023 to `cairn/DECISIONS.md`: the package checks a
      `stream` in `...`. This narrows D-003 and trades GP4. A named
      argument whose one legal value is `FALSE` adds nothing. D-023 annotates
      the `stream = TRUE` examples in the Consequences of D-015 and D-019.
      Then write the failing tests for AC1 and AC2 in
      `tests/testthat/test-arg-guards.R`. Use `local_no_request_allowed()`
      and the request recorder in `tests/testthat/helper-mock-http.R`.
- [x] T2: Add `rlm_check_stream(dots)` to `R/utils-args.R`. It aborts when
      any element named `stream` is neither `NULL` nor
      `identical(x, FALSE)`.
      Call it above `stop_if_no_server()` in the
      three direct functions (`R/chat.R:184`, `:342`, `:912`) and in
      `lms_chat_batch()` on the `rlm_chat_dots()` result (`R/chat.R:1195`).
      Tests green. Per the M003 lesson, delete each call site in a scratch
      copy and see its test go red.
- [x] T3: Write the `...` help text on the five functions, run
      `devtools::document()`, and add a `NEWS.md` bullet. Start the server
      and set `RLMSTUDIO_API_TOKEN` (M009 lesson). Then run
      `devtools::test()` and `devtools::check()`.

## Work log

- 2026-09-27: created by /milestone-plan.
- 2026-09-27: criteria audit (full mode, fresh reader) returned 6 findings. Five fixed at the gate: value and form probes widened, `api_type` routes and a duplicate `stream` added to AC1, AC2 reworded from the harness to the sent body, AC3 names the server probe, NEWS and D-entry tasks added. The value rule went to the gate. No finding on AC4 or the function domain.
- 2026-09-27: plan gate chose to abort every `stream` but `FALSE` or `NULL` over `isTRUE()` values only because the package reads a whole reply and cannot know how the server reads `1` or `"true"`; falsified by a server that treats such a value as off.
- 2026-09-27: plan gate chose a check on `...` with D-023 over a named `stream = FALSE` argument (GP4) because a formal with one legal value adds nothing and the streaming candidate must then redefine it; falsified by a user who needs `stream` documented as an argument.
- 2026-09-27: plan chose to leave `lms_chat()` without its own check over a check at its top because each route delegates to a checked function before any probe; falsified by a route of `lms_chat()` that reaches the probe or a request without a checked delegate.
- 2026-09-27: T1 done. D-023 appended. The stream abort test is red on `rlmstudio_no_server` from `lms_chat_openresponses()`, and the FALSE and NULL test passes on the current code.
- 2026-09-27: T2 done. `rlm_check_stream()` runs in the three direct functions and in `lms_chat_batch()`. The batch reads the raw `list(...)`, because `rlm_chat_dots()` keeps only the first of two same-named values, which the duplicate probe caught. Deleting each of the four call sites in a scratch copy turned the test red. `devtools::test()`: 10194 passed, 0 failed.
- 2026-09-27: amendment (mini gate): AC3 no longer says that `stream` is the one checked field in `...`, because `lms_chat_openai()` refuses a `response_format` next to `schema` and `lms_chat_native()` warns on and drops a `logprobs`. The user chose narrowing over listing every checked field.
- 2026-09-27: re-audit: AC3 (full) — nothing. The reader noted that "server probe" is internal wording, and AC3 binds the meaning, not the words.
- 2026-09-27: T3 done. Help text at `...` on the five chat pages, `stream` added to the argument list of the conditions page's "Server not running" section, and a NEWS bullet. The help says "before the call checks for a running server" in place of "server probe". `devtools::test()`: 10194 passed, 0 failed. `devtools::check()`: 0 errors, 0 warnings, 0 notes. `document()` still warns on the `@aliases` tag at `R/conditions.R:257`, as the existing candidate row records.
- 2026-09-27: claim audit: 26 claims read, 3 corrected — R/utils-args.R, tests/testthat/test-arg-guards.R. Two comments said that the server can read a second `stream` and that any value other than `FALSE` makes the server stream. A test comment rested on the first. The same reader re-read all three and found them correct.
- 2026-09-27: implement complete, status review. `devtools::test()`: 10194 passed, 0 failed. `document()` gives no diff.

## Decisions

## Review

Pass 1, 2026-09-27, on `m037-chat-stream-guard` at `b0bd31a`, with main unmoved since the branch was cut.

- AC1: `test_file("tests/testthat/test-arg-guards.R")`. "a stream other than FALSE or NULL aborts before the server probe" ran 244 expectations, 0 failed, and the probe count stayed 0. The domain test lists the five `lms_chat*` exports from `getNamespaceExports()`. Pass.
- AC2: in the same run, "stream = FALSE is sent and stream = NULL is left out" ran 60 expectations, 0 failed, and covered every export and each `api_type` of `lms_chat()` and `lms_chat_batch()`. Pass.
- AC3: a Python parse of the `\item{...}` entry of each of the five `man/lms_chat*.Rd` pages found "The package checks a \code{stream} here" and "other than \code{FALSE} or \code{NULL} aborts before the call checks for a running server" on all five. Pass.
- AC4: `devtools::test()` with the server running and the token set passed 10194 tests with 0 failed, 0 errors, and 0 skipped. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. Pass.
- Gate: `cairn_validate` passed all checks, and `devtools::document()` gave no diff. `pkgdown::check_pkgdown()` found no problems. README is untouched, NEWS has the entry, and there is no new top-level file. DESIGN is unchanged, so `cairn_impact` was not run.
- Lenses: diff-bug [O] reported 8 items. Blame-history [S] found nothing. Prior-review [S] found no prior-review evidence (no PR comments, and no archived finding reintroduced).

