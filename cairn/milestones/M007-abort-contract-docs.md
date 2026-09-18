# M007: The abort contract reaches the help pages

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** GP3
- **Resolves:** —
- **Surface tier:** user-facing — the help pages are the package's documented error contract
- **Branch/PR:** `m007-abort-contract-docs`

## Goal

Every exported function that calls one of the package's two abort helpers documents the condition class it raises, and one topic page states the contract.

## Scope

**In:** A new doc-only topic, `rlmstudio-conditions`, states what
`rlmstudio_no_server` and `rlmstudio_api_error` mean, when each is raised, that
an `rlmstudio_api_error` condition carries a `status` field, and how to catch
each by class. Its two sections reach the ten exported functions that call
`stop_if_no_server()` or `rlm_abort_api()` through `@inheritSection`. The three
exported functions that reach an abort only through another function say so and
name the function. `NEWS.md` and the pkgdown reference index gain entries.

**Out:**
- A shipped guard that keeps a future raiser of either class documented → new
  candidate row. The promise here is deliberately bounded to what the two greps
  in AC2 and AC3 sweep.
- Bounding the length of a non-JSON failure body in the abort message →
  existing candidate row.
- Documenting the `...` escape hatch limit that D-003 records → not in scope.
- Any runtime behavior change. This milestone edits roxygen, `NEWS.md`, and
  `pkgdown/_pkgdown.yml` only.

## Acceptance criteria

- [ ] AC1: `man/rlmstudio-conditions.Rd` exists and is generated from a roxygen
      block in `R/conditions.R`. Its text states that `rlmstudio_no_server` is
      raised when the LM Studio server does not answer at `host`, states that
      `rlmstudio_api_error` is raised when a REST call returns a response the
      wrapper treats as a failure, states that an `rlmstudio_api_error`
      condition carries a `status` field holding the HTTP response status as an
      integer, and carries an `\examples{}` block whose `\dontrun{}` body calls
      `tryCatch()` with a handler named for each of the two classes.
- [ ] AC2: For each call site that
      `grep -rn "stop_if_no_server(" R/ | grep -v "^[^:]*:[0-9]\+:[[:space:]]*#"`
      prints (ten when this plan was written), the help page of the exported
      function the call site sits in contains a rendered `\section` that names
      `rlmstudio_no_server` and states that it is raised when the LM Studio
      server is not running.
- [ ] AC3: For each call site that
      `grep -rn "rlm_abort_api(" R/ | grep -v "^[^:]*:[0-9]\+:[[:space:]]*#"`
      prints (eight when this plan was written), the help page of the exported
      function the call site sits in contains a rendered `\section` that names
      `rlmstudio_api_error`, states that it is raised on a failed REST response,
      and states that the condition carries a `status` field holding the HTTP
      status as an integer.
- [ ] AC4: The help page of `lms_chat()` states that it can raise
      `rlmstudio_no_server` and `rlmstudio_api_error` through
      `lms_chat_openresponses()`, `lms_chat_openai()`, or `lms_chat_native()`.
      The help page of `lms_chat_batch()` states that it can raise
      `rlmstudio_api_error` through `lms_chat()`. The help page of
      `lms_unload_all()` states that it can raise `rlmstudio_api_error` through
      `list_models()` and `lms_unload()`.
- [ ] AC5: `Rscript -e 'devtools::document()'` leaves the working tree
      unchanged. `Rscript -e 'devtools::test()'` reports no failures.
      `Rscript -e 'pkgdown::check_pkgdown()'` reports no topic missing from the
      reference index. `Rscript -e 'devtools::check()'` reports 0 errors and 0
      warnings.
- [ ] AC6: `NEWS.md` carries an entry under the `# rlmstudio (development
      version)` heading that names `rlmstudio_no_server`, `rlmstudio_api_error`,
      the `status` field, and `rlmstudio-conditions`, and that contains no `M`
      followed by digits.

## Coverage

- AC1 → T1
- AC2 → T1, T2
- AC3 → T1, T2
- AC4 → T3
- AC5 → T4, T5
- AC6 → T6

## Tasks

- [x] T1: Write `R/conditions.R`: a doc-only roxygen block ending in `NULL`,
      with `@name rlmstudio-conditions`, `@title`, two `@section` blocks titled
      exactly `Server not running` and `API failure`, and an `@examples` block
      whose `\dontrun{}` body catches each class with `tryCatch()`. Do not add
      `@keywords internal`; T4 puts the topic in the pkgdown index instead. Run
      `devtools::document()`.
- [x] T2: Add the two `@inheritSection rlmstudio-conditions <title>` tags to the
      eleven exported functions named below. Ten of them hold the AC2 and AC3
      call sites. The eleventh, `lms_chat()` (`R/chat.R:26`), was added at the
      implement question gate, because it reaches both aborts through the
      function it routes to. The ten are: `list_models()`
      (`R/list.R:27`), `lms_load()` (`R/load.R:31`), `lms_unload()`
      (`R/unload.R:23`), `lms_unload_all()` (`R/unload.R:73`), `lms_download()`
      (`R/download.R:17`), `lms_download_status()` (`R/download.R:100`),
      `lms_chat_openresponses()` (`R/chat.R:102`), `lms_chat_openai()`
      (`R/chat.R:210`), `lms_chat_native()` (`R/chat.R:268`), `lms_chat_batch()`
      (`R/chat.R:327`). Each tag stays on one line: roxygen2 8.0.0 warns on a
      wrapped single-line tag, and the section title must match character for
      character. Re-document.
