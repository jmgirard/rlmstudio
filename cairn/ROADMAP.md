# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-22 (M020 done and archived, M017 row pruned, three review candidates added)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- Rows are grouped by status, not sorted by ID. Keep only the 3 most recent
     terminal (done or dropped) rows. Older ones live in milestones/archive/ and git. -->
| M021 | An unreadable OpenResponses reply names its fault | review | none | normal | milestones/M021-openresponses-reply-faults.md |
| M020 | A chat reply without readable answer text fails that input, not the batch | done | none | normal | milestones/archive/M020-chat-reply-shape.md |
| M019 | A failed input no longer ends a chat batch | done | none | normal | milestones/archive/M019-batch-survives-errors.md |
| M018 | A failed structured reply keeps its text and no longer ends a batch | done | none | normal | milestones/archive/M018-failed-structured-reply.md |

## Candidates
<!-- Unnumbered ideas, one line each, ordered high, then normal, then low:
     - [high] idea, added YYYY-MM-DD, links
     - idea, added YYYY-MM-DD, links
     The opening token is [high] or [low] or absent (normal).
     See tracking-rules "Candidate priority token". -->
- `lms_server_start()` with `host = NULL` does not check the host it builds from `port` before the CLI runs. A `port` of `"abc"` or `99999` makes the probe abort. If the CLI accepts such a port, the call warns after the start rather than aborting before it, added 2026-09-20, M015 review finding 4
- The argument-guard loops in `tests/testthat/test-arg-guards.R` report one failure for ten functions. A non-matching error aborts the whole `test_that()` block. The first broken function then hides the other nine. The file still turns red. The diagnostics alone are coarse, added 2026-09-20, M013 review finding 7
- Run `lms daemon up` then `lms daemon status --json` on a headless llmster install, as on Linux. On macOS with the desktop app installed, `up` returned only once the daemon ran, so M016 dropped its wait. If `up` returns early there, a wait on `lms_daemon_start()` has a reason, added 2026-09-20, milestones/archive/M016-daemon-start-wait.md
- A `chunk_size` argument on `lms_embed()` with a progress bar, so a long input vector goes out as several requests. M012 sends the whole vector in one POST, added 2026-09-20, M012 plan gate
- `lms_chat_openai()` takes its prompt as `messages`, a list, so M013's text guard does not reach it. A malformed messages list still goes to the server unchecked, added 2026-09-20, M013 scope
- The chat wrappers send an `input` of length two as a JSON array rather than one prompt. M013 leaves the length alone, because narrowing a named formal is a permanent API restriction. Decide whether a length rule belongs there, added 2026-09-20, M013 plan gate
- A `ttl` argument on `lms_load()` and the chat wrappers. It sets how long an idle model stays in memory and is the one documented load field the package does not name, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- A `/api/v1/chat` response carries a `stats` block with `input_tokens`, `total_output_tokens`, `tokens_per_second`, and `time_to_first_token_seconds`. `lms_chat_native()` drops it. Surfacing it lets a batch run report throughput, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- Structured output on `/v1/responses` and `/api/v1/chat`. M017 covers `/v1/chat/completions` only, the one endpoint the LM Studio docs describe for it. Promote once the docs or a live request show that another endpoint honors a schema, added 2026-09-21, M017 scope
- Bind parsed batch replies into data-frame columns. With `schema`, `lms_chat_batch(format = "data.frame")` returns an `output` list-column after M017, added 2026-09-21, M017 scope
- A loaded-instance table, the view `lms ps` prints, flattened from the `loaded_instances` field that `list_models(detailed = TRUE)` already returns, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- Stateful chat on `/api/v1/chat`. The endpoint returns a `response_id` and continues a thread from `previous_response_id`. The package drops the id, so the thread is unreachable, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- A shipped guard that keeps every raiser of `rlmstudio_no_server` and `rlmstudio_api_error` documented at the exported function that raises it. M007 bounds its promise to the call sites two named greps sweep, so a fresh `cli_abort(class = ...)` elsewhere escapes. A test that greps `R/` gates `devtools::test()` only, added 2026-09-18, M007 scope
- Building either vignette stops an LM Studio server the vignette did not start. The teardown chunks run whenever the CLI is present, added 2026-09-20, M010 review finding 5
- The port helpers in `tests/testthat/test-server-ready.R` and `tests/testthat/test-serve.R` are near-duplicates that belong in a `helper-` file. Both pick a port through `sample()`. That moves the session RNG and collides reproducibly under a seed, added 2026-09-20, M010 review findings 8 and 9
- A guard that keeps the pre-call probe in the REST wrappers in step with the condition help page. M010 narrows that page and adds a stronger probe. The wrappers keep the TCP probe, so the two can drift, added 2026-09-20, M010 scope
- The release walk needs a live-run step: full suite against a running LM Studio, then a re-record of stale fixtures, added 2026-09-17, DESIGN Conventions
- A guard that keeps every new `stop_if_no_server()` call site covered by a class test, added 2026-09-18, M003 scope
- A guard that keeps every REST wrapper handling a failed response listed in the failure table. The deleted guard read package sources that R CMD check does not ship, so it skipped there. It did run under `devtools::test()`, so it gated local runs (corrected M006 review), added 2026-09-18, M006 scope, see also the `stop_if_no_server()` guard row
- A non-JSON failure body becomes the abort message in full, with no length bound. A proxy's HTML page reaches the user whole. A scalar JSON body reaches the user as the bare token, added 2026-09-18, M005 implement audit and M005 review finding 12
- When only R-devel breaks, a red `ubuntu-latest (devel)` job still blocks the merge. Decide its disposition, added 2026-09-17, M002 review finding 6
- `request_target()` parses the request body as JSON with no guard, so a wrapper that ever sends a non-JSON body surfaces a raw `jsonlite` error from the helper rather than a named test failure. Catch the parse and return the raw string, added 2026-09-19, M008 review finding 6
- The eight abort sites call `rlm_token(token)` again to decide the hint. `lms_client()` already resolved it. Ambient state that changes between the two reads gives the wrong hint, added 2026-09-20, M009 review finding 5
- `request_target()` now returns headers with redaction off for every caller. The older callers do not pin `RLMSTUDIO_API_TOKEN`. Nothing prints those headers today. Give them an opt-in accessor, added 2026-09-20, M009 review finding 6
- A guard that keeps the token wrapper table covering every exported function that reaches the REST API. The table is a fixed list of twelve names. A thirteenth wrapper added later escapes it, added 2026-09-20, M009 review finding 8, count corrected M010, see the two sibling guard rows above
- A structured reply that the token limit cut off but that is still valid JSON, such as `"12"`, parses with no sign of the cut-off. Decide whether a `finish_reason` of `"length"` warns or aborts even when the parse succeeds, added 2026-09-22, M018 review pass 2 finding 3
- A bad token (401) or a model that is not loaded (404) fails every input of `lms_chat_batch()` in the same way. The batch then sends every request and warns at the end. Decide whether a failure that holds for every input stops the batch early, added 2026-09-22, M019 review finding O3
- An unreadable native or OpenResponses reply that the token limit cut off aborts with the shape detail and no hint about the limit. On 2026-09-22, cut-off replies at `max_output_tokens` 5 from gemma-3-1b and qwen3-4b-2507 carried no marker. `/v1/responses` said `status` `"completed"` and `incomplete_details` `null`. `/api/v1/chat` carried only `model_instance_id`, `output`, `stats`, and `response_id`. No reasoning model was on hand to test a reply that ends before any message item. Promote once a live reply marks the cut-off, such as `status` `"incomplete"` with reason `"max_output_tokens"`, added 2026-09-22, M021 plan gate and T1
- A cut-off OpenResponses or native reply whose text is readable returns the partial text with no sign of the cut-off. Decide whether it warns. See the sibling row on a cut-off structured reply that still parses, added 2026-09-22, M021 scope
- The tests of the unreadable native and OpenResponses replies do not pin the order of the checks. Each shape breaks exactly one check, so the tests still pass after a swap of two adjacent checks. Add shapes that break two checks, added 2026-09-22, M021 review finding O6
- The shared "Malformed response" help section now lists the six OpenResponses `logprobs` rules. It reaches the help pages of `lms_embed()`, `lms_chat_native()`, `lms_chat_openai()`, and `lms_chat()`, which never check them. M007 chose one shared section over one copy per function. Decide whether the rules move to the `lms_chat_openresponses()` page alone, added 2026-09-22, M021 review finding O9
- The `Full Integration` test in `tests/testthat/test-chat.R` calls `lms_unload()` in its `on.exit()`, outside the recorded replies. On a machine with a live server, `devtools::test()` then unloads `google/gemma-3-1b`. It does this also for a model that was loaded before the run, observed 2026-09-22, M021 T2
- [low] Remove the macOS Package Manager workaround from `R-CMD-check.yaml` and set `use-public-rspm` back to `true`. Promote once a released pak extracts zstd archives, added 2026-09-20, M011 scope, r-lib/pkgdepends#485
- [low] Pin the macOS check job to R 4.5, whose CRAN binaries are still gzip. This is the alternative M011 rejected. If Posit Package Manager stops serving gzip macOS binaries, or drops its R 4.6 path, promote this row, added 2026-09-20, M011 plan gate
- [low] Streaming chat over Server Sent Events (`stream: true`, nineteen named event types). It changes the return shape, so it needs its own design work, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- [low] Make the headless CI job install LM Studio or rename it to say what it runs, added 2026-09-17, DESIGN Known issues
- [low] Unify the four workflow files on one `actions/checkout` version, a `concurrency` group, and a `workflow_dispatch` trigger, added 2026-09-17, M002 findings 7 and 8
