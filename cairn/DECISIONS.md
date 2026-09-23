<!-- Instantiated by /cairn-init as cairn/DECISIONS.md (file header; entries
     are appended from templates/decision.md). A migration replaces the body
     note with its pointer-only or re-recorded disposition (migration
     protocol step 5). -->
# Decisions

Append-only. Never renumber; supersede with a new entry. D-entries record
choices with rationale — never deferrals ("not now" is a ROADMAP fact).

### D-001 (2026-09-17): Pre-1.0 waiver of the deprecation cycle

**Context:** The package is on CRAN at 0.2.2 with an experimental lifecycle badge. The tracking rules require a deprecation cycle for breaking changes unless the project is pre-1.0 and the user waives it.
**Decision:** Until 1.0, any exported name or return shape can change with a NEWS entry and no deprecation cycle.
**Consequences:** Milestones before 1.0 do not plan deprecation shims. The waiver ends at the 1.0 release, which takes a superseding entry.

### D-002 (2026-09-17): macOS, Linux, and Windows are all release commitments

**Context:** CI runs R CMD check on Ubuntu only. Many target users run Windows with NVIDIA GPUs, and the maintainer has machines for each platform.
**Decision:** A reproducible bug on any of the three platforms blocks a release.
**Consequences:** CI needs macOS and Windows check jobs (a ROADMAP candidate). Platform-specific code in `R/path.R` and `R/setup.R` needs tests on each platform.

### D-003 (2026-09-17): The server validates API fields, not the package

**Context:** Every REST wrapper forwards `...` into the request body (GP4). A misspelled field passes silently, which collides with fail-fast (GP3).
**Decision:** The package keeps no list of valid API fields. It forwards unknown fields and surfaces whatever error the server returns. Considered warning or erroring on unknown fields, rejected because the list goes stale each time LM Studio ships a field.
**Consequences:** A typo in a dot argument can be ignored without a message. The documentation for `...` states this limit.

### D-004 (2026-09-18): Failure-branch HTTP tests mock the transport, and recorded fixtures stay the default

**Context:** DESIGN names recorded `httptest2` fixtures as the everyday HTTP contract. A healthy LM Studio server returns no failure status. No recording can produce the non-200 bodies the failure branches read. A committed fixture also owes a generator script, which cannot reach those bodies either.
**Decision:** Response-branch and error-branch tests mock `httr2::req_perform` through the shared recorder in `tests/testthat/helper-mock-http.R`. Recorded fixtures remain the default for every path a live server can produce. Considered hand-writing fixture files under the cassette directories, rejected because a hand-written cassette claims a provenance it does not have.
**Consequences:** The suite carries two sanctioned HTTP-testing styles, chosen by whether a live server can produce the response. The recorder applies the request's own error policy, so a caller that drops its `req_error()` line still turns tests red. The inline `req_perform` closures in `test-load.R` and `test-chat.R` are a third, unsanctioned style, and folding them into the recorder is a candidate row.

### D-005 (2026-09-18): httpuv joins Suggests so tests can assert the HTTP verb

**Context:** httr2 infers the HTTP verb from the body rather than storing it on the request. So `httr2::req_dry_run()` is the only supported way to read the method. That call needs `httpuv`, which httr2 only suggests. The maintainer's machine had it and CI did not. The local suite passed at 100 while CI failed two tests.
**Decision:** `httpuv` joins Suggests as a test-only dependency. When the package is absent, `request_target()` skips its caller. Considered reading the path off `req$url` and inferring the verb from the body. That drops the direct verb assertion the implement gate chose, so it was rejected.
**Consequences:** Nothing a user installs at runtime changes. A contributor without `httpuv` sees skips rather than failures. A local green run is no longer evidence that CI is green. The CI wait at the merge gate is what settles that.

### D-006 (2026-09-20): A missing httpuv under CI fails the test instead of skipping it (narrows D-005)

