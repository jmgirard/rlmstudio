# M074: A vignette shows chat options, conversations, and errors in scripts

**Status:** done (2026-10-01, PR #74 https://github.com/jmgirard/rlmstudio/pull/74).

**Goal:** A user can choose a chat route, set request options, hold a
conversation, and handle errors in a script, from one new vignette.

**Outcome:** `vignettes/chat-options.Rmd.orig` is new and knitted. A table
shows what `lms_chat()` supports on each route. The text covers
`temperature` and a misspelled option, which the default route ignores and
native refuses. It shows a follow-up by `previous_response_id`, a
`messages` data frame on `lms_chat_openai()`, and the raw reply. A
`chat_or_na()` function catches four condition classes, and the text names
the errors that still stop a loop. `test-vignette-claims.R` backs each
package claim. NEWS has one entry.

**Decisions:** none cross-cutting. The API error example is a misspelled
model name. It also raises the mismatch on the default route.

**Review:** One defect return: "The package does not check the names of
request options" was false. Pass 2 passed all 6 criteria with three
lenses. The user left the gate to the session, which fixed 12 findings.
Among them were a misspelled-name sentence too broad for a short name and
three new tests. Seven were rejected and one noted. The knit lesson was
extended.
