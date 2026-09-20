# M009: The package can authenticate to LM Studio.

**Status:** done (2026-09-20, PR #10 https://github.com/jmgirard/rlmstudio/pull/10)

**Goal:** Every exported function that reaches the LM Studio REST API can send an API token.

**Outcome:** `rlm_token()` in `R/utils-token.R` reads the `token` argument, then the
`rlmstudio.token` option, then the `RLMSTUDIO_API_TOKEN` environment variable. `NULL` and the
empty string count as unset, and any other shape aborts. `lms_client()` takes `token` and sets
the header with `httr2::req_auth_bearer_token()`, which renders as `<REDACTED>` under `print()`.
Eleven exported functions take `token`, placed after `...` on the nine with dots, so no argument
moved. `rlm_abort_api()` takes a `token_sent` flag and `api_error_hint()` holds the two wordings:
401 and 403 with no token name the variable, with a token say the server refused it, and other
statuses gain no hint. `request_target()` returns headers unredacted, `httpuv_absence_action()`
makes a missing `httpuv` raise under CI, and `R/token.R` holds the `rlmstudio_token` topic.

**Decisions:** D-006 narrows D-005 on the httpuv skip. Milestone-local: the token-hiding tests
read `conditionMessage()`, not the printed condition, whose backtrace echoes the caller's literal.

**Review:** One pass, six criteria verified, six cases live against an authenticated server.
Gate clean, `devtools::check()` 0/0/0. The fan-out returned eight findings, all from the
diff-bug lens. Five were fixed, the largest being that a malformed `token` argument was
discarded in silence and replaced by another source. Two became candidate rows, one was
rejected. Merged with `macos-latest (release)` red, as a recorded override: that job dies
downloading a dependency from a lagging mirror and never builds the package.
