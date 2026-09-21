# M014: The server start call can wait until the REST API answers

**Status:** done (2026-09-20, PR #15 https://github.com/jmgirard/rlmstudio/pull/15,
every check green, squash 7ac62d9)

**Goal:** `lms_server_start()` can wait until the REST API answers.

**Outcome:** `lms_server_start()` gained `wait` (default 10 seconds) and `host`.
`rlm_check_wait()` aborts on a bad `wait` before the CLI runs. `wait_host()`
picks the host: `host`, then `port`, then the port `server_status_port()` reads
from `lms server status --json`. `wait_for_server()` polls `lms_server_ready()`
every 0.25 s with a 1 s timeout and `token = NULL`. `warn_unless_ready()` warns
through `cli::cli_warn()` when the wait runs out or no port is found. The help
page of `lms_server_ready()` lists the call faults that abort it. NEWS.md and
both `start-server` vignette chunks cover the wait.

**Decisions:** none cross-cutting. The implement gate chose the 0.25 s pause,
the 1 s probe timeout, and unclassed warnings.

**Review:** Three-lens fan-out, user-facing tier, 14 findings. Six were fixed at
the gate: a doubled warning on an unparsed status read, two wrong claims about
the wait budget, two test gaps, and one vignette paragraph. The `host` guard
stays a candidate row. Three were rejected and four noted. All CI checks passed.
