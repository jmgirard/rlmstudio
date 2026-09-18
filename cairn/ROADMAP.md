# Roadmap

_The only authority on milestone status. Grouped by status, not ID._
_Last hygiene check: 2026-09-17 (scaffolded by cairn-init)_

## Milestones

| ID | Title | Status | Depends on | Priority | File/Archive |
|---|---|---|---|---|---|
<!-- Rows are grouped by status, not sorted by ID. Keep only the 3 most recent
     terminal (done or dropped) rows. Older ones live in milestones/archive/ and git. -->

## Candidates
<!-- Unnumbered ideas, one line each, ordered high, then normal, then low:
     - [high] idea, added YYYY-MM-DD, links
     - idea, added YYYY-MM-DD, links
     The opening token is [high] or [low] or absent (normal).
     See tracking-rules "Candidate priority token". -->
- [high] Add macOS and Windows R CMD check jobs to CI, so the all-platform commitment in DESIGN.md is automated, added 2026-09-17, DESIGN Platforms
- [high] Make the server probe honor the `host` argument (`is_server_running()` always probes localhost:1234), added 2026-09-17, DESIGN Known issues
- Make `list_models()` and `lms_download()` abort on a stopped server, to match the error posture in DESIGN Conventions, added 2026-09-17, DESIGN Known issues
- Make `has_lms()` use the same lookup as `lms_path()`, added 2026-09-17, DESIGN Known issues
- Write the pre-release live-run procedure (full suite against a running LM Studio, re-record stale fixtures) into the release walk, added 2026-09-17, DESIGN Conventions
- [low] Make the headless CI job install LM Studio or rename it to say what it runs, added 2026-09-17, DESIGN Known issues
