# RB01: The OpenAI chat function and a non-vector messages column (M042)

- **Date:** 2026-09-27
- **Output required:** write findings to `cairn/reviews/RR01-ac2-non-vector-columns.md`
- **Binding criteria:** not requested

You are performing an independent expert review. This brief is fully
self-contained. Do not assume any conversation context. Read only what this
brief directs you to read, answer the numbered questions, and write your
findings to the output path above using the same numbering.

## Background

rlmstudio is an R package that wraps the LM Studio command-line tool and REST
API. `lms_chat_openai()` sends a chat request to LM Studio's OpenAI-style
endpoint. Its `messages` argument is a list of messages or a data frame with
one row per message. Before the call checks for a running server, the
function `rlm_check_messages()` runs a series of rules on `messages`, in this
order:

1. Shape rules (`messages_fault()`), which include the data-frame rules in
   `data_frame_messages_fault()`: a column-name rule, then an empty-row rule
   (a row in which every cell is empty is refused, because jsonlite
   sends it as an empty message), then a list-`dim` rule and a nested-name
   rule. Each fault aborts under the header "`messages` must be a data frame
   or an unnamed list of messages."
2. A function rule (`has_function()`): a function anywhere in the value
   aborts.
3. A trial write (`messages_write_fault()`): `jsonlite::toJSON()` runs with
   the options the request uses. An error aborts with the detail "You gave a
   value that jsonlite cannot write: <jsonlite message>". Rules 2 and 3 use
   the header "`messages` holds a field value that cannot be sent as JSON."
   A jsonlite warning is not caught, and the value is sent.

Milestone M040 chose the trial write in place of an allow-list of classes, so
that the package refuses only what jsonlite cannot write.

Milestone M042 (branch `m042-openai-messages-odd-columns`) changes
`empty_rows()`, the helper behind the empty-row rule. Before M042, it called
`is.na()` on each column. For a data-frame column that is neither an atomic
vector nor a list (an environment, a symbol, a call, an S4 object, an
external pointer, an expression vector), `is.na()` warns. M042 treats such a
column as never empty and does not call `is.na()` on it.

Acceptance criterion AC2 of M042 then promises what happens next. Its current
text:

> AC2: In `lms_chat_openai()`, a data-frame column that is neither an atomic
> vector nor a list counts as not empty in each row. Examples are an
> environment, a formula, a symbol, a call, an S4 object whose `typeof()` is
> `"S4"` (such as a reference-class object), an external pointer, an
> expression vector, and a function (any value for which `is.function()` is
> TRUE). This holds for a column of `messages` and for a column of a
> data-frame column. `empty_rows()` gives no R warning for such a column. In
> a frame that passes the shape, column-name, empty-row, list-`dim`,
> nested-name and function rules, every such column aborts with the
> value-fault header and the jsonlite-write detail. The one exception is an
> S4 class definition with at least one slot
> (`methods::is(x, "classRepresentation")` and `length(x@slots) > 0`), which
> jsonlite writes as an object mapping slot names to class names. A function
> column in a row that is otherwise `NA` aborts with the function detail.

AC2 failed independent review twice, each time because jsonlite wrote a
non-vector value that, by the text, it cannot write:

- Review pass 1: a column holding an S4 class definition
  (`methods::getClass()` of a class with a slot) gave the jsonlite warning
  "collapse=FALSE called for named list." and was sent. AC2 was then
  narrowed to the text above, with that exception.
- Review pass 2: a non-vector column with an S3 class that jsonlite has a
  method for was sent. Three inputs reached the server: an environment with
  class `"POSIXt"`, a call with class `"function"`, and an expression vector
  with class `"NULL"`.

The project's rules treat a second failure of one criterion by the same kind
of cause as a sign of a wrong approach, not a wording slip. The maintainer
chose to ask for this review before the next attempt.

## Materials

Read these, on the branch `m042-openai-messages-odd-columns`:

- `R/utils-args.R`: `rlm_check_messages()` (about line 345),
  `messages_write_fault()` (about line 393), `messages_fault()` (about line
  475), `data_frame_messages_fault()` (about line 678), `empty_rows()`
  (about line 698 to 745).
- `R/chat.R` lines 265 to 320: the `messages` help of `lms_chat_openai()`.
- `NEWS.md` lines 1 to 8.
- `tests/testthat/test-arg-guards.R`: the three tests whose names contain
  "not a vector", "class-definition column", and "empty_rows() finds no
  empty row" (search for those strings).
