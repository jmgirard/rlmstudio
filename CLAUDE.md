# rlmstudio

R package wrapping the LM Studio CLI and REST API. Toolchain profile:
r-package (see `cairn/PROFILE.md`).

## Dev commands

``` r

devtools::document()   # after roxygen changes
devtools::test()       # tests; live LM Studio tests are skipped without it
devtools::check()      # full check before review
devtools::build_readme()
```

## Project tracking (cairn)

This repo uses the cairn plugin. Before you act on any request, classify
it and route it. A cairn skill must fire before the tracking rulebook
loads. Work started in plain conversation bypasses the work tiers and
the git model. Classify first:

- Trivial (no runtime surface: a typo, a comment, a tracking edit):
  commit directly to the default branch.
- User-visible bug: invoke `/hotfix`.
- New work, a design decision, or more than one sitting: invoke
  `/milestone-plan`, then `/milestone-implement`, then
  `/milestone-review`.
- Status, “what’s next”, or unsure which tier: invoke `/milestone`.
- Never implement code on the default branch outside a milestone or
  hotfix branch. The user must give explicit approval at the review gate
  before anything reaches it.

If the request is anything but trivial, invoke the skill first so the
full rulebook loads. The rulebook is the plugin’s
`skills/shared/tracking-rules.md`. Do not reconstruct the rules here
from memory. All project state lives under `cairn/`. Architecture goes
to DESIGN, status to ROADMAP, tasks to milestone files, decisions to
DECISIONS, lessons to LESSONS, and history to archive and git. Never
record status or TODOs in this file. Claude’s persistent memory never
holds project state. The `cairn/` files win any conflict.
