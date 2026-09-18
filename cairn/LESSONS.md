<!-- Instantiated by /cairn-init as cairn/LESSONS.md (file header; the
     scaffold ships it empty of lessons). One line per lesson; corrected in
     place when proven false; retirement per tracking-rules "Retiring a
     lesson". -->
# Lessons

Durable repo lessons — build quirks, testing tricks, gotchas worth
remembering next time — captured at milestone end and surfaced at plan time.
Not status, not decisions: a lesson is a reusable "how this repo actually
behaves" note. Cross-cutting *choices* still go to `DECISIONS.md`.

One line per lesson: `- YYYY-MM-DD (M<NNN>): <lesson>`. Two caps: 50 lines
and 20,000 bytes; over either, retire or prune before adding. Corrected in
place when proven false (never append a correction).
- 2026-09-17 (M001): `httr2::url_parse()` keeps the brackets of an IPv6 literal in `$hostname` and errors on a schemeless `host:port`; normalize before handing a hostname to `socketConnection()`.
- 2026-09-17 (M001): `testthat::local_mocked_bindings(..., .package = "base")` works for `file.exists` and `socketConnection` called from package code; a listening `serverSocket()` on a random 20000–40000 port gives a real TCP target without a server.
- 2026-09-17 (M002): The `test-headless` job installs its R packages from the `r2u.stat.illinois.edu` apt mirror. A timeout there fails the job with `Unable to locate package r-cran-httptest2`, which reads like a missing dependency. Re-run the job before investigating.
- 2026-09-18 (M003): A function can delegate to one that runs its own server check. A test that mocks `is_server_running` then passes with the call site under test deleted. Mock the delegate out, then delete the call site in a scratch copy and confirm that the test goes red. `lms_load()` and `lms_unload_all()` reach `list_models()`, and `lms_chat_batch()` reaches `lms_chat()`.
- 2026-09-17 (M002): Every check workflow limits its `push` trigger to `main` and `master`, so pushing a milestone branch starts no `R-CMD-check` run. The `pull_request` trigger carries no branch filter, so the first multi-platform signal arrives with the pull request.
