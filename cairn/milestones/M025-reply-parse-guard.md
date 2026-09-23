<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M025: A model-management reply that does not parse as JSON aborts with rlmstudio_bad_response

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** IP1, GP2   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — five exported functions change the error they raise, and two change what they accept   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m025-reply-parse-guard   <!-- owner: implement (branch) / review (PR URL) · create -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

Every reply parse reads JSON text only, so a status-200 body that is not JSON
aborts the model-management functions with `rlmstudio_bad_response`.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** One low-level parse for every HTTP reply body. It reads the body text
as UTF-8 and parses it with `jsonlite::parse_json()`, which reads JSON text
only (D-016). `parse_ok_body()`, `api_error_message()`, and
`lms_server_ready()` use it. The four functions in the goal parse their
status-200 body through `parse_ok_body()`. `lms_unload_all()` and
`lms_load()` without `force` get the abort through `list_models()`. Help page
and NEWS.

Background. `parse_ok_body()` called `httr2::resp_body_json()`, which calls
`jsonlite::fromJSON()` on the body text. If that text is under 2084 bytes, is
not valid JSON, and starts with `http://` or `https://`, `fromJSON()` fetches
it. If it names an existing file, `fromJSON()` reads the file. On 2026-09-22 a
200 body that held the path of a temp JSON file made `parse_ok_body()` return
the content of that file. A fetch calls a host the user never named (IP1).

**Out:**
- A reply that parses as JSON but has the wrong shape, such as `{}`, in the
  four functions. That work is a new candidate row.
- The `fromJSON()` call at `R/serve.R:394`. It parses the output of the `lms`
  CLI, not an HTTP reply, and stays as it is.
- A length bound on a non-JSON failure body. That work stays in its existing
  candidate row.
- `request_target()` in the test helpers. That work stays in its existing
  candidate row.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: Four functions abort with `rlmstudio_bad_response` on a status-200
      body that does not parse as JSON. They are `list_models()`,
      `lms_load()`, `lms_download()`, and `lms_download_status()`. The
      condition's `status` is `200L`. The message contains
      `did not parse as JSON` and `answering on this host`. A test runs each
      function over three bodies: an HTML page, JSON text that stops part
      way, and an empty body. It calls `lms_load()` with `force = TRUE`, so
      the load reply is the body under test.
- [ ] AC2: The condition of the AC1 abort holds no copy of the body text. A
      test puts a marker string in a cut-off JSON body, next to where the
      parse stops, and sends it to each AC1 function. It asserts that the
      marker is in neither `conditionMessage()` nor any field of the
      condition.
- [ ] AC3: If the model-list body does not parse as JSON, `lms_load()`
      without `force` and `lms_unload_all()` abort with
      `rlmstudio_bad_response`. A test pins each of the two.
- [ ] AC4: Valid JSON sent as `text/plain` reads as JSON. For each of
      `lms_load(force = TRUE)`, `lms_download()`, `lms_download_status()`, and
      `lms_server_ready()`, a test sends one body under `text/plain` and under
      `application/json` and compares the results with `expect_identical()`.
      A status-400 body `{"error": {"message": "MARKER"}}` under `text/plain`
      gives an `rlmstudio_api_error` whose message contains `MARKER` and no
      `{`. A test pins that through `lms_load(force = TRUE)`.
- [ ] AC5: No reply parse site reads a body as a file path or fetches it as a
      URL. The sites are the lines of `R/` that read an HTTP reply and that
      `grep -nE 'fromJSON|resp_body_json|parse_json|resp_body_string' R/`
      lists. The work log records that list. For
      each site, a test sends three bodies: the path of a temp file that holds
      a valid reply, an `http://` URL, and an `https://` URL. At status 200,
      each function aborts with `rlmstudio_bad_response`, and
      `lms_server_ready()` returns `FALSE`. At status 400, the message does not
      contain the file's content. With `base::url` mocked to count calls, the
      test asserts zero calls.
- [ ] AC6: The `rlmstudio-conditions` help page names `list_models()`,
      `lms_load()`, `lms_download()`, `lms_download_status()`, and
      `lms_unload_all()` as raisers of `rlmstudio_bad_response` for a
      status-200 body that does not parse as JSON. The function counts in its
      `Malformed response` section match the functions it lists. It no longer
      says that those five raise an error with no class of this package for
      such a body. The Rd file of each of the five contains the
      `Malformed response` section. NEWS.md has an entry for AC1, AC3, AC4,
      and AC5.
- [ ] AC7: `devtools::test()` is clean, and `devtools::document()` produces
      no diff.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T2
- AC2 → T2
- AC3 → T2
- AC4 → T1, T2
- AC5 → T1, T2
- AC6 → T3
- AC7 → T1, T2, T3

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits) -->

