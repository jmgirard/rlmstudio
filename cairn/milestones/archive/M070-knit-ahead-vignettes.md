# M070: The vignettes are knitted ahead of time from a live LM Studio

**Status:** done (2026-09-30, PR #70 https://github.com/jmgirard/rlmstudio/pull/70).

**Goal:** Each vignette ships with output that the author knitted ahead of
time from a live LM Studio, so a package check and a CRAN build never reach
LM Studio.

**Outcome:** The vignettes moved to `vignettes/<name>.Rmd.orig` sources. They
lost the gates, state chunks, pasted output, and build paragraphs. `data-raw/knit-vignettes.R` knits them to
`vignettes/<name>.Rmd`. It refuses to start with the server running or a
model loaded. It knits with `error = FALSE` in a new environment. It resets
the server and models after each source and in a `finally` clause.
`.Rbuildignore` excludes the sources. DESIGN Conventions holds the knit-ahead
rule, the prose register and word list, and the code list. NEWS has one entry.

**Decisions:** none cross-cutting. The plan gate chose the knit-ahead build
over the live build of M068 and the state chunks of M055.

**Review:** Three lenses. All 5 criteria verified, check clean with no
LM Studio. Of 16 findings, the gate fixed five: NEWS, the knit
environment, the reset after each source, and a lesson. Daemon teardown on a
headless host, chunk warnings, and stale output went to candidate rows. The
rest went to the M071 to M073 work logs or were rejected.