**Context:** D-005 put the `httpuv` package in Suggests. It had `request_target()` skip its caller on a machine without that package. Every request assertion in this package reads through that helper. On CI a skip lets each of those assertions pass by not running, and nothing reports it. The two `R CMD check` workflows get `httpuv` through Suggests. The headless workflow gets it through devtools instead. A change to either one can therefore take it away with no signal.
**Decision:** `request_target()` raises on a machine that lacks `httpuv` and has the `CI` environment variable set. Off CI it still skips. The decision sits in `httpuv_absence_action()`. That function takes both inputs as arguments. A test can therefore drive either branch without mocking. Considered keeping the unconditional skip, rejected because the milestone that adds the `Authorization` header assertions then ships them unrun on CI.
**Consequences:** D-005's stated consequence, that a contributor without `httpuv` sees skips rather than failures, now holds off CI only. A CI image that drops `httpuv` turns the suite red instead of green with skips.

### D-007 (2026-09-20): A malformed response body gets its own condition class

**Context:** M012 adds `lms_embed()`, the first wrapper that validates a successful response body before returning it. The other wrappers index straight into the body and return whatever they find. A misordered or ragged embeddings block would otherwise build a silently misaligned matrix, and GP2 says the scripted batch wins. `rlm_abort_api()` cannot carry that abort: on an HTTP 200 it falls back to the raw body text (LESSONS, M006), which here is every float of every embedding, and it has no way to add the `simplify = FALSE` guidance.
**Decision:** A body that a wrapper cannot interpret aborts with the new condition class `rlmstudio_bad_response`, carrying the response status as an integer `status` field. `rlm_abort_api()` and `rlmstudio_api_error` keep their meaning, which is a response the wrapper treats as a failure. Considered reusing `rlmstudio_api_error` with `status` fixed at 200, rejected because that field then tells a catching user nothing and the documented example on the `rlmstudio-conditions` page renders "status 200". Considered a bespoke unclassed abort, rejected because DESIGN Conventions says a caller catches by class and not by message text.
**Consequences:** The package documents a third condition class. `lms_embed()` is its only raiser for now, so a second wrapper that validates its body inherits the class rather than inventing one. The validator is an asymmetry with the sibling wrappers, which validate nothing. D-003 is untouched, because it governs request fields and not response bodies.

### D-008 (2026-09-20): An argument fault is unclassed and beats the server probe (narrows D-007 and the M001 ordering)

**Context:** M013 puts an input check on `model`, `job_id`, `input`, and `inputs` across ten exported functions. Two choices were open and both collide with something already on record. D-007 rejected a bespoke unclassed abort, because DESIGN Conventions says a caller catches by class. M001 placed `stop_if_no_server()` first in each wrapper, so that a stopped server fails fast.
**Decision:** An argument fault aborts without a condition class, and it aborts above `stop_if_no_server()`. Considered a new `rlmstudio_bad_argument` class, rejected because a bad argument is a programming error. A running script cannot recover from one, so a caller has nothing to catch it for. Considered leaving the server probe first, rejected because an argument fault is knowable without a server. A user with both problems is better served by the one they can fix offline.
**Consequences:** D-007's stated reason for rejecting an unclassed abort holds for response bodies and not for argument faults. The two cases are now split on whether a caller can act on the condition at runtime. GP3 is traded here: a call with a bad argument and a stopped server no longer raises `rlmstudio_no_server`. The `rlmstudio-conditions` help page states that, and a test in `tests/testthat/test-arg-guards.R` pins it. A user who needs to catch an argument fault by class falsifies the first half. A caller who relies on the server abort firing first falsifies the second.

### D-009 (2026-09-21): The contract boundary excludes prose parsers, not the JSON an API call returns (narrows the DESIGN contract boundary)

**Context:** M017 adds a `schema` argument to `lms_chat_openai()`. LM Studio then returns the reply as a JSON string in `choices[[1]]$message$content`. DESIGN's contract boundary lists "structured-output parsers" among the general LLM helpers that are out of scope. A parse of that string falls under the literal wording.
**Decision:** The boundary excludes helpers that pull structure out of free prose. It does not exclude a parse of JSON that an LM Studio endpoint returns because the request asked for it. That parse is part of wrapping the feature (GP1). Considered returning the string and leaving the parse to the user. Rejected, because every scoring script then repeats the same parse call (GP2).
**Consequences:** `lms_chat_openai()` with `schema` and `simplify = TRUE` returns a parsed R value. The DESIGN contract-boundary line is reworded in M017 to cite this entry. A helper that parses a model's prose answer into a score is still out. A request for such a prose parser from the target users falsifies the line this entry draws.

