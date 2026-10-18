# M084: The server-start examples pass port 1234, and the no-port message names the last-used port

**Status:** done (2026-10-18, PR #87 https://github.com/jmgirard/rlmstudio/pull/87).

**Goal:** A reader who copies a server start from the README, a vignette, or a help example starts the server on port 1234, where the package's other calls look.

**Outcome:** The README Quick Start, `chat-options`, `text-analysis`,
`headless-config`, and the roxygen examples of 12 help pages start the
server with `port = 1234`. The one exception, `lms_server_start(port = 8080,
cors = TRUE)`, has a comment naming the `host` the other calls then need. A
no-port start reports "on the port that LM Studio used last". The `port`
help names `http://localhost:1234`. The browser branch of
`install_lmstudio()` says to open the app once. The three vignettes were
re-knit live. New tests: the start message, the install message, and a
source test over `README.Rmd` and `vignettes/*.Rmd.orig`. NEWS has two bullets.

**Decisions:** none cross-cutting. The `port` default stays `NULL` (user's
choice). AC3 was narrowed to the examples sections at a user stop.

**Review:** 7 criteria verified. Three lenses gave 18 findings: 7 fixed
(NEWS wording, a tighter nested source test, the cassette script's port), 5
follow-up (the "server-start hints" and "install message quiet" rows), 6
rejected. CI green on the first wait. One `devtools::check()` gave an
unnamed test ERROR, and the rerun was clean. Graduated the "No-port start
outside getting-started" row. One lesson added.
