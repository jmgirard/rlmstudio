<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M085: The no-server hints name the port of the host that the call asked

- **Status:** in-progress   <!-- owner: transitioning skill · mirror-update; cairn/ROADMAP.md is the authority -->
- **Priority:** normal   <!-- owner: plan · create/amend-via-gate; high | normal | low -->
- **Depends on:** —   <!-- owner: plan · create/amend-via-gate; M<xx>, M<yy> or — -->
- **Driving RR:** —   <!-- owner: plan · create/amend-via-gate; RR<NN> whose Binding criteria bind this milestone's ACs (binding-criteria check), or — -->
- **Principles touched:** —   <!-- owner: plan · create/amend-via-gate; comma-separated IPn/GPn ids this milestone touches, or — -->
- **Resolves:** —   <!-- owner: plan · create/amend-via-gate; comma-separated GitHub issues the scope absorbs, each `#N closes` (the PR closes it at merge) or `#N partial` (the remainder gets a candidate row), or — ; skill conduct only — no validate check parses it -->
- **Surface tier:** user-facing — two error messages, a help section that 13 pages inherit, and an install message   <!-- owner: plan · create/amend-via-gate; user-facing | internal — <one-clause reason>; skill conduct only — no validate check parses it -->
- **Branch/PR:** m085-no-server-hint-port   <!-- owner: implement (branch) / review (PR URL) · create; a companion checkout the milestone also works in is one further entry per checkout, `companion: <abs-path> <branch>` (implement), its PR URL appended by review — /milestone-review merges companions first, in listed order -->

## Goal
<!-- owner: plan · create; a wrong goal returns to plan, never edited in place -->

A user who follows a no-server hint starts the server on the port that the failed call asked.

## Scope
<!-- owner: plan · create/amend-via-gate -->

**In:** Absorbs the candidate row "server-start hints" in full. The no-server abort of `stop_if_no_server()` (`R/serve.R:743-751`) and of `reply_model_serves()` (`R/chat.R:991-1001`) build their hint from `host`. For a hostname of `localhost` in any letter case or `127.0.0.1`, the hint names `lms_server_start(port = <p>)`, with `<p>` the port that `is_server_running()` probes for that `host`. For any other `host`, the hint says to start the server on the machine that `host` names, and names no `lms_server_start()` call. One helper parses `host` for both the probe and the hint. The "Server not running" help section (`R/conditions.R:34-36`) says the same. The headless install message (`R/setup.R:235`) names `lms_server_start(port = 1234)`. One NEWS bullet.

**Out:**
- The quiet bypass of the browser install warning and the other direct alerts: M086.
- A `port` default of 1234 in `lms_server_start()`: the user kept the default at the M084 plan gate, 2026-10-18.
- The README, vignette, and help-example starts: M084 shipped `port = 1234` there.
- `::1` and other loopback names: they get the remote hint, as the user chose "localhost or 127.0.0.1" at the plan gate.

## Acceptance criteria
<!-- owner: plan · create/amend-via-gate; review reads, never reinterprets. -->

- [ ] AC1: A table test in `tests/testthat/test-serve.R` calls `stop_if_no_server()` with the server probe failing, once for each `host` in this list: the default `host`, `http://localhost:8080`, `localhost:5000`, `http://LocalHost:1234`, `http://127.0.0.1:4321`, `http://localhost`, `http://192.168.1.5:1234`, and one `host` for which `httr2::url_parse()` errors. For each row it asserts the class `rlmstudio_no_server`. For the first six rows it asserts that the message holds `lms_server_start(port = <p>)`, with `<p>` 1234, 8080, 5000, 1234, 4321, and 1234. For the last two rows it asserts that the message holds the `host` text and no `lms_server_start(`.
- [ ] AC2: A test calls the model-list lookup of a chat route with the server probe failing, for `host` `http://localhost:8080` and for `http://192.168.1.5:1234`. It asserts the class `rlmstudio_no_server`, the lookup label "because the model-list lookup failed", `lms_server_start(port = 8080)` in the first message, and no `lms_server_start(` in the second.
- [ ] AC3: The "Server not running" section of `man/rlmstudio-conditions.Rd` says to start the server with `lms_server_start()` and the port of `host` when the hostname of `host` is `localhost` in any letter case or `127.0.0.1`, 1234 for the default `host`, and to start it on the machine that `host` names otherwise, as a read of the section shows.
- [ ] AC4: `install_lmstudio(method = "headless")` reports `lms_server_start(port = 1234)` in its last message, as an assertion in the successful headless-install test of `tests/testthat/test-vignette-claims.R` checks.
- [ ] AC5: The development section of `NEWS.md` has one bullet that says that the no-server errors and the headless install message now name the port to start the server on.
- [ ] AC6: `devtools::test()` and `devtools::check()` report no failures, errors, or warnings.

