# M075: The website has a light purple theme, a dark mode switch, and articles in reading order

- **Status:** review
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

- [x] AC1: In a site built by `pkgdown::build_site()` from the milestone branch into a fresh folder, every `.html` page that a recursive listing of that folder finds holding a `<nav>` element whose class list contains `navbar` gives that element's start tag no `bg-` class and no `data-bs-theme` attribute. This marks a light navbar and does not test how the navbar renders.
- [x] AC2: On the built `index.html`, opened in the browser pane, `--bs-link-color` on the root element equals `#4139C3`, compared trimmed and case-insensitively, with `data-bs-theme="light"` set on the root element. With `data-bs-theme="dark"` set there, it computes to a color whose contrast ratio against the computed `--bs-body-bg` is at least 4.5:1 (WCAG 2.1, success criterion 1.4.3). The built `index.html` holds pkgdown's mode switch (`#dropdown-lightswitch`) and its search box (`#search-input`).
- [x] AC3: The Articles menu of the built `index.html` is a dropdown whose links, read in `href` order, are `getting-started`, `chat-options`, `text-analysis`, `headless-config`, under no heading. `articles/index.html` lists them in the same order. The set of linked names equals the file names, without `.Rmd`, that `list.files("vignettes", "\\.Rmd$")` returns.
- [x] AC4: `pkgdown/extra.css` does not exist. In the fresh build folder, no file is named `extra.css`, and no `.html` page holds a `<link>` whose `href` ends in `extra.css`.
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
- [x] T3: In `.github/workflows/pkgdown.yaml`, add a step before the build that deletes `CLAUDE.md`. Its comment says that pkgdown renders every root `.md` file. Set `clean: true` on the deploy step.
- [x] T4: Run `pkgdown::init_site()` before an article build, because an article build does not refresh `deps/` after a theme change (circumplex lesson, M156). Build the site into a fresh scratch folder and record the AC1 to AC4 evidence. Do the AC6 build from a copy without `CLAUDE.md`. Run `pkgdown::check_pkgdown()`.
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
- 2026-10-01: T3 done. The workflow removes `CLAUDE.md` before the build and deploys with `clean: true`. The comment matches `pkgdown:::package_mds()` in 2.2.1, read this session.
- 2026-10-01: T4 done. `init_site()` then `build_site()` into a fresh scratch folder, with no preset warning. AC1: 0 of 46 navbar tags carry `bg-` or `data-bs-theme`, and the published `gh-pages` site flags 46 of 46. AC2: light link `#4139C3`, dark link `#8d88db` on `#212529` is 4.90:1. AC3: menu and `articles/index.html` both read getting-started, chat-options, text-analysis, headless-config, with no heading. AC4: no `extra.css` file or link in 147 link tags, and `gh-pages` has 46 such links. AC6: the build from a copy without `CLAUDE.md` writes no `CLAUDE*` file, and the build with it writes `CLAUDE.html`. `check_pkgdown()` prints "No problems found". `devtools::test()`: 0 failed, 0 errors, 3 skipped.
- 2026-10-01: T5 runs after the merge, at `/milestone-review`. AC5 and AC6 also need the workflow run on the pull request, which review opens.
- 2026-10-01: claim audit: 5 claims read, 2 corrected — .github/workflows/pkgdown.yaml, pkgdown/_pkgdown.yml
- 2026-10-01: implement complete, status set to review. T5 stays open until after the merge, as the plan states.
- 2026-10-01: review started. No PR existed for the branch, and `origin/main` had not moved since the branch was cut.

## Review

Fresh build for AC1 to AC4: `pkgdown::init_site()` then `pkgdown::build_site()` from the branch head into an empty scratch folder, with pkgdown 2.2.1. The build exited 0. Its only warnings were pandoc's `--mathml` deprecation notices.

