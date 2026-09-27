# M030: A download status prints progress only from 0 to 100 and shows sizes and speed in a unit that fits

**Status:** done (2026-09-27, PR #30 https://github.com/jmgirard/rlmstudio/pull/30)

**Goal:** `print()` on a download status shows a percentage from 0 to 100
only, and it shows sizes and speed in a unit that fits the value.

**Outcome:** If `downloaded_bytes` is below 0 or above `total_size_bytes`,
`print.lms_download_status()` leaves out the Progress line. The percentage is
`floor(downloaded / total * 1000) / 10`, so a download short of its total does
not print `100%`. The `is.finite(pct)` guard is gone, because the new bounds
keep the ratio from 0 to 1. A new internal `format_bytes()` prints sizes and
speed in B, KB, MB, GB, or TB (base 1024) with `format(signif(x, 3), digits =
3)`. The README and getting-started examples now show `(737 MB / 737 MB)`.
One NEWS entry. This closed the M029 print-gap candidate row.

**Decisions:** none.

**Review:** One pass, three-lens fan-out, user-facing tier. All four criteria
passed, and `devtools::check()` was clean. The claim audit before review fixed
a subnormal number that `signif()` printed at full length. The blame-history
and prior-review lenses found nothing. The diff-bug lens found 6. The gate
fixed D1 (stale examples), D3 (no TB test), and D6 (stale test comment).
D4 (999.6 prints `1000 B`) became a candidate row. D2 (`scipen` and `OutDec`
change the output) and D5 (`1e-09 B/s` form) were rejected.
