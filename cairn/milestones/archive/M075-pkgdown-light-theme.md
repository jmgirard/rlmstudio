# M075: The website has a light purple theme, a dark mode switch, and articles in reading order

**Status:** done (2026-10-01, PR #75 https://github.com/jmgirard/rlmstudio/pull/75).

**Goal:** The pkgdown site keeps its purple on a light navbar with a mode
switch, lists its articles in reading order, and stops publishing `CLAUDE.md`.

**Outcome:** `_pkgdown.yml` uses the zephyr preset with `primary: "#4139C3"`
and `light-switch: true`. The light switch is what keeps the navbar light.
`link-color`, `navbar: bg`, and `pkgdown/extra.css` are gone. Links are
`#4139C3` in light mode and `#8d88db` in dark mode (4.90:1). One `articles:`
section with `navbar: ~` orders the menu. The pkgdown workflow deletes
`CLAUDE.md` before the build and deploys with `clean: true`. T5: after
the deploy from `7b95435`, `gh-pages` lists 281 files, with `.nojekyll` and
no `CLAUDE.*`, `extra.css`, or `dev/` file.

**Decisions:** none cross-cutting. The plan gate chose zephyr over sandstone
with a light navbar, and one flat articles section over headed groups.

**Review:** All 6 criteria passed on a fresh build and on the PR #75
workflow run. Three lenses found no blocking defect. The gate fixed three:
a comment on the light switch, a workflow comment that points to
`pkgdown:::package_mds()`, and the title `All articles`. Seven
findings were rejected or noted. The first CI watch hit its time limit, and
a resume ticked AC5 and AC6 from the PR run. No lessons added.
