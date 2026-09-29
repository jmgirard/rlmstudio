# M055: Cleanup of vignette teardown, test helpers, and the token hint

**Status:** done (2026-09-29, PR #55 https://github.com/jmgirard/rlmstudio/pull/55).

**Goal:** Vignette builds and live test runs leave the LM Studio server and
the loaded models as they found them. The 401 and 403 hint matches the
request sent.

**Outcome:** Both vignettes read `server_was_running` and `model_was_loaded`
in hidden chunks and stop or unload only what the build started. This holds
where the desktop app runs the daemon. `test-chat.R` and `test-integration.R`
lost the `on.exit()` unload outside the mock blocks. `loaded_embedding_models()`
lets a `list_models()` error fail the live embedding tests. `request_target()`
returns a non-JSON body as text and takes `redact_headers = TRUE`. The new
`request_sends_token()` reads the built request, and the nine
`rlm_abort_api()` sites take their hint from it. NEWS has two entries.

**Decisions:** none cross-cutting. The plan gate chose a failing test over a
skip on a model-list error, and a hint read off the built request.

**Review:** Two passes of three lenses. Pass 1 gave an amendment return that
bound AC1 to a desktop-app host. Pass 2 verified 5 of 5 criteria and fixed
five findings. After approval, covr failed the site-count test on an
installed `R/` with no `.R` file, and a skip fixed it. Four candidate rows
were added or extended. The M005 and M009 lessons were corrected.
