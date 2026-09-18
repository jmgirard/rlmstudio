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