### D-010 (2026-09-21): The batch warning about failed structured replies ignores quiet (trades GP6)

**Context:** M018 makes `lms_chat_batch()` keep going past a structured reply that it cannot parse. The failed input's slot holds the `rlmstudio_bad_response` condition, and the call warns once. GP6 says every user-facing message honors `quiet` and `rlmstudio.quiet`, and only errors are exempt.
**Decision:** That warning shows with `quiet` on as well as off. It replaces an abort, and it is the only signal that some answers are missing. A quiet run that silenced it returns failed slots with nothing to point at them, which works against GP2. Considered honoring `quiet` as GP6 says, rejected for that reason. The batch's existing format warnings already ignore `quiet`, so this entry records a practice and does not start one.
**Consequences:** GP6 has one recorded exception for warnings that report lost results. A user who runs quiet batches and treats this warning as noise falsifies the choice.

### D-011 (2026-09-22): A chat batch stores failed inputs and keeps a lost server an error (extends D-010)

**Context:** M019 extends M018 to every setting of `lms_chat_batch()` and to `rlmstudio_api_error`. Before M019, an API failure or a lost server for one input aborted the batch and lost every reply so far. GP2 says the scripted batch wins. GP3 says a missing server is an error. D-010 lets only the warning about failed structured replies ignore `quiet`.
**Decision:** An `rlmstudio_api_error` or `rlmstudio_bad_response` for one input is stored in that input's slot, and the batch goes on. A list slot holds the condition. A vector or data-frame slot without a `schema` holds `NA_character_`. The one warning about failed inputs covers both classes and ignores `quiet`, so D-010 now covers API failures as well. An `rlmstudio_no_server` still aborts the batch, and the condition carries the replies so far in a `results` field. Considered storing a lost server and going on, rejected because every later input then fails and GP3 asks for an error. Considered an `on_error` argument, rejected because the warning already marks the failures and an argument is hard to remove. Considered a data-frame `error` column, rejected because it changes the data-frame shape of every batch.
**Consequences:** The type of a batch result no longer depends on whether an input failed. A user who needs the condition from a vector or data-frame batch reruns with `format = "list"`. A user who needs a batch to stop at the first failure falsifies the no-argument choice.

### D-012 (2026-09-22): A chat reply with no answer text aborts on every route (extends D-007 and D-011)

**Context:** M020 makes `lms_chat_native()` and `lms_chat_openresponses()` read the reply by item type. A reply can then hold no answer text, for example only reasoning, only a tool call, or `null` content. Before M020, `lms_chat_openai()` returned `NULL` for `null` content, and `lms_chat_batch()` stored `NA` for it with no warning. The other two routes returned the text of the first item or failed with a base R error.
**Decision:** With `simplify = TRUE`, all three routes abort with `rlmstudio_bad_response` when the reply holds no answer text. A batch then stores the condition and warns, as D-011 says. Considered `NULL` on every route, rejected because a batch then gives no sign that an answer is missing (GP2). Considered keeping `NULL` on the OpenAI route alone, rejected because the routes then disagree about the same kind of reply. The pre-1.0 waiver (D-001) covers the change to a single OpenAI call.
**Consequences:** A call that passes tools through `...` and gets only a tool call back aborts with `simplify = TRUE`. With `simplify = FALSE`, the call still returns the body. A user who relies on a `NULL` return for a tool-call reply falsifies the choice.

### D-013 (2026-09-22): A native data-frame batch adds reply columns, and a bad reply field is a silent NA (annotates D-011)

**Context:** M022 returns the `response_id` and six `stats` fields of each native reply in a data-frame batch. D-011 rejected a data-frame `error` column because it changes the data-frame shape of every batch. D-007 and D-012 make a malformed answer abort with `rlmstudio_bad_response`.
**Decision:** With `api_type = "native"` and `format = "data.frame"`, the batch adds seven fixed columns after its existing ones. The shape changes on this one route and format only. It does not depend on the replies, so D-011's concern does not apply to it. A reply field of the wrong type gives an `NA` cell with no warning, and the answer is kept. These fields are extra to the answer, so a change to the server's stats block does not fail every input. Considered a `stats` list-column, rejected because flat columns compute directly. Considered failing the input on a bad field, rejected for the reason above. Considered attributes on a single simplified reply, rejected because `simplify = FALSE` already returns the body and attributes print under every answer. The pre-1.0 waiver (D-001) covers the new columns.
**Consequences:** Code that indexes a native data-frame batch by column position still works, because the new columns come last. A user who needs to know that a stats field went missing, or who needs one column set across routes, falsifies the choice.

