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

### D-004 (2026-09-18): Failure-branch HTTP tests mock the transport, and recorded fixtures stay the default

**Context:** DESIGN names recorded `httptest2` fixtures as the everyday HTTP contract. A healthy LM Studio server returns no failure status. No recording can produce the non-200 bodies the failure branches read. A committed fixture also owes a generator script, which cannot reach those bodies either.
**Decision:** Response-branch and error-branch tests mock `httr2::req_perform` through the shared recorder in `tests/testthat/helper-mock-http.R`. Recorded fixtures remain the default for every path a live server can produce. Considered hand-writing fixture files under the cassette directories, rejected because a hand-written cassette claims a provenance it does not have.
**Consequences:** The suite carries two sanctioned HTTP-testing styles, chosen by whether a live server can produce the response. The recorder applies the request's own error policy, so a caller that drops its `req_error()` line still turns tests red. The inline `req_perform` closures in `test-load.R` and `test-chat.R` are a third, unsanctioned style, and folding them into the recorder is a candidate row.

### D-005 (2026-09-18): httpuv joins Suggests so tests can assert the HTTP verb

**Context:** httr2 infers the HTTP verb from the body rather than storing it on the request. So `httr2::req_dry_run()` is the only supported way to read the method. That call needs `httpuv`, which httr2 only suggests. The maintainer's machine had it and CI did not. The local suite passed at 100 while CI failed two tests.
**Decision:** `httpuv` joins Suggests as a test-only dependency. When the package is absent, `request_target()` skips its caller. Considered reading the path off `req$url` and inferring the verb from the body. That drops the direct verb assertion the implement gate chose, so it was rejected.
**Consequences:** Nothing a user installs at runtime changes. A contributor without `httpuv` sees skips rather than failures. A local green run is no longer evidence that CI is green. The CI wait at the merge gate is what settles that.