- AC1: A recursive walk of the build folder found 55 `.html` pages and 46 `<nav>` start tags whose class list holds `navbar`. None carries a `bg-` class or `data-bs-theme`. Control: `index.html` on `origin/gh-pages` has `bg-primary` and `data-bs-theme="dark"` on the same tag, so the scan can fail.
- AC2: The built `index.html` was served on localhost and opened in the browser pane. With `data-bs-theme="light"` on the root, `--bs-link-color` read `#4139C3`. With `data-bs-theme="dark"`, it read `#8d88db` against a `--bs-body-bg` of `#212529`, a contrast ratio of 4.90:1 by the WCAG 2.1 formula. `#dropdown-lightswitch` and `#search-input` are both on the page.
- AC3: In the built `index.html`, the Articles item is a `dropdown-toggle` menu. Its links in document order are getting-started, chat-options, text-analysis, headless-config, with no `dropdown-header`. `articles/index.html` lists the same four in the same order. `list.files("vignettes", "\\.Rmd$")` returns the same four names.
- AC4: `pkgdown/extra.css` does not exist. The walk of the build folder found no file named `extra.css`. None of the 147 `<link>` tags has an `href` that ends in `extra.css`. Control: `index.html` on `origin/gh-pages` holds such a link.
- AC5 (local half): `pkgdown::check_pkgdown()` printed "No problems found" and raised no error. The workflow half needs the `pkgdown.yaml` run on the pull request, which step 8 opens after the merge approval. The box stays open until that run passes.
- AC6 (local half): In `.github/workflows/pkgdown.yaml`, the step "Remove CLAUDE.md before the build" (`rm -f CLAUDE.md`) comes before "Build site", and the deploy step sets `clean: true`. A `git archive` copy of the branch head, with `CLAUDE.md` removed, ran `pkgdown::build_site_github_pages()` into an empty folder. It wrote 54 `.html` pages, `.nojekyll`, and no `CLAUDE*` file. Control: the AC1 build, with `CLAUDE.md` present, wrote `CLAUDE.html` and `CLAUDE.md`. The log half needs the workflow run on the pull request. The box stays open until that log shows the delete step ran.

Consistency gate: `cairn_validate.py` exited 0 with every line PASS or OK. `devtools::document()` left no diff. `devtools::check()` gave 0 errors, 0 warnings, 0 notes. `devtools::test()` gave 0 failures, 3 skips, because LM Studio was not running. `pkgdown::check_pkgdown()` passed (AC5). README.Rmd and README.md did not change. No NEWS entry, because the plan scope excludes one: no package code changed. No new top-level files and no principle changes.

Independent review (three fresh lenses, user-facing tier):

- Prior-review lens (Sonnet): no prior-review evidence on the touched files. The archive holds no review finding on the site configuration, and the repo has no PR review comments.
- Blame-history lens (Sonnet), 5 findings, all ranked low:
  - B1 `clean: true` deletes anything on `gh-pages` that the build does not make, such as a future `CNAME` or hand-edited page. `clean: false` came from the r-lib template in `6d21753` with no stated reason. `origin/gh-pages` holds no `CNAME` today.
  - B2 The `rm -f CLAUDE.md` step covers that one file. A new root `.md` file publishes the same way. `CLAUDE.md` is the only such file today.
  - B3 Deleting `extra.css` drops forced search-box colors, and AC2 tests only that `#search-input` exists. Measured in the browser pane on the fresh build: text on the box is 8.18:1 in light mode and 11.85:1 in dark mode.
  - B4 Removing `link-color` undoes nothing. Zephyr derives links from `primary`, as AC2 measured.
  - B5 The `articles:` index lists the four vignettes by name, so a fifth one needs an entry. `check_pkgdown()` reports a missing one.
- Diff-bug lens (Opus), 5 findings, all ranked low, none blocking. D1 to D3 were confirmed against pkgdown 2.2.1 source and the fresh build this session.
  - D1 The light navbar comes from `light-switch: true`, not from removing `navbar: bg`. `pkgdown:::data_navbar()` sets the navbar style to `NULL` with the light switch on. Without it, zephyr's default is `bg-primary`. Nothing in the configuration records that link.
  - D2 The workflow comment lists the skipped `.md` files as README, NEWS, LICENSE, and cran-comments. `pkgdown:::package_mds()` also skips `LICENCE.md`, the issue and PR templates, and `404.md` in dev mode, and it renders `.md` files in `.github/`.
  - D3 `articles/index.html` shows "Articles" twice, as the page `<h1>` and as the section `<h3>`, because the one section has the title `Articles`.
  - D4 Zephyr colors the active tab label with raw `primary`, about 1.9:1 on the dark background. No page on the site uses tabs today.
  - D5 `clean: true` deletes the 258-file `dev/` tree on `gh-pages`, so outside bookmarks into it break. Nothing in the repo links to it, and the plan scope names this removal.
