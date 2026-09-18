# M001: Honor the host argument and fail fast on a stopped server

- **Status:** in-progress
- **Priority:** high
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** IP1, GP3, GP5
- **Resolves:** —
- **Surface tier:** user-facing — changes the behavior of exported functions and one internal probe they all share
- **Branch/PR:** m001-host-aware-probe

## Goal

Make every REST wrapper probe the server at the host the user names, abort with one condition class when it is down, and make `has_lms()` agree with `lms_path()`.

## Scope

**In:** `is_server_running()` in `R/serve.R` gains a `host` argument and probes the hostname and port parsed from it. Every call site under `R/` passes its `host`. `list_models()` and `lms_download()` abort instead of returning an empty result (GP3). Every server-down abort carries the condition class `rlmstudio_no_server`. `has_lms()` in `R/setup.R` returns TRUE when `lms_path()` succeeds. Tests, roxygen, and `NEWS.md` for each change. The return-shape changes are breaking and ship under D-001 with a NEWS entry.

**Out:** CI check jobs on macOS and Windows → M002. The headless CI job and the pre-release live-run procedure → ROADMAP candidate rows. Any change to the `host` default or to `lms_client()` → not needed; stays as is.

## Acceptance criteria

- [ ] AC1: `is_server_running(host)` parses hostname and port from `host` and probes that address. Evidence: a test opens `serverSocket()` on a free port and expects TRUE for `http://localhost:<port>` and for `http://127.0.0.1:<port>`, FALSE for a second free port with no listener, and FALSE for a hostname that is not the listening one at the listening port.
- [ ] AC2: Every occurrence of `is_server_running(` under `R/`, roxygen examples included, passes a `host` argument. Evidence: `grep -n "is_server_running(" R/*.R` shows no zero-argument occurrence.
- [ ] AC3: `list_models()` and `lms_download()` abort with condition class `rlmstudio_no_server` instead of returning an empty result, and the seven other server-down aborts (`R/chat.R:112,233,305,380`, `R/load.R:56`, `R/unload.R:35,108` at plan time) carry the same class. Evidence: `expect_error(class = "rlmstudio_no_server")` tests for `list_models()` and `lms_download()`, and a read of each of the seven named sites.
- [ ] AC4: `has_lms()` calls `lms_path()` and returns FALSE only when it aborts. Evidence: tests expecting TRUE for the `RLMSTUDIO_LMS_PATH` branch (`withr::local_envvar` on a temp file) and for the PATH branch (`withr::local_path` on a temp dir holding a fake executable `lms`), and a test expecting FALSE with the env var cleared, `PATH` set to an empty temp dir, and the common-directory lookup mocked to find nothing.
- [ ] AC5: Under `# rlmstudio (development version)` in `NEWS.md`, three bullets, each naming the affected function and stating the user-visible change: the server probe now honors `host`; `list_models()` and `lms_download()` now abort instead of returning an empty result; `has_lms()` now uses the same lookup as `lms_path()`.
- [ ] AC6: `devtools::document()` produces no diff and `devtools::test()` is clean (profile `verify` slot).

## Coverage

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T5

## Tasks

- [x] T1: Give `is_server_running()` a `host = "http://localhost:1234"` argument. Parse with `httr2::url_parse()`; use the URL's hostname and port, and 1234 when the URL names no port. Write the AC1 tests in `tests/testthat/test-serve.R` first.
- [ ] T2: Pass `host` at every call site (`R/chat.R`, `R/download.R`, `R/list.R`, `R/load.R`, `R/unload.R`) and in the `@examples` block of `is_server_running()` in `R/serve.R`. Change every test mock from `function() TRUE` to `function(...) TRUE`.
- [ ] T3: Add an internal helper `stop_if_no_server(host)` in `R/serve.R` that aborts with class `rlmstudio_no_server` and the existing message. Replace the seven existing abort sites and the two soft returns in `R/list.R` and `R/download.R` with it. Write the AC3 tests first. Sub-task: also replace the soft return in `lms_download_status()` at `R/download.R:134`, with a test of its own.
- [ ] T4: Rewrite `has_lms()` as a `tryCatch` around `lms_path()`. Update `check_lms_version()` and the roxygen of both. Write the AC4 tests first.
- [ ] T5: Add the three `NEWS.md` bullets. Run `devtools::document()` and `devtools::test()`; run `devtools::check()` and record the result.

## Work log

- 2026-09-17: created by /milestone-plan.
- 2026-09-17: criteria audit ran in full mode on a fresh [O] reader; it returned rewordings for AC1 (add a second hostname and a wrong-host probe), AC2 (include the roxygen example), AC3 (name the seven sites instead of a grep proxy), AC4 (cover the PATH branch and a real FALSE case), and AC5 (state what each bullet says); all adopted.
- 2026-09-17: plan gate chose no review brief over a Fable brief for the IP1 touch because the change narrows where text is sent rather than widening it; falsified by any code path that sends a request to a host the caller did not name.
- 2026-09-17: plan chose a port fallback of 1234 for a `host` with no port over the scheme default of 80 because 1234 is the package and LM Studio default; falsified by a user report of a server reached at a scheme-default port.
- 2026-09-17: implement started on branch m001-host-aware-probe; the tree carried an unrelated `.DS_Store` change, left unstaged.
- 2026-09-17: question gate chose to abort in `lms_download_status()` too (a tenth server-down site the plan did not list); added as a T3 sub-task, criteria unchanged.
- 2026-09-17: T1 done. Four probe tests in test-serve.R, all failing against the old probe with an unused-argument error. Installed httptest2 and mockery locally so the suite runs. `document()` refreshed `man/rlmstudio-package.Rd`, stale since the DESCRIPTION edit in 31fde62.

## Decisions

## Review