- [x] T3: Add the delegation sentence to `lms_chat()` (`R/chat.R:26`),
      `lms_chat_batch()` (`R/chat.R:327`), and `lms_unload_all()`
      (`R/unload.R:73`), each naming the function it calls. `lms_chat()` also
      needs the `rlmstudio_no_server` sentence, because it is the one affected
      export with no direct `stop_if_no_server()` call. Re-document.
- [x] T4: Add an `Error conditions` section to the `reference:` list in
      `pkgdown/_pkgdown.yml` holding `rlmstudio-conditions`. Run
      `pkgdown::check_pkgdown()`.
- [ ] T5: Run `devtools::document()`, `devtools::test()`, and
      `devtools::check()`. Fix what they report. Record each NOTE with a
      one-line reason for the review gate.
- [x] T6: Add the `NEWS.md` entry under the development version heading.
      Run before T5, so that `devtools::check()` runs over the finished tree.

## Work log

- 2026-09-18: created by /milestone-plan.
- 2026-09-18: criteria audit ran in full mode (surface tier user-facing), two rounds, a fresh-context reader each round; round one returned ten findings and no clean criterion, round two returned four more on the repaired wording, and all fourteen were fixed at the gate.
- 2026-09-18: round-one findings: AC4 named an unspecified grep and listed `lms_chat_batch()`, which reaches an abort at two hops and fell in no reading of the domain; AC2 and AC3 tested for a substring an `\alias` line satisfies; their greps matched roxygen lines, so the milestone's own prose would have created call sites that failed the criterion; the `tryCatch()` example had no stated home; "every NOTE justified" and "in user-facing terms" were unbounded judgments.
- 2026-09-18: round-two findings: AC2 and AC3 said "the function aborts", which an `@inheritSection`-produced generic section does not state; the filter `grep -v ":[0-9]*: *#"` both kept trailing comments and dropped any line holding `::` before a `#`; `devtools::check()` defaults to `--as-cran`, so the "no NOTE absent on `main`" clause rested on network-dependent NOTEs that vary run to run; "milestone number" was under-specified against NEWS.md's own release headings.
- 2026-09-18: round two confirmed `@inheritSection` from a doc-only `@name` block renders into the consumer's `.Rd` under the installed roxygen2 8.0.0, with the tag required to stay on one line and the section title to match character for character.
- 2026-09-18: plan gate chose one `@inheritSection` source topic over a paragraph copied into each affected roxygen block, because eleven copies drift independently and the hand-list becomes the sweep; falsified by a rendered `.Rd` showing the inherited section missing or stale relative to `R/conditions.R`.
- 2026-09-18: plan gate chose a promise bounded to the two named greps over a promise covering every path that can raise either class, because no stated procedure enumerates the wider domain and the M005 lesson says a guard that greps `R/` does not run under `R CMD check`; falsified by a raiser of either class that neither grep prints.
- 2026-09-18: plan gate chose a visible pkgdown `Error conditions` section over `@keywords internal`, because a user looking for how to catch an error reads the site; falsified by `pkgdown::check_pkgdown()` failing on the new topic.
- 2026-09-18: AC5 binds instrument properties and is a standing D-118 finding, kept because the milestone template mandates a verify-slot criterion for code milestones and the audit called it standard repo hygiene rather than a novel instrument; the NOTE-justification half moved out of the criterion into T5.
- 2026-09-18: implement question gate settled two items. The three exports that reach an abort only through another function carry the two shared sections as well as their own delegation sentence. The drafted section wording was accepted as drafted.
- 2026-09-18: minor amendment from that gate. T2's function list grows from ten to eleven, adding `lms_chat()`. No criterion changes. AC2 and AC3 still bind the ten call sites the greps name, and the eleventh page is additive.
- 2026-09-18: T1 done: `R/conditions.R` written and `man/rlmstudio-conditions.Rd` generated. `devtools::test()` reported 147 pass, 0 fail, 0 warn, 0 skip.
- 2026-09-18: minor amendment. T6 runs before T5, so that `devtools::check()` runs over the finished tree. No task text changes beyond the added ordering note.
- 2026-09-18: T6 done: one `NEWS.md` bullet added under the development version heading. A grep of that bullet found `rlmstudio_no_server`, `rlmstudio_api_error`, `status`, and `rlmstudio-conditions`. The same grep found no `M` followed by digits. A sweep of the other source files found no further exported function that reaches either abort. The bullet's "every exported function" clause therefore covers the eleven pages and no more.
- 2026-09-18: T4 done: `pkgdown/_pkgdown.yml` gained a reference section holding `rlmstudio-conditions`. The title reads `Error Conditions`, in the title case that the seven existing section titles use. `pkgdown::check_pkgdown()` reported no problems.
- 2026-09-18: T3 done: a `@details` paragraph added at `lms_chat()`, `lms_chat_batch()`, and `lms_unload_all()`, each naming the function it reaches the abort through. A read of the `lms_chat()` body found no `httr2` call, no `lms_client()` call, and no `stop_if_no_server()` call. That read is the source of the "runs no request of its own" sentence. `devtools::test()` reported 147 pass, 0 fail.
- 2026-09-18: T2 done: both `@inheritSection` tags added at eleven exports. A grep over the regenerated `man/` files found one `\section{Server not running}` and one `\section{API failure}` in each of the eleven. Each block names its own class. The API block names the integer status field. `devtools::test()` reported 147 pass, 0 fail.

## Decisions

## Review
