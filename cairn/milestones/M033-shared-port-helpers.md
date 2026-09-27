# M033: The socket tests share one port helper that leaves the random seed alone

- **Status:** planned
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — test helpers that no package user calls
- **Branch/PR:** —

## Goal

The tests that need a real TCP socket get their ports from one helper file whose helpers never call the random number generator.

## Scope

**In:** A new `tests/testthat/helper-ports.R` with `local_listener()` and `free_port()`. Both take a `ports` argument (default `20000:40000`). They scan it from a start that `Sys.getpid()` sets. If no port in it binds, they raise an error. The copies in `tests/testthat/test-serve.R` and `tests/testthat/test-server-ready.R` go away. Their callers use the shared helpers. A new `tests/testthat/test-ports.R` tests the helpers.

**Out:** The other test-helper candidate rows in `cairn/ROADMAP.md` (the argument-guard loop, `request_target()` parsing) stay there as candidates. No package code under `R/` changes.

## Acceptance criteria

- [ ] AC1: `tests/testthat/helper-ports.R` defines `local_listener()` and `free_port()`, and `grep -rnE "^[^#]*serverSocket\(" tests/testthat` reports matches in that file only.
- [ ] AC2: `local_listener()` and `free_port()` leave `.Random.seed` unchanged. After `set.seed(1)`, it is identical after the call. If it was absent before the call, it is still absent.
- [ ] AC3: If no port in its `ports` argument binds, each helper fails the calling test with an error that names the port range.
- [ ] AC4: `devtools::test()` runs clean.

## Coverage

- AC1 → T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3

## Tasks

- [ ] T1: Write `tests/testthat/test-ports.R` first. For each helper, test that `.Random.seed` stays identical after `withr::local_seed(1)`. Also test that it stays absent after `rm(".Random.seed", envir = globalenv())` under a withr restore. Test that two open `local_listener()` calls in one test return different ports. For the no-port error, hold one port `p` open with `local_listener()`. Then call each helper with `ports = p` and match the error message, never a bare `expect_error()`.
- [ ] T2: Create `tests/testthat/helper-ports.R`. `local_listener(ports, env)` binds with `serverSocket()` and returns the port. It defers `close()` to `env` through `withr::defer()`. `free_port(ports)` binds, closes, and returns the port. Both walk `ports` from index `Sys.getpid() %% length(ports)`, with wrap-around. After at most 50 tries, they `stop()` with the range. Put `sample()` back into the new helper in a scratch edit, and see the T1 seed tests go red. Then delete the helpers at `test-serve.R:32-57` and `test-server-ready.R:10-30`. In `test-server-ready.R` (lines 32-72), move the three socket tests from `open_listener()` plus `on.exit()` to `local_listener()`.
- [ ] T3: Run the AC1 grep and `devtools::test()`. The M001 line in `cairn/LESSONS.md` says that the port is random. Correct it and mark it `corrected M033`.

## Work log

- 2026-09-27: created by /milestone-plan. The reduced criteria audit ([O] reader) returned three findings, and the plan fixed all three. The AC1 grep now reads code lines only. AC2 and AC3 now state helper behavior, not "a test shows". AC3 gets a `ports` argument as its test seam.
- 2026-09-27: plan gate chose a port scan that starts from `Sys.getpid()` over `sample()` inside `withr::with_preserve_seed()`, because the preserved seed still makes every seeded run try the same ports first; falsified by two test processes on one machine colliding on ports under the scan.
- 2026-09-27: plan gate chose an error over `skip()` when no port binds, because a skip passes silently on CI; falsified by CI runs that fail only because every port in the range was taken.

## Decisions

## Review
