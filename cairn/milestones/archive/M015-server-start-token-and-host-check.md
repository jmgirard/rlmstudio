# M015: The server start call takes a token and checks its wait arguments before it starts

**Status:** done (2026-09-20, PR #16 https://github.com/jmgirard/rlmstudio/pull/16,
every check green, squash c2c6744)

**Goal:** `lms_server_start()` takes a `token` for its readiness wait. A fault
in `host` or `token` never aborts after the CLI started the server.

**Outcome:** `lms_server_start()` gained `token`, which reaches
`lms_server_ready()` through `warn_unless_ready()` and `wait_for_server()`.
`server_ready_request()` builds the readiness request for `lms_server_ready()`
and for `rlm_check_ready_host()`. Before the CLI runs, `rlm_token(token)` and
then `rlm_check_ready_host(host)` abort on a bad value, with any `wait`.
`warn_unless_ready()` turns an abort from the probe into one `cli_warn()` that
names the host. The token wrapper table lists fourteen functions.

**Decisions:** none cross-cutting. The plan gate chose a request build over a
shape check on `host`, and a warning over an abort for a probe abort.

**Review:** Three-lens fan-out, user-facing tier, 11 findings. Four were fixed
at the gate. The no-CLI stub called `fail()`, which `expect_error()` absorbed.
The quoted reason had no test, the help text left out `wait`, and one comment
was wrong. A
pre-start check of a host built from `port` became a candidate row. Six were
rejected. All CI checks passed.
