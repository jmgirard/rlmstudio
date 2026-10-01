# M075: The website has a light purple theme, a dark mode switch, and articles in reading order

- **Status:** in-progress
- **Priority:** normal
- **Depends on:** —
- **Driving RR:** —
- **Principles touched:** —
- **Resolves:** —
- **Surface tier:** user-facing — the public pkgdown website
- **Branch/PR:** m075-pkgdown-light-theme

## Goal

The pkgdown site keeps its purple on a light navbar with a mode switch, lists its articles in reading order, and stops publishing `CLAUDE.md`.

## Scope

**In:** `pkgdown/_pkgdown.yml` moves from the `sandstone` theme with
`navbar: bg: primary` to the `zephyr` preset with `primary: "#4139C3"`.
circumplex moved to the same preset in its M138. The file also sets
`light-switch: true`. The `link-color` and `bootswatch` keys go, so dark
mode makes a lighter link color from `primary`. `pkgdown/extra.css` is
deleted. It only forced a white search box on the purple navbar. A new
`articles:` index has one section with `navbar: ~`. Its order is
`getting-started`, `chat-options`, `text-analysis`, `headless-config`.
`.github/workflows/pkgdown.yaml` deletes `CLAUDE.md` before the build.
pkgdown renders every root `.md` file and does not read `.Rbuildignore`.
The deploy step changes to `clean: true`. The first deploy then removes
`CLAUDE.html`, `CLAUDE.md`, `extra.css`, and the old `dev/` site from
`gh-pages`. Nothing links to `dev/`, because the site is in release mode.

**Out:** The reference index order and the navbar labels stay as they are.
Nobody asked to change them. The plan gate declined a `Get started` navbar
link. The four reader gaps in `vignette("getting-started")` stay in their
ROADMAP candidate row. The same `CLAUDE.md` page on the circumplex site
belongs to the circumplex tracking. No NEWS entry, because no package code
changes.

## Acceptance criteria

- [ ] AC1: In a site built by `pkgdown::build_site()` from the milestone branch into a fresh folder, every `.html` page that a recursive listing of that folder finds holding a `<nav>` element whose class list contains `navbar` gives that element's start tag no `bg-` class and no `data-bs-theme` attribute. This marks a light navbar and does not test how the navbar renders.
- [ ] AC2: On the built `index.html`, opened in the browser pane, `--bs-link-color` on the root element equals `#4139C3`, compared trimmed and case-insensitively, with `data-bs-theme="light"` set on the root element. With `data-bs-theme="dark"` set there, it computes to a color whose contrast ratio against the computed `--bs-body-bg` is at least 4.5:1 (WCAG 2.1, success criterion 1.4.3). The built `index.html` holds pkgdown's mode switch (`#dropdown-lightswitch`) and its search box (`#search-input`).
- [ ] AC3: The Articles menu of the built `index.html` is a dropdown whose links, read in `href` order, are `getting-started`, `chat-options`, `text-analysis`, `headless-config`, under no heading. `articles/index.html` lists them in the same order. The set of linked names equals the file names, without `.Rmd`, that `list.files("vignettes", "\\.Rmd$")` returns.
- [ ] AC4: `pkgdown/extra.css` does not exist. In the fresh build folder, no file is named `extra.css`, and no `.html` page holds a `<link>` whose `href` ends in `extra.css`.
- [ ] AC5: `pkgdown::check_pkgdown()` prints "No problems found" and raises no error, and the `pkgdown.yaml` workflow passes on the milestone's pull request.
- [ ] AC6: In `.github/workflows/pkgdown.yaml`, a step before the site build deletes `CLAUDE.md`, and the deploy step sets `clean: true`. On the milestone's pull request, the workflow log shows that the delete step ran. A `pkgdown::build_site_github_pages()` run into a fresh folder, from a copy of the branch without `CLAUDE.md`, writes no `CLAUDE.html` and no `CLAUDE.md`.

## Coverage

- AC1 → T1, T4
- AC2 → T1, T4
- AC3 → T2, T4
- AC4 → T1, T4
- AC5 → T4
- AC6 → T3, T4

## Tasks

- [x] T1: In `pkgdown/_pkgdown.yml`, set the `template:` block to `bootstrap: 5`, `bslib: preset: zephyr`, `primary: "#4139C3"`, and `light-switch: true`. Remove `navbar: bg: primary`. Delete `pkgdown/extra.css`. If `bootswatch` stays beside `preset`, pkgdown warns "Multiple Bootstrap preset themes".
- [x] T2: Add an `articles:` index to `pkgdown/_pkgdown.yml`. It has one section with `navbar: ~` and the four vignettes in the AC3 order. A comment states the rule: with no `navbar` key, pkgdown makes the Articles menu a plain link.
- [ ] T3: In `.github/workflows/pkgdown.yaml`, add a step before the build that deletes `CLAUDE.md`. Its comment says that pkgdown renders every root `.md` file. Set `clean: true` on the deploy step.
- [ ] T4: Run `pkgdown::init_site()` before an article build, because an article build does not refresh `deps/` after a theme change (circumplex lesson, M156). Build the site into a fresh scratch folder and record the AC1 to AC4 evidence. Do the AC6 build from a copy without `CLAUDE.md`. Run `pkgdown::check_pkgdown()`.
- [ ] T5: After the merge, wait for the deploy run on the default branch. Then run `git ls-tree -r --name-only origin/gh-pages`. Make sure that it lists no `CLAUDE.html`, no `CLAUDE.md`, no `extra.css`, and nothing under `dev/`, and that `.nojekyll` is still there. Record the result in the work log.

## Work log

- 2026-10-01: created by /milestone-plan.
- 2026-10-01: plan gate chose the zephyr preset with `primary: "#4139C3"` over sandstone with a light navbar, from built previews of both. Falsified by a zephyr page that fails the AC2 contrast floor.
- 2026-10-01: plan gate chose one flat articles section over two headed groups and over a separate Get started link. Falsified by a new vignette that fits no single reading order.
- 2026-10-01: plan gate chose to fix the published `CLAUDE.md` here over a candidate row. Falsified by a `gh-pages` file that the build does not make and that must survive a deploy.
- 2026-10-01: plan criteria audit (full mode, fresh Opus reader) returned 5 findings on AC1 to AC5, all fixed before the gate. AC3 needs `navbar: ~`. AC1 reads the `<nav>` start tag only. AC2 sets the light theme itself. AC4 searches stylesheet links only. AC3 drops `.Rmd`. It also found the published `CLAUDE.html`.
- 2026-10-01: second audit pass (same reader, full mode) on AC6 and the revised AC1 to AC5 returned 2 findings, both fixed. AC6 named a post-merge effect, so it now names pre-merge evidence and the `gh-pages` listing moved to T5. AC2 compares the color trimmed.
- 2026-10-01: implement started on branch `m075-pkgdown-light-theme`. The question gate was skipped, because the plan left no choice open.
- 2026-10-01: T1 done. `_pkgdown.yml` uses the zephyr preset with `light-switch: true`, and `pkgdown/extra.css` is deleted. pkgdown 2.2.1, bslib 0.12.0.
- 2026-10-01: T2 done. The `articles:` index has one section with `navbar: ~`. The comment matches `pkgdown:::navbar_articles()` in 2.2.1, read this session.
