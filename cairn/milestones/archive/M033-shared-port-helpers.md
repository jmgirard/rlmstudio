# M033: The socket tests share one port helper that leaves the random seed alone

**Status:** done (2026-09-27, PR #33 https://github.com/jmgirard/rlmstudio/pull/33)

**Goal:** The tests that need a real TCP socket get their ports from one
helper file whose helpers never call the random number generator.

**Outcome:** `tests/testthat/helper-ports.R` defines `local_listener()` and
`free_port()`. Both scan up to 50 ports of `ports` (default `20000:40000`).
The scan starts at the process id times 97 and wraps around. When no port
binds, they `stop()` with the range and the count tried. The copies in
`test-serve.R` and `test-server-ready.R` are gone, and the old `skip()` on
no free port became that error. `test-ports.R` tests seed identity, seed
absence, two distinct listeners, and the error for both helpers. The M001
lesson now names the helpers.

**Decisions:** none. The plan gate chose the process-id scan over `sample()`
under a preserved seed, and an error over `skip()`.

**Review:** One pass, three-lens fan-out. All four criteria passed, and
`devtools::check()` was clean. Two lenses found nothing. The diff-bug lens
found 8 items. The gate fixed 2: adjacent process ids shared ports, and the
error hid the try count. It sent 1 to a candidate row, a busy block of 50
ports. It rejected 5. One was a Windows rebind concern. R's `sock.c` refutes
it, and the Windows CI job passed.