- [x] T1: Shared parse. Tests first. Add a helper that reads the body with
      `httr2::resp_body_string(resp, "UTF-8")` and parses it with
      `jsonlite::parse_json()`, with a `simplifyVector` argument and nothing
      else. `parse_ok_body()` (`R/utils-api-error.R:178`),
      `api_error_message()` (`R/utils-api-error.R:46`), and
      `lms_server_ready()` (`R/serve.R:667`) call it. Rewrite the comments
      that describe the old parse: `R/utils-api-error.R:12-15` and `:159-165`,
      and `R/embed.R:89`. Write the AC5 tests for the chat functions,
      `lms_embed()`, the error-message path, and `lms_server_ready()`. Write
      the AC4 tests for `lms_server_ready()` and the error message. Record the
      AC5 site list in the work log.
- [x] T2: Four wrappers. Tests first, in `tests/testthat/test-body-parse.R`.
      `list_models()` (`R/list.R:69-70`) calls `parse_ok_body()` with
      `simplifyVector = TRUE`. `lms_load()` (`R/load.R:133`), `lms_download()`
      (`R/download.R:71`), and `lms_download_status()` (`R/download.R:147`)
      call `parse_ok_body()`. Write the AC1 to AC5 tests for these functions.
      `lms_load()` without `force` sends two requests (LESSONS, M008), and
      `lms_unload_all()` reaches `list_models()` (LESSONS, M003). The existing
      list, load, and download tests stay green.
- [ ] T3: Docs. Rewrite the two sections of `R/conditions.R` (`:26-39` and
      `:64-79`). Add `@inheritSection rlmstudio-conditions Malformed response`
      to the five functions. Add the NEWS entries. Run `devtools::document()`
      and `devtools::test()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-09-22: created by /milestone-plan.
- 2026-09-22: criteria audit, full mode, fresh [O] reader. It found 12 gaps, all fixed in the criteria. A grep criterion checked an instrument. The URL probe missed `https://`. The file probe did not see a read. The leak test read only the message. `list_models()` made the `text/plain` test vacuous. Two parse sites, the help page counts, UTF-8 decoding, and `lms_unload_all()` docs were missing. The header change in two functions went to the gate.
- 2026-09-22: plan gate chose to fix the file and URL read in M025 over a separate hotfix. The same helper carries both changes. Falsified by a regression in the chat routes that traces to the parser switch alone.
- 2026-09-22: plan gate chose to parse every reply by content over a header check in `lms_server_ready()` and `api_error_message()`. One parse rule then covers one body. Falsified by a server setup that sends a non-JSON-type body that `lms_server_ready()` must reject.
- 2026-09-22: plan chose `jsonlite::parse_json()` on the body text over `jsonlite::validate()` before `fromJSON()`. `parse_json()` never reads a file or a URL. Falsified by a body that `parse_json(simplifyVector = TRUE)` reads differently from `fromJSON(simplifyDataFrame = TRUE)`.
- 2026-09-22: started implementation on `m025-reply-parse-guard`. No implementation choice was open, so the question gate was skipped.
- 2026-09-22: T1 done. `parse_json_body()` in `R/utils-api-error.R` is the one reply parse, and `parse_ok_body()`, `api_error_message()`, and `lms_server_ready()` call it. `tests/testthat/test-body-parse.R` failed 10 times before the change and passes after it. The AC5 site list moves to T2, because T2 changes the sites. `devtools::test()` is clean.
- 2026-09-22: T2 done. `list_models()`, `lms_load()`, `lms_download()`, and `lms_download_status()` parse through `parse_ok_body()`. The new tests failed before the change and pass after it. A planted leak of the parser text into the message turned the no-copy test red, and the file was restored. `parse_json(simplifyVector = TRUE)` and `fromJSON(simplifyDataFrame = TRUE)` gave identical output on the recorded model list. `devtools::test()` is clean.
- 2026-09-22: AC5 site list. The code lines that the AC5 grep lists are `R/chat.R:507`, `R/serve.R:394`, `R/serve.R:667`, and `R/utils-api-error.R:44`, `:46`, `:169-171`, and `:209`. The HTTP reply sites are `:667` (`lms_server_ready()`), `:46` (`api_error_message()`), and `:209` (`parse_ok_body()`), and each has a file and URL test. `:169-171` is the shared parse that the three call. `:44` reads the raw text for the message fallback and parses nothing. `R/chat.R:507` parses reply content that is already out of the body, with `parse_json()`. `R/serve.R:394` parses CLI output.

## Decisions
<!-- owner: implement / review · append-only; milestone-local -->

## Review
<!-- owner: review · exclusive -->
