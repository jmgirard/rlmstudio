<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M032: A download status picks the unit of a size or speed after rounding

- **Status:** review   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — it changes what `print()` shows for a download status   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m032-download-unit-rounding   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

`print()` on a download status shows a size or speed of 1023.9 bytes as `1 KB`
and not as `1020 B`, because the unit is picked after the value is rounded.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** `format_bytes()` in `R/download.R:348-358` picks the largest unit in
which the value, rounded to three significant digits, is 1 or more. Its
roxygen comment at `R/download.R:338-342` states that rule. New tests at the
four unit thresholds. The unreleased NEWS bullet from M030 states the rule.

**Out:** a value from 999.5 to 1023.4 bytes keeps a four-digit figure such as
`1000 B` or `1020 B`. The plan gate chose that, and no row holds it. A value
of 1024 TB or more stays in TB, because TB is the largest unit. No PB unit,
not planned. The `scipen` and `OutDec` options and the `1e-09 B/s` form stay
as M030 review rejected them.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets.
     Every item opens with its positional label — `ACn:` — the item's
     position counted top-to-bottom, the number Coverage cites; an
     insertion, removal, or reorder renumbers the labels and the Coverage
     lines together.
     Driving RR set → its Binding criteria appear VERBATIM here (binding-
     criteria check), each ingested as a numbered criterion carrying its tag
     — `- [ ] ACn (BCm): <verbatim>` — with its own Coverage line, since
     coverage-complete counts AC checkboxes positionally (M107); departures:
     a "Deviations from RR<NN>" table ends this section. -->

- [x] AC1: `print()` on a download status shows each size and the speed in
      the largest of B, KB, MB, GB, and TB (base 1024) in which the value,
      rounded to three significant digits, is 1 or more. When no unit gives
      such a value, the unit is B. A test in
      `tests/testthat/test-load-download-shape.R` pins, at each of the four
      unit thresholds (1024 to the power 1 through 4), two values below the
      threshold. One prints `1 KB`, `1 MB`, `1 GB`, or `1 TB`. The other
      prints `1020` in the lower unit. Each
      expectation includes the `Speed: ` or `(` prefix. At least one probe is
      on the progress line, such as 1023 of 1023.9 bytes printing
      `(1020 B / 1 KB)`. The expectations that the M030 test already holds
      pass unchanged.
- [x] AC2: The NEWS.md bullet that describes the unit rule for a download
      status states the rule of AC1, with 1023.9 bytes printing `1 KB` as an
      example. Its phrase "and B for a value below 1" is replaced by the AC1
      fallback: B when no unit gives a rounded value of 1 or more.
- [x] AC3: `devtools::test()` and `devtools::check()` are clean (0 errors,
      0 warnings).

## Coverage
<!-- owner: plan · create/amend-via-gate; each acceptance criterion → the
     task(s) satisfying it, by positional number (AC/Task counted
     top-to-bottom). Review reads to fence evidence — tracking-rules "AC fencing". -->

- AC1 → T1, T2
- AC2 → T3
- AC3 → T4

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive
     change is amend-via-gate. Every item opens with its positional label —
     `Tn:` — the item's position counted top-to-bottom, the number Coverage
     cites; an insertion, removal, or reorder renumbers the labels and the
     Coverage lines together. -->

- [x] T1: In `tests/testthat/test-load-download-shape.R` near line 423, add
      eight threshold probes as speeds: 1023.9 and 1023 times 1024 to the
      power 0 through 3. Add one progress-line probe. Run the tests and
      see the four round-up probes and the progress probe go red. The planned
      rule moves up at 1023.488 times the lower unit, so both probes sit
      clear of the cut-over.
- [x] T2: Change `format_bytes()` at `R/download.R:348-358` to pick the unit
      from the rounded value. Rewrite its roxygen comment at
      `R/download.R:338-342` to state the same rule. Run `devtools::test()`.
- [x] T3: Amend the M030 unit bullet in NEWS.md (line 8) per AC2.
- [x] T4: Run `devtools::test()` and `devtools::check()` (the check needs
      the LM Studio token and a running server, see LESSONS M009).

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates.
     EXEMPT from the 150-line cap (D-046): history under D-045, never edited,
     so the cap must never demand a trim here. Wrapped entries get a WARN.
     The rejected-alternative record (/milestone-plan step 4) takes this form:
     `- YYYY-MM-DD: plan gate chose <approach> over <alternative> because
     <reason>; falsified by <evidence class>.` — one per approach choice the
     gate actually weighed, none where it weighed none, and it is the record
     `/milestone-review`'s thrash trigger (b) reads. It lives here rather than
     below so an instantiated file inherits no placeholder to delete. -->

