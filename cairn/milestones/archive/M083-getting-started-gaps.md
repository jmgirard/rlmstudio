# M083: The getting-started vignette covers the first app run, a finished download, the server port, and finding model keys

**Status:** done (2026-10-18, PR #86 https://github.com/jmgirard/rlmstudio/pull/86).

**Goal:** A reader who follows `vignette("getting-started")` on a new machine does not stop at one of the four gaps that the M071 review found.

**Outcome:** `vignettes/getting-started.Rmd.orig` tells the reader to open
the app once after the install (from https://lmstudio.ai/docs/cli), starts
the server with `port = 1234`, says that a key is the end of a model's page
address at https://lmstudio.ai/models and not the `lms get` name, and names
the `status` values "downloading", "completed", "failed", and
"already_downloaded". The `lms_server_ready()` help drops the fresh-install
claim. `test-vignette-claims.R` gained a port test and a status test. NEWS
has one entry. Live probes: a no-port start reuses the last port.

**Decisions:** none cross-cutting. The plan chose an explicit port over a
recovery note, and a catalog pointer over a search function (GP1).

**Review:** All 7 criteria verified with live runs. The claim audit fixed 2
of 21 claims. Three lenses gave 17 findings: 2 fixed (the "failed" status,
"the first case"), 4 sent to the "No-port start outside getting-started"
row, 10 rejected, 1 noted. CI green on the first wait. Graduated the four
gaps row and narrowed the `lms_server_start()` help row. One lesson added.