## Coverage
<!-- owner: plan · create/amend-via-gate -->

- AC1 → T1
- AC2 → T2
- AC3 → T3
- AC4 → T4
- AC5 → T5
- AC6 → T6

## Tasks
<!-- owner: plan (create) / implement (check-off, minor edits); substantive change is amend-via-gate. -->

- [x] T1: Test first in `tests/testthat/test-serve.R`: the AC1 table, with `is_server_running()` mocked to `FALSE`, red against `R/serve.R:746`. Find an unparseable `host` with no spaces by a run of `httr2::url_parse()`, not from memory, because cli wraps a message at spaces. Move the host parse of `is_server_running()` (`R/serve.R:705-720`) into one helper that returns the hostname and port, and use it in the probe and in a new hint helper. Plant a hint that names 1234 for every host and see the 8080 row go red.
- [x] T2: Test first beside the lookup tests of `tests/testthat/test-model-check.R:465`: the AC2 cases, red against `R/chat.R:997`. Then build that hint with the T1 helper.
- [x] T3: Rewrite `R/conditions.R:34-36` to match the T1 hint. Run `devtools::document()` and read the section in `man/rlmstudio-conditions.Rd`.
- [x] T4: Test first: add the AC4 assertion to the successful headless-install test at `tests/testthat/test-vignette-claims.R:514` and see it red. Then edit `R/setup.R:235`.
- [ ] T5: One NEWS bullet in the development section, written against the T1 to T4 output.
- [ ] T6: `devtools::test()` and `devtools::check()` clean.

## Work log
<!-- owner: any skill · append-only; one line per entry; absolute dates. -->

- 2026-10-18: created by /milestone-plan.
- 2026-10-18: tier check: not run — work named at the question set.
- 2026-10-18: question set: which work — the "server-start hints", "install message quiet", and "Slow tests on CRAN" candidate rows, planned as M085, M086, and M087.
- 2026-10-18: question set: the hint for a host that is not this machine — a generic hint with no `lms_server_start()` call; localhost and 127.0.0.1 get the port hint.
- 2026-10-18: plan gate chose a port hint for localhost and 127.0.0.1 alone over a port hint for every host because `lms_server_start()` starts a server on this machine only; falsified by a user on a remote host who reads the generic hint and cannot start the server.
- 2026-10-18: plan chose one shared host parse over a second parse in the hint helper because two parses can disagree on the port; falsified by a host form where the probe and the hint must read different ports.
- 2026-10-18: collision check: absorbs the "server-start hints" row in full; M084 (done) shipped the examples and the no-port success message; no D-entry bears on a hint or a port; inbox has 0 open issues and 0 open PRs.
- 2026-10-18: lessons surfaced: M003/M013 (mock the delegate, then delete the call site to see the test go red), M026 (assert the fault text, plant a wrong message), M012/M018 (splice `host` into the cli string as a value, not as text, so its braces stay inert).
- 2026-10-18: criteria audit (full mode, fresh Opus reader), 1 finding, taken: AC3 named "this machine", which also covers `::1`; it now names `localhost` and `127.0.0.1`. The reader's tip to pick an unparseable host with no spaces went into T1.
- 2026-10-18: changelog: one new NEWS bullet in the development section.
- 2026-10-18: ROADMAP line cap: merged the two `lms_embed()` rows, the two `list_instances()` rows, and the RoPE row into the `ttl` row, to add the M085 to M087 rows and the "load echo alert" row.
- 2026-10-18: implement started on branch m085-no-server-hint-port; tree clean at the cut.
- 2026-10-18: T1 done: `host_address()` and `no_server_hint()` in `R/serve.R`; the abort now has a main line and an "i" hint line. Unparseable host chosen by a run of `httr2::url_parse()`: `http://localhost:abc` (port not a number). The table went red on all rows first; a planted fixed-1234 `host_address()` turned the 8080 check red; `devtools::test()` 0 failed, 0 errors.
- 2026-10-18: T2 done: `reply_model_serves()` builds its hint with `no_server_hint()`; the new lookup test in `test-model-check.R` went red on both routes and both hosts first, then green; `devtools::test()` 0 failed, 0 errors.
- 2026-10-18: T3 done: the "Server not running" section names `localhost`, `127.0.0.1`, and `lms_server_start(port = 1234)` for the default host; `devtools::document()` rewrote `man/rlmstudio-conditions.Rd` and the 13 pages that inherit it; `devtools::test()` 0 failed, 0 errors.
- 2026-10-18: T4 done: the headless install message names `lms_server_start(port = 1234)`; the new assertion reads the text after the success line, and went red on the old message first; `devtools::test()` 0 failed, 0 errors.
