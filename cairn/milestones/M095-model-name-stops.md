<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M095: Model-name stops for embeddings and batches

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** GP2, GP3   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes when two exported functions abort   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m095-model-name-stops   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A model name that the server answers with another model or with "No models
loaded" ends `lms_embed()` and `lms_chat_batch()` at the first request that
shows it.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** three cases of the candidate row "model-name cases". First, the
reply-model check of D-025 for `lms_embed()`. On 2026-10-19, with one
embedding model loaded, `/v1/embeddings` answered an unknown name, and a chat
model's name, with status 200 and vectors from the loaded embedding model.
Second, a batch stop at status 400 "No models loaded", which all three
OpenAI-style routes sent for an unknown name with nothing loaded
(2026-10-19, LM Studio 0.4.26+4, just-in-time loading on). Third, one
model-list lookup per kept reply id in a call. A D-entry that narrows D-019
and annotates D-024, D-025, and D-026. Help and NEWS.

**Out:** the variant-name case of the row (a variant name, a file-name id, a
name without its publisher, a padded name, with just-in-time loading off). It
stays in the candidate row "model-name cases" with its trigger. A
`model_not_found` stop in `lms_embed()` stays out by D-026: no probe has
shown that code on `/v1/embeddings`, because one embedding model is on disk.
`lms_chat_native()`, whose route answers an unknown name with 404
`model_not_found`, already stopped on 2026-10-19.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets.
     Every item opens with its positional label — `ACn:` — the item's
     position counted top-to-bottom, the number Coverage cites; an
     insertion, removal, or reorder renumbers the labels and the Coverage
     lines together. -->

- [ ] AC1: `lms_embed()` checks the `model` field of each status-200 reply,
      with either setting of `simplify`, by the rule of `lms_chat_openai()`.
      When the field is a string with a non-space character that differs
      from the asked name, one model-list lookup decides. The reply is kept
      when a model whose key equals the asked name in any letter case has a
      loaded instance with that id. Otherwise the call aborts with
      `rlmstudio_model_mismatch`, and no embeddings request goes out after
      that one. The condition carries `results` when an earlier request
      succeeded. Any other `model` value is not checked. A failed lookup
      fails that request alone, unless its condition is an
      `rlmstudio_no_server` or an `rlmstudio_api_error` with status 401,
      403, or 404, which end the call with `results` when an earlier request
      succeeded. Tests with `batch_size = 1` fire, with `simplify = TRUE` and
      `FALSE`: a kept reply, a mismatch at request 2 of 3 from the reply
      recorded on 2026-10-19, a mismatch at request 1, a reply with no
      `model` field, a lookup that fails alone, and a lookup with no server.
      Each asserts which condition is raised, or none, the number of
      embeddings requests sent, and whether `results` is present.
- [ ] AC2: `lms_chat_batch()` and `lms_embed()` abort at the first
      `rlmstudio_api_error` with status 400 whose response body has an
      `error` string, or an `error.message` string, that starts with
      "No models loaded" in this letter case. No chat or embeddings request
      goes out after it. The `lms_chat_batch()` condition carries `results`
      as at its other stops, and the `lms_embed()` condition carries
      `results` when an earlier request succeeded. A 400 with another message
      and no `code` still fails its own input alone in both functions. Tests
      stop at input 2 of 3 on the `"openai"` and `"openresponses"` routes and
      at request 2 of 3 in `lms_embed()`, with the bodies recorded on
      2026-10-19. They assert the class, the status, the number of chat or
      embeddings requests sent, and `results`. Tests in both functions send
      a 400 with another message beside a successful request and assert that
      the call goes on.
- [ ] AC3: In one call of `lms_chat_batch()` on the `"openai"` or
      `"openresponses"` route, or of `lms_embed()`, a reply whose `model` id
      a lookup in that call already kept for the asked name sends no lookup.
      Tests with three replies that name the same id, which differs from the
      asked name and belongs to a loaded instance of the asked model, assert
      one model-list request per call. They run on both routes in the list
      and data-frame formats, and in `lms_embed()`. A test whose third reply
      names a second such id asserts two lookups. A test of two calls asserts
      two lookups.
- [ ] AC4: The `lms_embed()` help states the reply-model check, the
      "No models loaded" stop, and the one lookup per kept id, and its
      paragraph on failed requests names these exceptions. The
      `lms_chat_batch()` help states the "No models loaded" stop and the one
      lookup per kept id. The `rlmstudio-conditions` topic, its "Reply from
      another model" section included, states that `lms_embed()` raises
      `rlmstudio_model_mismatch` and that both functions stop at
      "No models loaded". `NEWS.md` has one entry that names the embedding
      check, the stop, and the one lookup per kept id.
- [ ] AC5: On the dev machine, `devtools::test()` with the live tests
      skipped and `devtools::check()` both give 0 errors and 0 warnings.

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T1, T4
- AC4 → T5
- AC5 → T6

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: Record the live replies. Start the server with `port = 1234`.
      Record the "No models loaded" 400 of `/v1/chat/completions`,
      `/v1/responses`, and `/v1/embeddings` with nothing loaded. Record the
      200 of `/v1/embeddings` for an unknown name with
      `text-embedding-nomic-embed-text-v1.5` loaded, and the model list with
      a model loaded under another id (`lms load --identifier`). Unload all
      and stop the server in a `finally` clause (LESSONS M083, M017).
