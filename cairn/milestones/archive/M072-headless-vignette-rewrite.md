# M072: The headless vignette covers what differs without the desktop app

**Status:** done (2026-10-01, PR #72 https://github.com/jmgirard/rlmstudio/pull/72).

**Goal:** A user on a machine without the LM Studio desktop app, or with
LM Studio on another machine, can follow `headless-config` to a working server.

**Outcome:** `vignettes/headless-config.Rmd.orig` is rewritten and knitted.
It covers the headless install and its consent rules, the daemon, a slow
server start, and API tokens. It covers `LMS_SERVER_HOST` with the `host`
argument, and `with_lms_daemon()` with a caution for shared computers. The daemon stop,
the script, the install, and the remote calls are `eval = FALSE`.
`test-vignette-claims.R` backs each package claim. `R/setup.R` gained an
`interactive <- NULL` binding for the consent mocks. NEWS has one entry.

**Decisions:** none cross-cutting. The gate ran the daemon start and status
in the knit and showed the stop. It chose `LMS_SERVER_HOST` over an SSH tunnel.

**Review:** No return. All 7 criteria passed with three lenses and 15 merged
findings. The gate fixed 10: a DESIGN line that now allows `eval = FALSE`,
seven prose points, and two tests. Two were rejected, two noted. The
`lms daemon up` row and finding 4 moved to DESIGN Known issues. One AC3
line was rewrapped because the validator read a code span as a fence. The
M014 mocking lesson was extended.
