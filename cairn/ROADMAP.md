# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene pass: 2026-09-19 (triage of 14 items. The API-error docs row dropped as already shipped by M007. The condition-docs guard row compressed. 12 items unchanged, no decision entry, validate green)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- Rows are grouped by status, not sorted by ID. Keep only the 3 most recent
     terminal (done or dropped) rows. Older ones live in milestones/archive/ and git. -->
| M009 | The package can authenticate to LM Studio | review | none | high | milestones/M009-api-token-auth.md |
| M008 | Tests that fail on the branch they name | done | none | normal | milestones/archive/M008-test-discrimination.md |
| M007 | The abort contract reaches the help pages | done | none | normal | milestones/archive/M007-abort-contract-docs.md |
| M006 | list_models() joins the shared REST abort path | done | none | normal | milestones/archive/M006-list-models-abort-path.md |

## Candidates
<!-- Unnumbered ideas, one line each, ordered high, then normal, then low:
     - [high] idea, added YYYY-MM-DD, links
     - idea, added YYYY-MM-DD, links
     The opening token is [high] or [low] or absent (normal).
     See tracking-rules "Candidate priority token". -->
- [high] `/v1/embeddings` has no wrapper. It is the one documented endpoint family with no coverage, and text embeddings serve the scoring-at-scale user directly, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- A `ttl` argument on `lms_load()` and the chat wrappers. It sets how long an idle model stays in memory and is the one documented load field the package does not name, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- A `/api/v1/chat` response carries a `stats` block with `input_tokens`, `total_output_tokens`, `tokens_per_second`, and `time_to_first_token_seconds`. `lms_chat_native()` drops it. Surfacing it lets a batch run report throughput, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- Structured output on `/v1/chat/completions` through `response_format` with a JSON schema. A scoring run gets one parsed value per item instead of prose to parse, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- A loaded-instance table, the view `lms ps` prints, flattened from the `loaded_instances` field that `list_models(detailed = TRUE)` already returns, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- Stateful chat on `/api/v1/chat`. The endpoint returns a `response_id` and continues a thread from `previous_response_id`. The package drops the id, so the thread is unreachable, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- A shipped guard that keeps every raiser of `rlmstudio_no_server` and `rlmstudio_api_error` documented at the exported function that raises it. M007 bounds its promise to the call sites two named greps sweep, so a fresh `cli_abort(class = ...)` elsewhere escapes. A test that greps `R/` gates `devtools::test()` only, added 2026-09-18, M007 scope
- The help text promises `rlmstudio_no_server` for a stopped LM Studio server. `is_server_running()` opens a TCP connection to the host and port. It does not make sure that the listener is LM Studio. A foreign process on the port suppresses the condition. Narrow the help text or tighten the probe, added 2026-09-18, M007 claim audit
- [high] Both vignettes start the local server and make live API calls while they build, gated only on `has_lms()`. `R CMD check` therefore depends on whatever state that server happens to be in. On a server that requires a token and a machine with no `RLMSTUDIO_API_TOKEN` set, the check fails. Gate the chunks on a reachable and usable server, not on the CLI alone, added 2026-09-20, M009 T8
- The release walk needs a live-run step: full suite against a running LM Studio, then a re-record of stale fixtures, added 2026-09-17, DESIGN Conventions
- A guard that keeps every new `stop_if_no_server()` call site covered by a class test, added 2026-09-18, M003 scope
- A guard that keeps every REST wrapper handling a failed response listed in the failure table. The deleted guard read package sources that R CMD check does not ship, so it skipped there. It did run under `devtools::test()`, so it gated local runs (corrected M006 review), added 2026-09-18, M006 scope, see also the `stop_if_no_server()` guard row
- A non-JSON failure body becomes the abort message in full, with no length bound. A proxy's HTML page reaches the user whole. A scalar JSON body reaches the user as the bare token, added 2026-09-18, M005 implement audit and M005 review finding 12
- When only R-devel breaks, a red `ubuntu-latest (devel)` job still blocks the merge. Decide its disposition, added 2026-09-17, M002 review finding 6
- `request_target()` parses the request body as JSON with no guard, so a wrapper that ever sends a non-JSON body surfaces a raw `jsonlite` error from the helper rather than a named test failure. Catch the parse and return the raw string, added 2026-09-19, M008 review finding 6
- [low] Streaming chat over Server Sent Events (`stream: true`, nineteen named event types). It changes the return shape, so it needs its own design work, added 2026-09-19, cairn/references/lmstudio-api-surface.md
- [low] Make the headless CI job install LM Studio or rename it to say what it runs, added 2026-09-17, DESIGN Known issues
- [low] Unify the four workflow files on one `actions/checkout` version, a `concurrency` group, and a `workflow_dispatch` trigger, added 2026-09-17, M002 findings 7 and 8