### D-014 (2026-09-22): The OpenResponses and OpenAI data-frame batches add four of the native reply columns (annotates D-013)

**Context:** D-013 added seven columns to the native data-frame batch and changed the shape on that route and format only. M023 gives the other two routes the id and token counts of each reply. The servers name the counts differently. `/v1/responses` sends `usage.input_tokens` and `usage.output_tokens`. `/v1/chat/completions` sends `usage.prompt_tokens` and `usage.completion_tokens`.
**Decision:** With `format = "data.frame"`, the OpenResponses and OpenAI routes add four columns after their existing ones. They take the names of the first four native columns: `response_id`, `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens`. The help page maps each server field to its column. The columns depend on the route and format alone, for every setting of `logprobs` and `schema`. D-013's silent `NA` rule applies to them. Considered each server's own field names, rejected because a script then handles three column sets and cannot stack batches from different routes. Considered the columns only for batches without `logprobs` or `schema`, rejected because the shape then depends on arguments other than route and format. The pre-1.0 waiver (D-001) covers the new columns.
**Consequences:** Batches from the three routes share four column names. A column name can differ from the server field it holds, such as `total_output_tokens` from `completion_tokens`. A user who needs the server's own names, or who finds that the counts differ in meaning across routes, falsifies the choice.

### D-015 (2026-09-23): A status-200 body that does not parse as JSON aborts on every chat route, even with simplify = FALSE (annotates D-007 and D-012)

**Context:** M024 extends the `lms_embed()` parse guard to the three chat functions. Before M024, such a body raised an unclassed httr2 or jsonlite error, and `lms_chat_batch()` lost every reply so far. D-012 says that with `simplify = FALSE` the call still returns the body. D-007 says that `lms_embed()` is the only raiser of `rlmstudio_bad_response`, which was already out of date.
**Decision:** The three chat functions and `lms_embed()` parse a status-200 body through one helper. It reads the body by content and not by its `Content-Type` header. It aborts with `rlmstudio_bad_response` when the parse fails, whatever `simplify` is. The condition keeps no copy of the body, and the message leaves out the parser text because that text quotes the body. Considered returning the raw text with `simplify = FALSE`, rejected because the return type then depends on the server. Considered an abort on a `text/plain` header, rejected because it reports two causes as one. It also leaves no way through a proxy that rewrites the header. Considered a `body` field, rejected because a batch then holds a large page for each failed input.
**Consequences:** D-012's `simplify = FALSE` line holds only for a body that parses. A batch keeps its other replies past such a body. A fault that hits every input, such as `stream = TRUE`, now fails every input alone and does not stop the batch. A server that sends non-JSON under `text/plain` on purpose falsifies the choice. So does a user who needs the page to find a proxy fault.

### D-016 (2026-09-22): Every reply parse reads JSON text only and ignores the Content-Type header (extends D-015)

**Context:** M025 routes `list_models()`, `lms_load()`, `lms_download()`, and `lms_download_status()` through the parse helper from D-015. That helper called `jsonlite::fromJSON()` through httr2. When the body text is not valid JSON, `fromJSON()` fetches a text that looks like a URL and reads a text that names a file. Such a reply body made the package read a local file or call a host the user did not name, against IP1. `api_error_message()` and `lms_server_ready()` parsed the same way, and both checked the `Content-Type` header.
**Decision:** Every parse of an HTTP reply body reads the body text as UTF-8 and parses it with `jsonlite::parse_json()`, which reads JSON text only. No reply parse checks the header. `lms_server_ready()` then accepts a model list sent as `text/plain`. An error body sent as `text/plain` gives its `error.message` text. Considered a header check in those two functions, rejected because the package then has two parse rules for one body. Considered `jsonlite::validate()` before `fromJSON()`, rejected because a parser that can read files then sits behind a second check.
**Consequences:** D-015's parse by content now covers every reply parse. A server or proxy that sends JSON as `text/plain` for a reason the package must honor falsifies the header choice.
