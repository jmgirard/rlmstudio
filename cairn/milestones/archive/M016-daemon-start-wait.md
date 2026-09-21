# M016: The daemon start call can wait until the daemon reports running

**Status:** dropped (2026-09-20, user decision at the T1 premise gate). No
PR. Branch m016-daemon-start-wait deleted unmerged. No code changed.

**Goal:** `lms_daemon_start()` can wait until `lms daemon status --json`
reports the daemon running.

**Why dropped:** The plan made the milestone depend on one premise, which T1
tested: `lms daemon up` can return before the daemon runs. T1 ran on macOS
with LM Studio 0.4.25+1 and the desktop app closed. `lms daemon up` took 3.2
seconds and exited 0. It printed "LM Studio started (PID: 52104)". A
`lms daemon status --json` call run at once after it printed
`{"status":"running","pid":52104,"isDaemon":false}`. The call returned only
once the daemon ran, so a wait adds nothing. The plan's Premise section drops
the milestone on this evidence.

**Observed CLI output:** The stopped state prints `{"status":"not-running"}`
with exit 0. With nothing running, `lms daemon down` exits 1 with "Daemon is
not running." While the desktop app owns the daemon, it exits 1 with "The
daemon is currently running as part of LM Studio". On this Mac, `up`
launched the desktop app (`isDaemon` false). Nobody tested a headless
llmster install. A candidate row holds that check.

**Decisions:** none.
