# M032: A download status picks the unit of a size or speed after rounding

**Status:** done (2026-09-27, PR #32 https://github.com/jmgirard/rlmstudio/pull/32)

**Goal:** `print()` on a download status shows a size or speed of 1023.9
bytes as `1 KB` and not as `1020 B`, because the unit is picked after the
value is rounded.

**Outcome:** `format_bytes()` now starts at TB and steps down while the value,
rounded to three significant digits, is below 1. B is the fallback. The
cut-over is 1023.488 times the lower unit at each threshold. A value from
999.5 to 1023.4 of a unit still prints a four-digit figure such as `1020 B`.
Its roxygen comment and the unreleased M030 NEWS bullet state the rule. A new
test pins two speeds below each of the four thresholds and one progress line.

**Decisions:** none.

**Review:** One pass, three-lens fan-out, user-facing tier. All three
criteria passed, and `devtools::check()` was clean. Two lenses found
nothing. The diff-bug lens found 4 minor items, and the gate rejected all 4.
The `1e+05 TB` form and the `NA` abort also occur on main. The NEWS
wording is accurate, and the `1020` probes catch a rule that moves up at
1000.
