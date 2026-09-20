# Design

_Architecture as it is. Future work lives in ROADMAP.md. Status lives nowhere here._

## Purpose & Scope

Elicited by `/design-interview` on 2026-09-17 (Phase 1). Seeded by cairn-init from DESCRIPTION, README, and a read of `R/`.

- rlmstudio is an unofficial R wrapper for the LM Studio command line interface (the `lms` executable) and its v1 REST API.
- The core user is a researcher who runs local models over many items and wants scores. When a console convenience and a scripted batch pull in different directions, the batch pipeline wins.
- It lets an R user download local models and start or stop the server and the headless daemon. It also loads and unloads models and generates text from R.
- It targets LM Studio 0.4.0 or higher and the v1 REST API.
- It is on CRAN (0.2.2) in the experimental lifecycle stage. The development version is 0.2.2.9000.

### Contract boundary

- The package exposes what `lms` and the REST API offer, one wrapper per feature, plus a small amount of R-native analysis of the results. `lms_score_expected` is the only member of the analysis family. It is an experimental helper for one use case, not a general contract.
- If a new function wraps an LM Studio feature or serves the scoring-at-scale workflow, it earns a place. General LLM helpers (prompt templates, structured-output parsers, evaluation loops) are out.
- Out of scope: a GUI, model training, and anything the LM Studio CLI or API does not expose.

### Platforms

- macOS, Linux, and Windows are all commitments. A reproducible bug on any of them blocks a release. CI runs R CMD check on all three (`.github/workflows/R-CMD-check.yaml`), with three R versions on Ubuntu. (corrected M002)

### Stability and release

- Until 1.0, any exported function can change. A rename or a changed return shape needs a NEWS entry, not a deprecation cycle. This is the explicit pre-1.0 waiver that the tracking rules allow.
- If a feature set is ready, CRAN receives a release. There is no fixed cadence. GitHub `main` is the development channel.

### Dependencies

- Imports are cli, httr2, jsonlite, processx, and utils. Adding one is a recorded decision with rationale, never a side effect of a feature.

## Function Families

Read from NAMESPACE and the pkgdown reference index on 2026-09-17.

- Setup: `install_lmstudio`, `has_lms`, `check_lms_version`, `lms_path`.
- Daemon and server: `lms_daemon_start`, `lms_daemon_stop`, `lms_daemon_status`, `with_lms_daemon`, `lms_server_start`, `lms_server_stop`, `lms_server_status`, `lms_server_ready` (corrected M010).
- Model management: `list_models`, `lms_download`, `lms_download_status`, `lms_load`, `lms_unload`, `lms_unload_all`.
- Chat and inference: `lms_chat`, `lms_chat_batch`, `lms_chat_native`, `lms_chat_openai`, `lms_chat_openresponses`.
- Analysis (experimental): `lms_score_expected`.
- S3 classes: `lms_chat_result` (text plus token logprobs) and `lms_download_status`, each with a print method.

## Conventions

Observed in the code and agreed at the interview on 2026-09-17.

- User-facing messages go through `cli`. The `rlmstudio.quiet` option and a local `quiet` argument silence them (`R/utils-msg.R`).
- HTTP calls use `httr2`. JSON uses `jsonlite`. External processes use `processx`.
- Every REST wrapper merges `...` into the request body. Dots are the intended escape hatch for API fields that the package does not name. If a field needs input checks or documentation, it becomes a named argument.
- If the server is not running, a function that needs the server aborts with a message that names `lms_server_start`. This is the intended posture. Every server-down abort carries the condition class `rlmstudio_no_server`. `lms_server_ready()` is the one exception. It reports on the server rather than using it, so it returns `FALSE` (corrected M010).
- Every REST wrapper that handles a failed response aborts through `rlm_abort_api()` in `R/utils-api-error.R`. That abort carries the condition class `rlmstudio_api_error` and a `status` field holding the HTTP status as an integer. The helper reads `error` and `error$message` out of the parsed body and falls back to `HTTP Status <n>`. A caller catches an API failure by class rather than by message text.
- Tests use testthat edition 3. Recorded HTTP fixtures (`httptest2`, under `tests/testthat/<name>/localhost-1234`) are the everyday contract. The helpers in `tests/testthat/helper-skips.R` skip the tests that need a live LM Studio. A CRAN release requires a full live run on a real machine and a new recording of stale fixtures.
- Code is formatted with Air (`air.toml`).
- The changelog is `NEWS.md`. The site is pkgdown in release mode.

## Design Principles

Settled by `/design-interview` on 2026-09-17. An IP (Inviolable Principle) changes only by an explicit user decision recorded in DECISIONS.md. A GP (Guiding Principle) is a default that a milestone can trade with a stated reason. Numbers are never reused or renumbered.

### Inviolable

- IP1: **Local only.** The package sends user text only to the LM Studio host that the user names in the `host` argument. Two other network calls are allowed: the installer download in `install_lmstudio()` and a model download that the user requests. A host on another machine counts as the user's choice. No telemetry, no remote-inference fallback, no third-party service.
- IP2: **Consent before installing.** No function downloads or runs an installer without consent. Consent is an interactive yes or the explicit `RLMSTUDIO_ALLOW_INSTALL` opt-in. The same rule covers any write outside LM Studio's own directories. A model download is the user's explicit request and needs no prompt.

### Guiding

- GP1: **One wrapper per LM Studio feature.** The package exposes what `lms` and the REST API offer, plus analysis that serves scoring at scale. A new export must wrap an LM Studio feature or serve that workflow. General LLM helpers are out.
- GP2: **Batch pipelines win ties.** A scripted run over many items and an interactive console use can conflict. The scripted run wins.
- GP3: **A missing server is an error.** A function that needs the server aborts with a message that names `lms_server_start()`. It never returns an empty result in place of an error.
- GP4: **Dots are the escape hatch.** Every REST wrapper forwards unnamed arguments to the request body. The server is the validator, and the package surfaces the error it returns. The package keeps no list of valid fields, so an unknown field passes silently (D-003). If a field needs input checks or documentation, it becomes a named argument.
- GP5: **Calls are safe to repeat.** Start, load, and download are no-ops with a message on a second call. Stop and unload act only on what the caller named and never close the desktop app.
- GP6: **Every message honors quiet.** User-facing output goes through the helpers in `R/utils-msg.R` and respects `rlmstudio.quiet` and a local `quiet` argument. Errors are exempt.

Disposition of the Phase 1 banked list: items 1, 2, 3, 7, and 8 became GP2, GP1, GP1, GP4, and GP3. Items 4 and 5 are conventions above and decisions D-002 and D-001. Items 6, 9, and 10 stay as convention and boundary text.

## Architecture

- One file per function family under `R/`. The chat result object lives in `R/chat_oop.R`.
- The daemon and server functions build `lms` command lines and run them with `processx`.
- The model and chat functions call the REST API at the running server through `lms_client()` in `R/chat.R`.

## Known issues

Recorded 2026-09-17 at the design interview.

- The headless CI job (`.github/workflows/test-headless.yaml`) installs no LM Studio. It runs only the tests that do not need a server.
- `lms_chat_openai()` returns `NULL` logprobs because LM Studio stubs them on that endpoint. Only the OpenResponses endpoint yields the logprobs data frame that `lms_score_expected()` consumes.
- The macOS check job reads every package from Posit Package Manager, which `R-CMD-check.yaml` sets as both the RSPM and the CRAN repo. That job therefore has no second source if Package Manager is down, and it loses the CRAN source-Archive fallback that the Ubuntu and Windows jobs keep. Accepted 2026-09-20 (M011) for as long as the zstd workaround stands.
