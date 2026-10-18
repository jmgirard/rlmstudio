# M085: The no-server hints name the port of the host that the call asked

**Status:** done (2026-10-18, PR #88 https://github.com/jmgirard/rlmstudio/pull/88).

**Goal:** A user who follows a no-server hint starts the server on the port that the failed call asked.

**Outcome:** `host_address()` in `R/serve.R` holds the one host parse that
`is_server_running()` and the new `no_server_hint()` share. The
`rlmstudio_no_server` aborts of `stop_if_no_server()` and of the chat lookup
`reply_model_serves()` say "Run `lms_server_start(port = <p>)` first." for a
hostname of `localhost`, in any letter case, or `127.0.0.1`, with the port the
probe uses (1234 when `host` names none). For any other host, or one that does
not parse, they name the host and no start call. The "Server not running" help
and the headless `install_lmstudio()` message say the same. New tests: a host
table in `test-serve.R` (a brace host included), the lookup hint on both chat
routes, and the headless install message. One NEWS bullet.

**Decisions:** D-042 records the narrowed start-call wording as a trade of
GP3, and `DESIGN.md` line 52 was corrected to match.

**Review:** 6 criteria verified. Three lenses gave 13 findings: 5 fixed (D-042
and the DESIGN text, the help example, the NEWS letter-case sentence, a
brace-host test row), 8 rejected (the `::1` scope choice four times, the
probe's port for `:0` and https, style, the mock order, the last-port claim,
the two-line message). CI green on the first wait. Graduated the
"server-start hints" row.
