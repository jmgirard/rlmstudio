# M071: The getting-started vignette reads plainly and covers a first run

**Status:** done (2026-09-30, PR #71 https://github.com/jmgirard/rlmstudio/pull/71).

**Goal:** A researcher who knows R but has not run a local model can follow
`getting-started` from installing LM Studio to a first batch of replies.

**Outcome:** `vignettes/getting-started.Rmd.orig` is rewritten in the M070
register and knitted to `vignettes/getting-started.Rmd`. It starts at the
install and the `lms` checks. Then it covers the server, the model list,
the download, the load, one chat, a batch, and the clean-up. It points to
`headless-config`. `test-vignette-claims.R` gained 6 tests for its package
claims. NEWS has one entry.

**Decisions:** none cross-cutting. The gate kept the model on disk for the
knit and showed no download loop. The text names both download replies.

**Review:** One defect return. Two LM Studio sentences failed live calls and
were removed. A claim audit then fixed "a new install has no models". Pass 2
verified all 6 criteria with three lenses and 20 findings. The gate fixed
four text points. Four vignette gaps and two help-page lines went to one
ROADMAP row. The token went to M072, and 8 findings were rejected. The
vignette lesson was extended.