- `cairn/milestones/M042-openai-messages-odd-columns.md`: Scope, Acceptance
  criteria, and the Review section. The Review section lists the pass-1
  findings O1 to O9 and the pass-2 findings P1 to P9.
- `git diff main...m042-openai-messages-odd-columns -- R NEWS.md` for the
  whole code change of the milestone.

To try an input, run in the repo root:

```r
devtools::load_all()
df <- structure(list(role = NA_character_, x = structure(new.env(), class = "POSIXt")),
  class = "data.frame", row.names = 1L)
lms_chat_openai("a-model", df, port = 1)
```

A call that passes every `messages` rule stops at the server check with a
"no server" error, because nothing listens on port 1. The tests run with
`devtools::test(filter = "arg-guards")`.

## Questions

1. Three repairs are on the table. Compare them for correctness, for how
   well each can be tested, and for what a user of `lms_chat_openai()`
   sees:
   - (a) Narrow AC2 and keep the code. The abort clause lists the tested
     kinds: an environment, a symbol, a call, and an expression vector,
     each with no `class` attribute; a formula made with `~`; an object of
     an S4 class that `methods::setClass()` defines with one numeric slot;
     a reference-class object; and an external pointer. It then says that
     any other such column reaches the trial write, and what jsonlite does
     decides whether the call aborts.
   - (b) Refuse in code. A new rule, before the trial write, aborts on
     every data-frame column (at any depth of data-frame columns) that is
     neither an atomic vector nor a list, other than a function, with the
     value-fault header and a new detail. A slotted class definition and
     the three classed values from review pass 2 then abort too.
   - (c) Drop the abort clause from AC2. AC2 then promises only that such a
     column is not empty and that `empty_rows()` gives no warning. The
     trial write stays as it is, and no criterion promises its result for
     these columns.
   Which do you recommend, and why? If none, propose a fourth.
2. Option (b) adds a type check next to a trial write that M040 chose over
   an allow-list of classes. Does a non-vector rule contradict that choice,
   or does it fit, given that jsonlite's handling of these values rests on
   its S3 dispatch rather than on what the value holds? Name any value a
   user can send today, on `main`, that (b) starts to refuse. Sparse
   matrices from the Matrix package (S4 objects) are one case to check.
3. For whichever option you recommend, give the exact AC2 text. Say which
   domain each universal clause in it quantifies over, and name the test or
   procedure that covers that domain. A clause whose domain no test
   enumerates must be bounded to a named list.
4. The `messages` help (`R/chat.R`, the empty-row bullet) says: "A column
   that is neither an atomic vector nor a list, such as an environment,
   never counts as empty." NEWS.md line 4 says that such a column "aborts
   with the error for a value that jsonlite cannot write, or with the error
   for a function", with a slotted class definition as the one exception.
   Under your recommended option, which of these sentences must change, and
   to what?
5. Does `empty_rows()` itself have a fault the two reviews missed for a
   column that is neither atomic nor a list? For example: a value for which
   `is.atomic()` or `is.list()` gives an answer that does not match how
   jsonlite writes it, or a classed value whose `is.na()` method returns
   something other than one logical per row.

## Constraints

- Hand-built frames (made with `structure()`) whose array column has a
  first extent other than the row count, or that hold a `NULL` column, are
  out of M042's scope. Do not recommend work on them here.
- M042 does not change what is sent for a list-matrix column. That stays as
  M041 chose.
- D-003 (in `cairn/DECISIONS.md`) and guiding principle GP4 (in
  `cairn/DESIGN.md`) say the server is the validator for fields passed
  through `...`. `messages` is a named argument, so the package checks it.
  Flag disagreement explicitly if you think a check here oversteps GP4.
- Any dependency change needs the maintainer's decision. Do not assume one.
- A criterion is checked as written at review. Prefer criteria a script can
  check.

## Output format

In `RR01-ac2-non-vector-columns.md`: answer each question by number with
your reasoning and evidence; list any additional findings separately under
"Beyond the brief"; end with concrete recommendations, each marked apply /
consider / reject-with-reason. Your report is advisory: emit a
`## Binding criteria` section ONLY if this brief's header slot says
`requested`. Where requested: numbered `BC1…`, each a measurable assertion
checkable against evidence, with any numeric projection stating its
tolerance. These are ingested VERBATIM into the constrained milestone's
acceptance criteria and mechanically diffed against this file; departures
are legal only through that milestone's shown "Deviations from RR01" table.
