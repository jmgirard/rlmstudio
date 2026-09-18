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

- macOS, Linux, and Windows are all commitments. A reproducible bug on any of them blocks a release. CI today runs R CMD check on Ubuntu only (`.github/workflows/`). The commitment is ahead of the automation.

### Stability and release

- Until 1.0, any exported function can change. A rename or a changed return shape needs a NEWS entry, not a deprecation cycle. This is the explicit pre-1.0 waiver that the tracking rules allow.
- If a feature set is ready, CRAN receives a release. There is no fixed cadence. GitHub `main` is the development channel.

### Dependencies

- Imports are cli, httr2, jsonlite, processx, and utils. Adding one is a recorded decision with rationale, never a side effect of a feature.

## Function Families

Read from NAMESPACE and the pkgdown reference index on 2026-09-17.

- Setup: `install_lmstudio`, `has_lms`, `check_lms_version`, `lms_path`.
- Daemon and server: `lms_daemon_start`, `lms_daemon_stop`, `lms_daemon_status`, `with_lms_daemon`, `lms_server_start`, `lms_server_stop`, `lms_server_status`.
- Model management: `list_models`, `lms_download`, `lms_download_status`, `lms_load`, `lms_unload`, `lms_unload_all`.
- Chat and inference: `lms_chat`, `lms_chat_batch`, `lms_chat_native`, `lms_chat_openai`, `lms_chat_openresponses`.
- Analysis (experimental): `lms_score_expected`.
- S3 classes: `lms_chat_result` (text plus token logprobs) and `lms_download_status`, each with a print method.

## Conventions

Observed in the code and agreed at the interview on 2026-09-17.

- User-facing messages go through `cli`. The `rlmstudio.quiet` option and a local `quiet` argument silence them (`R/utils-msg.R`).
- HTTP calls use `httr2`. JSON uses `jsonlite`. External processes use `processx`.
- Every REST wrapper merges `...` into the request body. Dots are the intended escape hatch for API fields that the package does not name. If a field needs input checks or documentation, it becomes a named argument.
- If the server is not running, a function aborts with a message that names `lms_server_start`. This is the intended posture. Two functions do not follow it yet (Known issues).
- Tests use testthat edition 3. Recorded HTTP fixtures (`httptest2`, under `tests/testthat/<name>/localhost-1234`) are the everyday contract. The helpers in `tests/testthat/helper-skips.R` skip the tests that need a live LM Studio. A CRAN release requires a full live run on a real machine and a new recording of stale fixtures.
- Code is formatted with Air (`air.toml`).
- The changelog is `NEWS.md`. The site is pkgdown in release mode.

## Design Principles

Phase 2 of `/design-interview` formalizes these. The IP (Inviolable) block comes first, then the GP (Guiding) block. Numbers are never reused.

### Inviolable

### Guiding

### Banked candidates (interview in progress, 2026-09-17)

Proto-principles heard in Phase 1. Not yet classified. Phase 2 replaces this list.

1. Batch pipelines win ties over console convenience.
2. One wrapper per LM Studio feature. The package ends where LM Studio's CLI and API end, plus scoring-workflow analysis.
3. A new export must wrap an LM Studio feature or serve scoring at scale.
4. macOS, Linux, and Windows are all release commitments.
5. Before 1.0, exported names and return shapes can change with a NEWS entry.
6. The five Imports are fixed. Adding one is a decision, not a side effect.
7. Dots pass through to the API body. Named arguments are added on demand.
8. A missing server is an error, never an empty result.
9. Recorded fixtures are the everyday contract. A live run gates each CRAN release.
10. `lms_score_expected` is experimental and can change or leave.

## Architecture

- One file per function family under `R/`. The chat result object lives in `R/chat_oop.R`.
- The daemon and server functions build `lms` command lines and run them with `processx`.
- The model and chat functions call the REST API at the running server through `lms_client()` in `R/chat.R`.

## Known issues

Recorded 2026-09-17 at the design interview.

- `is_server_running()` in `R/serve.R` always probes `localhost:1234`. Every REST function accepts a `host` argument, but each reports a server on another host or port as not running.
- If the server is down, `list_models()` returns an empty data frame and `lms_download()` returns `NULL`. The intended posture is to abort (Conventions).
- `has_lms()` in `R/setup.R` looks only at the system `PATH`. `lms_path()` also looks at `RLMSTUDIO_LMS_PATH` and common install directories. The two can disagree.
- The headless CI job (`.github/workflows/test-headless.yaml`) installs no LM Studio. It runs only the tests that do not need a server.
- `lms_chat_openai()` returns `NULL` logprobs because LM Studio stubs them on that endpoint. Only the OpenResponses endpoint yields the logprobs data frame that `lms_score_expected()` consumes.
