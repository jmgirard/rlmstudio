<!-- Section ownership + write-modes: see tracking-rules.md "Milestone-file
     section ownership". A phase skill never rewrites another phase's section.
     Per-section owners are tagged below. The one size check that can fail is
     cairn_validate's <150 over the plan-owned body. -->
# M030: A download status prints progress only from 0 to 100 and shows sizes and speed in a unit that fits

- **Status:** review
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — changes the printed output of an exported S3 method
- **Branch/PR:** m030-download-print-units

## Goal

`print()` on a download status shows a percentage from 0 to 100 only, and it
shows sizes and speed in a unit that fits the value.

## Scope

**In:** `print.lms_download_status()` in `R/download.R`. If
`downloaded_bytes` is below 0 or above `total_size_bytes`, the Progress line is
left out. Each size and the speed print in B, KB, MB, GB, or TB (base 1024).
The percentage rounds down to one decimal. Tests go in
`tests/testthat/test-load-download-shape.R`, with one NEWS entry. The milestone
absorbs the candidate row on the two display gaps from the M029 review (D2 and
D4).

**Out:** shape rules on the status reply. A negative or over-total size stays
a valid reply, because a display fault must not abort a status query (M029
plan gate). The print method of `lms_chat_result` stays as it is.

## Acceptance criteria

- [ ] AC1: If `downloaded_bytes` is below 0 or above `total_size_bytes`,
      `print()` on a download status leaves out the Progress line. If
      `downloaded_bytes` is 0 or equal to the total, it shows the line. A test
      covers these four cases.
- [ ] AC2: `print()` shows each size and the speed in B, KB, MB, GB, or TB
      (base 1024). The unit is the largest in which the value is 1 or more, and
      B below 1024. The value is `signif(x, 3)` with trailing zeros dropped. A
      test pins the Speed text for speeds `1e-9`, `1023`, `1024`, `1536`,
      `1234567`, and `5 * 1024^2`. The expected texts are `1e-09 B/s`,
      `1020 B/s`, `1 KB/s`, `1.5 KB/s`, `1.18 MB/s`, and `5 MB/s`. It pins the
      Progress text for 50 of 100 bytes as `50% (50 B / 100 B)`.
- [ ] AC3: The percentage rounds down to one decimal. A test pins 9996 of 10000
      bytes as `99.9%`, 29 of 100 as `29%`, 1 of 3 as `33.3%`, and 10000 of
      10000 as `100%`.
- [ ] AC4: The print of the LM Studio docs example reply stays
      `Progress: 100% (2.12 GB / 2.12 GB)`, and `devtools::check()` returns 0
      errors, 0 warnings, and 0 notes.

## Coverage

- AC1 → T1, T2
- AC2 → T1, T3
- AC3 → T1, T4
- AC4 → T3, T5

## Tasks

- [x] T1: Write the failing tests first in
      `tests/testthat/test-load-download-shape.R`, next to the M029 print test
      (about line 370): the four AC1 cases, the AC2 speed and size strings, and
      the AC3 percentages. Pin each line with `fixed = TRUE` matches on the
      captured messages.
- [x] T2: In `print.lms_download_status()` (`R/download.R` about line 305), add
      `downloaded >= 0` and `downloaded <= total` to the Progress condition.
      The existing `"total 1e-300"` case now also fails the new rule. Update
      its comment, which says only that the percentage divides to Inf.
- [x] T3: Add an internal helper that formats a byte count in the AC2 unit, and
      use it for both sizes and for the speed with a `/s` suffix. Extend the
      docs example test to pin the whole Progress line of AC4.
- [x] T4: Compute the percentage as `floor(downloaded / total * 1000) / 10`.
- [x] T5: Add a NEWS entry that states the AC1 to AC3 changes with the before
      and after text. Run `devtools::document()`, `devtools::test()`, and
      `devtools::check()`.

## Work log

- 2026-09-27: created by /milestone-plan. The full criteria audit by a fresh reader returned six findings. The plan fixed all six before the gate: AC2 wording and cases, TB added, AC3 cases, the stale 1e-300 test comment, and AC4 narrowed to the docs example output.
- 2026-09-27: plan gate chose to leave out the Progress line for a negative or over-total `downloaded_bytes`. It rejected a clamp to 0-100 and sizes without a percentage. M029 already leaves out the line for a total of 0 or a size that is not finite. A live reply with a downloaded size above the total in a normal download falsifies the choice.
- 2026-09-27: plan gate chose a unit per value (B to TB). It rejected leaving out a speed that rounds to 0, and it rejected a `< 0.01` floor. One helper fixes both the tiny speed and the 0 GB size. A user who parses the printed GB or MB/s text falsifies the choice.
- 2026-09-27: implement started on branch m030-download-print-units. The question gate was skipped because the plan left no choice open.
- 2026-09-27: T1-T5 done. The new tests failed first with `0 GB`, `0 MB/s`, and `100%` for 9996 of 10000. With each new bound removed in turn, a test went red. The `is.finite(pct)` guard is gone, because a downloaded size from 0 to the total keeps the ratio from 0 to 1. `devtools::test()` passed 9302 tests, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes.
- 2026-09-27: claim audit: 23 claims read, 3 corrected — R/download.R, NEWS.md, tests/testthat/test-load-download-shape.R
- 2026-09-27: the claim audit found that `signif()` leaves a subnormal number at full length. `format_bytes()` now wraps it in `format(digits = 3)`, and a test pins `5e-324` as `4.94e-324 B/s`. The NEWS entry now names B for a value below 1. The reader re-read the three claims once, and all three hold. `devtools::test()` passed 9303 tests, and `devtools::check()` gave 0 errors, 0 warnings, and 0 notes. Status set to review.

## Decisions

## Review
