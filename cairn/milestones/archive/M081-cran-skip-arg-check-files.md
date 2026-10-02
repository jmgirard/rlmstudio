# M081: The CRAN check skips the three argument-check test files

**Status:** done (2026-10-02, PR #83 https://github.com/jmgirard/rlmstudio/pull/83)

**Goal:** The Windows R-devel check of the package takes less than 10 minutes, because CRAN skips the three argument-check test files.

**Outcome:** `tests/testthat/test-arg-guards.R`, `test-flag-args.R`, and `test-name-faults.R` call `testthat::skip_on_cran()` at line 4, below a comment that gives the reason. If `NOT_CRAN` is unset, `r-lib/actions/setup-r@v2`, `devtools::test()`, and `devtools::check()` set it to `true`, so CI and local runs still run the files. The CRAN incoming check of 0.3.0 at 9c2a2df took 13 min, with 11 min in tests. A win-builder R-devel check of the branch took 463 s, with 348 s in tests and Status OK. Locally, the CRAN-mode test time fell from 97.5 s to 51.7 s. `cairn/DESIGN.md` now names the three skips in its test conventions.

**Decisions:** none. The plan chose a whole-file skip over one probe per test loop on CRAN.

**Review:** Fan-out of three fresh reviewers, with 9 findings and no bug. F3 and F4 were fixed at the gate. DESIGN gained a sentence. The skip comment now names `devtools::test()` and any run without `NOT_CRAN=true`. F1 (request-body tests that CRAN no longer runs) and F2 (no Windows R-devel job) became candidate rows. F5 to F8 were rejected, and F9 was noted. The PR's source-tree job passed 24,557 expectations with no "On CRAN" skip. No lesson was added or retired.