- [x] T2: AC1, tests first. Reuse `check_reply_model()` and
      `reply_model_serves()` (`R/chat.R:969`) in `embed_request()`
      (`R/embed.R`). Abort at a mismatch in the batch loop
      (`R/embed.R:185`), with the subclass test inside the parent handler
      (LESSONS M049). Count requests with the shared recorder (LESSONS M008).
- [x] T3: AC2, tests first. Carry the server message to the two batch
      handlers (`R/chat.R:2206`, `R/embed.R:185`), for example as a
      condition field set in `rlm_abort_api()` (`R/utils-api-error.R:107`).
- [ ] T4: AC3, tests first. Keep the kept ids of one call and pass them to
      `reply_model_serves()`. `lms_chat_batch()` reaches it through
      `lms_chat()`, so mock the lookup at the delegate (LESSONS M003).
- [ ] T5: Append the D-entry (narrows D-019, annotates D-024, D-025,
      D-026). Write the help of AC4 against observed output, and the NEWS
      entry. Pin `rlmstudio.quiet = FALSE` in message tests (LESSONS M086).
      Run `devtools::document()`.
- [ ] T6: Run `devtools::test()` and `devtools::check()`.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-19: created by /milestone-plan.
- 2026-10-19: tier check: milestone — it changes when two exported functions abort and needs a design decision.
- 2026-10-19: collision sweep: absorbs in part the candidate row "model-name cases" (cases 1 to 3); the variant-name case stays in that row. D-019, D-024, D-025, and D-026 surfaced and are narrowed or annotated by T5. M049 and M047 archives read. No overlap with other rows; "max_context_length limits" names the same key match for `lms_load()` and stays as it is.
- 2026-10-19: inbox sweep: 0 open issues, 0 open PRs.
- 2026-10-19: live probe (LM Studio 0.4.26+4, JIT on): with nothing loaded, an unknown name gave 400 "No models loaded" on `/v1/chat/completions` and `/v1/responses` (`param` "model", `code` null) and on `/v1/embeddings` (`error` a string); `/api/v1/chat` gave 404 `model_not_found`; with one embedding model loaded, `/v1/embeddings` answered an unknown name and a chat model's name with 200 from that model. Server stopped, models unloaded.
- 2026-10-19: question set: stop the batch at "No models loaded" — stop (user chose the recommended option).
- 2026-10-19: question set: the variant-name case — keep it for later in the candidate row (user chose the recommended option).
- 2026-10-19: plan gate chose a stop on the server message "No models loaded" over running the batch to the end with a help note, because every input fails the same way (GP2); falsified by a LM Studio release that changes the wording, or a "No models loaded" 400 that depends on the input.
- 2026-10-19: plan chose a per-call cache of kept ids over a help note on the lookup cost, because a batch against a model loaded under another id doubled its requests; falsified by a model unloaded and reloaded under the same id mid-call to another model.
- 2026-10-19: criteria audit (full mode, fresh Opus reader): 20 findings. Fixed: goal narrowed to the two faults shown (G1); AC1 counts embeddings requests only, states lookup failure, the non-space rule, and probes both `simplify` settings and stops at request 1 and 2; AC2 reads the body's `error` or `error.message` string, adds a non-stop 400 beside a success in both functions, and stops at input 2 of 3; AC3 names one id, a second id, both routes, both formats, and two calls; old AC4 (variant names) left the milestone by the user's answer, which settles AC1-c and AC4-a to e; docs AC narrowed per topic and adds the "Reply from another model" section; check AC names the environment; D-entry list taken into T5.
- 2026-10-19: no partial issue, no release, no dependency change; changelog: one NEWS entry (T5).
- 2026-10-19: status in-progress, branch m095-model-name-stops cut from main at 35f9949.
- 2026-10-19: T1 done: `data-raw/record-model-stop-cassette.R` recorded `tests/testthat/stop_live/` (none, embed_unknown, embed_alias) on LM Studio 0.4.26+4; all three routes gave 400 "No models loaded" with nothing loaded; embeddings gave 200 from `text-embedding-nomic-embed-text-v1.5` for "not-a-model" and 200 naming "my-nomic" for the key. Directory named `stop_live`, because `model_stop_live` put one tarball path at 100 bytes. Server stopped, no model loaded. data-raw/README.md lists the script.
- 2026-10-19: T2 done: `embed_request()` calls `check_reply_model()`; the `lms_embed()` loop aborts with results at `rlmstudio_model_mismatch` and at an `rlmstudio_no_server` from the lookup. New `tests/testthat/test-model-stops.R` (9 blocks) and `helper-model-check.R` (helpers moved from test-model-check.R). Red before the change; a plant that drops the two new handlers turned 3 blocks red. Full `devtools::test()`: 0 failed, 3 live skips. Chose a package-level cache env set by each batch call over a hidden argument, because `lms_chat_batch()` reaches the check through `lms_chat()`, whose dots go to the request body; its code landed with T2 and its tests come in T4.
- 2026-10-19: T3 done: `rlm_abort_api()` adds a `server_message` field (the body's `error` string, else its `error.message` string, else NULL) through `api_error_text()`; `is_no_models_loaded()` drives the stop in both batch handlers. Chose a new condition field over a match on the condition message, because that message opens with the wrapper label; falsified by a user who reads `server_message` as more than the server's text. 6 new blocks: red on the old code; a plant that drops the chat stop turned 2 red; the 5 near-miss controls stayed green. Full `devtools::test()`: 0 failed, 3 live skips.

## Decisions
<!-- owner: implement / review · append-only; milestone-local. -->

## Review
<!-- owner: review · exclusive. -->
