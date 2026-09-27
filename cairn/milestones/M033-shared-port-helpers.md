# M033: The socket tests share one port helper that leaves the random seed alone

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** internal — test helpers that no package user calls
- **Branch/PR:** m033-shared-port-helpers

## Goal

The tests that need a real TCP socket get their ports from one helper file whose helpers never call the random number generator.

## Scope

**In:** A new `tests/testthat/helper-ports.R` with `local_listener()` and `free_port()`. Both take a `ports` argument (default `20000:40000`). They scan it from a start that `Sys.getpid()` sets. If no port in it binds, they raise an error. The copies in `tests/testthat/test-serve.R` and `tests/testthat/test-server-ready.R` go away. Their callers use the shared helpers. A new `tests/testthat/test-ports.R` tests the helpers.

**Out:** The other test-helper candidate rows in `cairn/ROADMAP.md` (the argument-guard loop, `request_target()` parsing) stay there as candidates. No package code under `R/` changes.

## Acceptance criteria

- [x] AC1: `tests/testthat/helper-ports.R` defines `local_listener()` and `free_port()`, and `grep -rnE "^[^#]*serverSocket\(" tests/testthat` reports matches in that file only.
- [x] AC2: `local_listener()` and `free_port()` leave `.Random.seed` unchanged. After `set.seed(1)`, it is identical after the call. If it was absent before the call, it is still absent.
- [x] AC3: If no port in its `ports` argument binds, each helper fails the calling test with an error that names the port range.
- [x] AC4: `devtools::test()` runs clean.

## Coverage

- AC1 → T2
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3

## Tasks

- [x] T1: Write `tests/testthat/test-ports.R` first. For each helper, test that `.Random.seed` stays identical after `withr::local_seed(1)`. Also test that it stays absent after `rm(".Random.seed", envir = globalenv())` under a withr restore. Test that two open `local_listener()` calls in one test return different ports. For the no-port error, hold one port `p` open with `local_listener()`. Then call each helper with `ports = p` and match the error message, never a bare `expect_error()`.
- [x] T2: Create `tests/testthat/helper-ports.R`. `local_listener(ports, env)` binds with `serverSocket()` and returns the port. It defers `close()` to `env` through `withr::defer()`. `free_port(ports)` binds, closes, and returns the port. Both walk `ports` from index `Sys.getpid() %% length(ports)`, with wrap-around. After at most 50 tries, they `stop()` with the range. Put `sample()` back into the new helper in a scratch edit, and see the T1 seed tests go red. Then delete the helpers at `test-serve.R:32-57` and `test-server-ready.R:10-30`. In `test-server-ready.R` (lines 32-72), move the three socket tests from `open_listener()` plus `on.exit()` to `local_listener()`.
- [x] T3: Run the AC1 grep and `devtools::test()`. The M001 line in `cairn/LESSONS.md` says that the port is random. Correct it and mark it `corrected M033`.

## Work log

- 2026-09-27: created by /milestone-plan. The reduced criteria audit ([O] reader) returned three findings, and the plan fixed all three. The AC1 grep now reads code lines only. AC2 and AC3 now state helper behavior, not "a test shows". AC3 gets a `ports` argument as its test seam.
- 2026-09-27: plan gate chose a port scan that starts from `Sys.getpid()` over `sample()` inside `withr::with_preserve_seed()`, because the preserved seed still makes every seeded run try the same ports first; falsified by two test processes on one machine colliding on ports under the scan.
- 2026-09-27: plan gate chose an error over `skip()` when no port binds, because a skip passes silently on CI; falsified by CI runs that fail only because every port in the range was taken.
- 2026-09-27: implement started on branch `m033-shared-port-helpers`. The question gate was skipped because the plan left no choice open.
- 2026-09-27: T1 done. `tests/testthat/test-ports.R` failed first with "could not find function" for both helpers.
- 2026-09-27: T2 done. With `sample()` planted in a scratch copy of the helper, the four seed checks in `test-ports.R` went red and the other six passed. Without the plant, all ten passed.
- 2026-09-27: T3 done. The AC1 grep matched `tests/testthat/helper-ports.R:14` only. `devtools::test()` gave FAIL 0, WARN 0, SKIP 0, PASS 9418. The M001 lesson now names the helpers.
- 2026-09-27: claim audit: not owed — internal tier

## Decisions

## Review

- AC1 (2026-09-27): `helper-ports.R` defines `local_listener()` (line 24) and `free_port()` (line 32). The AC1 grep matched `tests/testthat/helper-ports.R:14` only. No `open_listener` or `sample(` call remains in `tests/testthat`.
- AC2 (2026-09-27): A direct probe sourced `helper-ports.R` and called each helper. After `set.seed(1)`, `.Random.seed` was identical after the call. With `.Random.seed` removed, it was still absent after the call. Both held for both helpers. `test-ports.R` ran 10 of 10 expectations green.
- AC3 (2026-09-27): A probe held one port `p` open. Then `local_listener(ports = p)` and `free_port(ports = p)` each raised "No free port in 28575-28575." The `test-ports.R` case matches that message for both helpers and passed. The error comes from `stop()`, so it fails the calling test.
- AC4 (2026-09-27): `devtools::test()` with LM Studio running gave FAIL 0, ERROR 0, WARN 0, SKIP 0, PASS 9418.
- Gate (2026-09-27): `cairn_validate.py` passed all checks (exit 0). No principle changed, so `cairn_impact` was skipped. `devtools::document()` left `NAMESPACE`, `man/`, and `R/` unchanged. The diff touches only `tests/` and `cairn/`, so README, NEWS, and `.Rbuildignore` owe nothing. No pkgdown site exists. `devtools::check()` gave 0 errors, 0 warnings, 0 notes.
- Reviewers (2026-09-27): three fresh-context lenses ran. The prior-review lens found no prior-review evidence on these files. The blame-history lens found no conflict: the skip-to-error change matches the plan gate and D-006. The diff-bug lens reported eight findings, ranked below.
- Finding 1 ([O], `helper-ports.R:11-14`): if a second bind on a held port succeeds on Windows, two tests fail there. Refuted against R's `sock.c`: `SO_REUSEADDR` is set only outside Windows, so a second bind fails on Windows too. Disposition: reject.
- Finding 2 ([O], `helper-ports.R:11`): two test processes with adjacent process ids start one port apart and reuse the same ports. Disposition: pending at the gate.
- Finding 3 ([O], `helper-ports.R:19`): the error names the whole range after only 50 tries. Disposition: pending at the gate.
- Finding 4 ([O], `helper-ports.R:11-12`): a busy block of 50 ports after the start fails every socket test, where `sample()` spread its tries. Disposition: pending at the gate.
- Finding 5 ([O], `helper-ports.R:19`): `ports = integer(0)` gives a warning and the message "Inf--Inf". Disposition: reject, because no caller passes an empty range.
- Finding 6 ([O], `helper-ports.R:19`): a non-contiguous `ports` is reported by its min and max. Disposition: reject, because no caller passes one.
- Finding 7 ([O], `test-server-ready.R`): the skip-to-error change has no D-entry. Disposition: reject, because the plan gate chose it and the work log records it.
- Finding 8 ([O], `test-ports.R:43-46`): the `free_port()` test proves little beyond its callers. Disposition: reject, because it states the helper contract that AC1 moved into one file.
