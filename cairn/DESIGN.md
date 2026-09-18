# Design

_Architecture as it is. Future work lives in ROADMAP.md. Status lives nowhere here._

## Purpose & Scope

Seeded by cairn-init on 2026-09-17 from DESCRIPTION, README, and a read of `R/`. Refine these lines. Run `/design-interview` to elicit the parts the code cannot show.

- rlmstudio is an unofficial R wrapper for the LM Studio command line interface (the `lms` executable) and its v1 REST API.
- It lets an R user download local models and start or stop the server and the headless daemon. It also loads and unloads models and generates text from R.
- It targets LM Studio 0.4.0 or higher and the v1 REST API.
- It is on CRAN (0.2.2) and in the experimental lifecycle stage. The development version is 0.2.2.9000.
- Out of scope: a GUI, model training, and anything the LM Studio CLI or API does not expose.

## Function Families

Read from NAMESPACE and the pkgdown reference index on 2026-09-17.

- Setup: `install_lmstudio`, `has_lms`, `check_lms_version`, `lms_path`.
- Daemon and server: `lms_daemon_start`, `lms_daemon_stop`, `lms_daemon_status`, `with_lms_daemon`, `lms_server_start`, `lms_server_stop`, `lms_server_status`.
- Model management: `list_models`, `lms_download`, `lms_download_status`, `lms_load`, `lms_unload`, `lms_unload_all`.
- Chat and inference: `lms_chat`, `lms_chat_batch`, `lms_chat_native`, `lms_chat_openai`, `lms_chat_openresponses`, `lms_score_expected`.
- S3 classes: `lms_chat_result` (text plus token logprobs) and `lms_download_status`, each with a print method.

## Conventions

Observed in the code on 2026-09-17. Confirm or correct.

- User-facing messages go through `cli`. The `rlmstudio.quiet` option and a local `quiet` argument silence them.
- HTTP calls use `httr2`. JSON uses `jsonlite`. External processes use `processx`.
- Tests use testthat edition 3. Tests that need a live LM Studio are skipped by helpers in `tests/testthat/helper-skips.R`. HTTP tests use `httptest2` and `mockery`.
- Code is formatted with Air (`air.toml`).
- The changelog is `NEWS.md`. The site is pkgdown in release mode.

## Design Principles

None yet. `/design-interview` elicits them. The IP (Inviolable) block comes first, then the GP (Guiding) block. Numbers are never reused.

### Inviolable

### Guiding

## Architecture

- One file per function family under `R/`. The chat result object lives in `R/chat_oop.R`.
- The daemon and server functions build `lms` command lines and run them with `processx`.
- The model and chat functions call the REST API at the running server.

## Known issues

None recorded at init.
