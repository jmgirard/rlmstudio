# M001: Honor the host argument and fail fast on a stopped server

**Status:** done (2026-09-17, PR #2 https://github.com/jmgirard/rlmstudio/pull/2)

**Goal:** Make every REST wrapper probe the server at the host the user names, abort with one condition class when it is down, and make `has_lms()` agree with `lms_path()`.

**Outcome:** `is_server_running(host)` in `R/serve.R` parses hostname and port with `httr2::url_parse()` (port 1234 when none is named, `http://` assumed for a schemeless host, IPv6 brackets stripped, an unparseable host reported as not running). A new internal `stop_if_no_server(host)` aborts with class `rlmstudio_no_server`; all ten server-down sites in `R/chat.R`, `R/download.R`, `R/list.R`, `R/load.R`, and `R/unload.R` call it, so `list_models()`, `lms_download()`, and `lms_download_status()` abort instead of returning an empty result. `has_lms()` in `R/setup.R` is a `tryCatch` around `lms_path()`; `check_lms_version()` looks the path up once. Tests in test-serve.R, test-list.R, test-download.R, test-setup.R; three NEWS bullets; `^CLAUDE\.md$` added to `.Rbuildignore`.

**Decisions:** port fallback of 1234 for a host that names no port (plan-local, in the work log). Breaking return-shape changes shipped under D-001.

**Review:** three-lens fan-out. Prior-review and blame-history lenses: zero findings. Diff-bug lens: 15 findings; fixed now: IPv6 brackets, schemeless host, unparseable host escaping the condition class, `quiet` doc for `list_models()`; follow-up candidate: class tests for the seven chat, load, and unload sites; ten rejected with reasons in git history. Hygiene retired the three Known issues entries this milestone resolved.
