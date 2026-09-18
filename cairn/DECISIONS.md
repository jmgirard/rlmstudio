<!-- Instantiated by /cairn-init as cairn/DECISIONS.md (file header; entries
     are appended from templates/decision.md). A migration replaces the body
     note with its pointer-only or re-recorded disposition (migration
     protocol step 5). -->
# Decisions

Append-only. Never renumber; supersede with a new entry. D-entries record
choices with rationale — never deferrals ("not now" is a ROADMAP fact).

### D-001 (2026-09-17): Pre-1.0 waiver of the deprecation cycle

**Context:** The package is on CRAN at 0.2.2 with an experimental lifecycle badge. The tracking rules require a deprecation cycle for breaking changes unless the project is pre-1.0 and the user waives it.
**Decision:** Until 1.0, any exported name or return shape can change with a NEWS entry and no deprecation cycle.
**Consequences:** Milestones before 1.0 do not plan deprecation shims. The waiver ends at the 1.0 release, which takes a superseding entry.

### D-002 (2026-09-17): macOS, Linux, and Windows are all release commitments

**Context:** CI runs R CMD check on Ubuntu only. Many target users run Windows with NVIDIA GPUs, and the maintainer has machines for each platform.
**Decision:** A reproducible bug on any of the three platforms blocks a release.
**Consequences:** CI needs macOS and Windows check jobs (a ROADMAP candidate). Platform-specific code in `R/path.R` and `R/setup.R` needs tests on each platform.

### D-003 (2026-09-17): The server validates API fields, not the package

**Context:** Every REST wrapper forwards `...` into the request body (GP4). A misspelled field passes silently, which collides with fail-fast (GP3).
**Decision:** The package keeps no list of valid API fields. It forwards unknown fields and surfaces whatever error the server returns. Considered warning or erroring on unknown fields, rejected because the list goes stale each time LM Studio ships a field.
**Consequences:** A typo in a dot argument can be ignored without a message. The documentation for `...` states this limit.