- 2026-09-27: created by /milestone-plan from the M030 review D4 candidate row.
- 2026-09-27: criteria audit ran in full mode (user-facing tier) and found nothing blocking. The gate fixed two points. AC1 gains a progress-line probe and the prefix rule for matches. AC2 names the old fallback phrase that must change.
- 2026-09-27: plan gate chose "largest unit whose rounded value is 1 or more" over "move up once the rounded value reaches 1000". The first keeps the value at 1 or more, and it prints 999.6 bytes as `1000 B`, not `0.976 KB`. A user report that a four-digit figure such as `1020 B` reads as wrong falsifies the choice.
- 2026-09-27: plan gate chose to amend the unreleased M030 NEWS bullet over a new bullet, because no release shipped the old rule. A release that ships the M030 rule before this merges falsifies the choice.
- 2026-09-27: T1 added eight threshold probes and one progress probe. The four round-up probes and the progress probe went red with `1020 B/s`, `1020 KB/s`, `1020 MB/s`, `1020 GB/s`, and `(1020 B / 1020 B)`.
- 2026-09-27: T2 changed `format_bytes()` to start at TB and step down while the rounded value is below 1, and rewrote its comment. `devtools::test()` passed 9408 with 0 failures.
- 2026-09-27: T3 amended the M030 NEWS bullet to state the rounded-value rule, with 1023.9 bytes as `1 KB` and 1023 bytes as `1020 B`.
- 2026-09-27: T4 ran `devtools::test()` (9408 passed, 0 failed) and `devtools::check()` (0 errors, 0 warnings, 0 notes).
- 2026-09-27: claim audit: 19 claims read, 0 corrected — R/download.R, NEWS.md, tests/testthat/test-load-download-shape.R
- 2026-09-27: review recorded evidence for AC1 to AC3 and passed the consistency gate. Three reviewers reported four minor findings and no defect.

## Decisions
<!-- owner: implement / review · append-only; milestone-local; promote
     cross-cutting ones to cairn/DECISIONS.md.
     EXEMPT from the 150-line cap (D-074) because D-045 makes it history like the work log — dated dispositions, never edited — so the cap must never demand a trim here either.
     Entries carry their rationale; the counterweight `decisions format`
     advisory watches for pasted output, not for entry length (D-075). -->

## Review
<!-- owner: review · exclusive; evidence per criterion, consistency-gate
     results, review findings + triage. EXEMPT from the 150-line cap (M55),
     as are the work log (D-046) and the decisions section (D-074); evidence
     never scrambles plan-owned content. -->

Review run 2026-09-27 on branch head d5af197. The branch already holds origin/main.

- AC1: a new test in `tests/testthat/test-load-download-shape.R` pins two speeds below each of the four thresholds. Each expectation has the `Speed: ` prefix. The test also pins `(1020 B / 1 KB)` for 1023 of 1023.9 bytes. A direct probe printed `1 KB`, `1 MB`, `1 GB`, and `1 TB` for the four round-up values. It printed `1020 B`, `1020 KB`, `1020 MB`, and `1020 GB` for the other four values. It printed `0.4 B` for 0.4 bytes. The `format_bytes()` from main printed `1020` in the lower unit for all four round-up values, so the test can fail. The diff only adds lines to the test file, and the M030 expectations pass in the full run.
- AC2: NEWS.md line 8 now states the rule. The unit is the largest in which the rounded value is 1 or more. When no unit gives such a value, the unit is B. It gives 1023.9 bytes as `1 KB` and 1023 bytes as `1020 B`. A search of NEWS.md finds no "and B for a value below 1" and no milestone number.
- AC3: `devtools::test()` passed 9408 with 0 failures, 0 errors, and 0 skips. `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. The LM Studio server was running and the token was set.

Consistency gate: `cairn_validate.py` passed all checks. `devtools::document()` left no diff. `pkgdown::check_pkgdown()` found no problems. The branch does not touch README.Rmd or README.md, and it adds no top-level file. NEWS.md holds the entry for AC2.

Independent review: three fresh reviewers ran. The prior-review reviewer found no finding, and the repo has no GitHub review comments. The blame-history reviewer found no finding. The diff-bug reviewer found no defect and gave four minor findings, most severe first:

- D1: a value of 100,000 TB or more can print in scientific form, such as `1e+05 TB`. Proposed triage: reject. The `format_bytes()` from main prints the same `1e+05 TB`, so the branch did not add it, and the Scope leaves `scipen` out.
- D2: `format_bytes()` aborts on `NA` and `NaN`, and prints `-5 B` and `Inf TB`. Proposed triage: reject. The only caller passes a finite value of 0 or more, as the `@param` states, and the old code did the same.
- D3: the NEWS phrase "three significant digits" sits next to the four-digit figures `1000 B` and `1020 B`. Proposed triage: reject. The figure `1020` has three significant digits, and the bullet gives it as an example.
- D4: the four `1020` probes pass on the old code too. Proposed triage: reject. The four round-up probes and the progress probe fail on the old code, and the `1020` probes catch a rule that moves up at 1000.
