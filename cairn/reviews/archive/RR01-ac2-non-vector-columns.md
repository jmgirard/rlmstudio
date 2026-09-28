# RR01: The OpenAI chat function and a non-vector messages column (M042)

- **Date:** 2026-09-27
- **Brief:** `cairn/reviews/RB01-ac2-non-vector-columns.md`
- **Branch read:** `m042-openai-messages-odd-columns` (HEAD 53c0151)
- **Environment:** R 4.6.1, jsonlite 2.0.0, Matrix installed
- **Status:** advisory. The brief did not request binding criteria.

## Evidence base

Two probe scripts ran against `devtools::load_all()` on the branch. For
comparison, `main`'s `empty_rows()` was sourced under another name from
`git show main:R/utils-args.R`. Whole-call probes used `port = 1`. The
facts below decide the answers.

1. jsonlite's fallback `asJSON` method (signature `"ANY"`) does two
   things. For any S4 object other than a `classRepresentation`, it stops
   with "No method for S4 class:<class>" unless `force = TRUE`. The
   object's content plays no part. For any other value, it strips the
   first class and retries until one class has a method. If none has, it
   stops with "No method asJSON S3 class: <class>". `httr2::req_body_json()`
   does not pass `force`. So for a value that is neither an atomic vector
   nor a list, only its `class` attribute decides whether jsonlite writes
   it. Its content never does.
2. jsonlite has methods for 27 S3 class names plus `classRepresentation`.
   Each of the 27 is a method for a vector, list, or data frame type. The
   only non-vector type with a method is `classRepresentation`.
3. The values in AC2's list that have no `class` attribute carry the
   implicit classes `environment`, `name`, `call`, and `expression`. A
   formula carries the attribute `formula`. None of these has a jsonlite
   method, so each aborts at the trial write, every time. Other call forms
   have implicit classes `if`, `<-`, `(`, `{`, and `for`. None has a
   method either.
4. A hand-set class attribute can make jsonlite write a non-vector value.
   Each case below was verified in a one-row frame whose other cell is
   `NA`:
   - An environment, a call, an expression vector, or an external pointer
     with class `classRepresentation` or `NULL` is written as `null`.
   - The same four base types with class `function` or `POSIXt` are
     written as printed or deparsed text, such as `"<environment: 0x...>"`
     or `"f(x)"`.
   - A call or an expression vector with class `hms` is written, with a
     warning.
   - An expression vector with class `ITime`, `json`, or `list` is written
     as `"1"` or `1`.
   - An expression vector with class `sfc` is written as
     `{"type":null,"coordinates":1}`.
   - A symbol was probed against every class name. None wrote it.
   The three pass-2 inputs reproduce. Each reaches the server probe.
5. The same three classed values in a list message,
   `list(list(role = "user", content = x))`, also pass every rule and
   reach the server probe. The hole is not specific to data-frame columns.
6. A sparse `dgCMatrix` column aborts at the trial write on the branch
   with "No method for S4 class:dgCMatrix", with or without `NA` cells.
   `main`'s `empty_rows()` returns the same row values for it, with no
   warning, because Matrix defines `is.na()` and `rowSums()`. Outside the
   package, `toJSON()` on a `dgCMatrix` fails the same way.
7. An S4 object that `contains` a basic type has `is.atomic()` or
   `is.list()` TRUE. It takes the `is.na()` branch with no warning. It then
   aborts at the trial write by fact 1. When its cell is `NA`, the
   empty-row rule aborts first.
8. On `main`, `empty_rows()` warns "is.na() applied to non-(list or vector)
   of type 'S4'" for an S4 object and for a slotted class definition. On
   the branch neither warns. On both refs, jsonlite writes the slotted
   class definition with the warning "collapse=FALSE called for named
   list.". The slotless one (`getClass("numeric")`) fails the write.
9. `is.function(structure(quote(f(x)), class = "function"))` is FALSE, so
   the function rule does not catch the pass-2 call.
10. `is.atomic(NULL)` is FALSE in R 4.6.1, as it is since R 4.4.0.

## 1. Which repair

**Correctness.** All three are correct as stated. (a) stays true for two
reasons. Its abort clause is bounded to kinds whose jsonlite outcome facts
1 and 3 fix (no class attribute, or S4). Its trailing clause describes the
pipeline and promises nothing. (b) is true by construction, because the
rule's predicate is the domain. (c) is true because it promises only what
`empty_rows()` does.

**Testability.** (a): the two whole-call tests already enumerate the list,
and the `empty_rows()` test enumerates twelve kinds at two depths. Nothing
new is needed. (b): the rule is one predicate, so one loop over a list of
kinds covers it. But the walk must reach a data-frame column at any depth.
Its order against the empty-row, list-`dim`, nested-name, and function
rules must be pinned too. That is four more probes. (c): the `empty_rows()`
test alone covers it.

**What the user sees.** (a) and (c) match `main`, with two changes. A
non-vector column no longer warns, and it no longer trips the empty-row
rule. A plain environment, symbol, call, formula, expression, external
pointer, S4 object, or reference-class object aborts with jsonlite's own
message. That message already names the class, for example "No method
asJSON S3 class: formula" or "No method for S4 class:dgCMatrix". A
non-vector value with a hand-set class from fact 4 is sent as junk text or
`null`. That is what `main` does today, in the frame form and the list
form. (b) changes two things. The fact-4 values and the slotted class
definition abort with a package message. The other kinds get the package
message in place of jsonlite's. But (b) as written covers only data-frame
columns. So `df$x <- structure(env, class = "POSIXt")` aborts, while the
same value as a list field is sent (fact 5). A user who reads the first
message and moves the value into a list gets it sent as
`"<environment: 0x...>"`. That asymmetry is new, and it is worse than
either hole alone.

**Recommendation: (a), with the wording in section 3.** The approach that
failed twice was a universal claim about what jsonlite does over an open
domain. (a) bounds the claim to kinds whose outcome jsonlite's code fixes
(facts 1 and 3). It says out loud that nothing else is promised. It costs
no code and no new tests. (c) is (a) minus the pin. It drops the record of
M042's user-visible effect. That is the NEWS sentence on such a column
now getting the jsonlite or function error in place of the empty-row
error. It gains
nothing, because the tests behind the pin exist either way.

(b) is the right idea in the wrong shape and the wrong milestone. The
right shape is a value rule over both forms, at any depth, beside
`has_function()`. It aborts on a value that is neither atomic, nor a list,
nor `NULL`. By fact 2, jsonlite writes no such value in a usable form. So
the rule refuses nothing a user wants sent. It closes the fact-4 and
fact-5 holes and the slotted-class-definition warning at once. It is a new
refusal for the list form too, and it retires the candidate row on the
slotted class definition. So it belongs in its own milestone. Call it (b′)
below.

## 2. Does (b) contradict M040

M040 rejected a class allow-list because a list of classes goes stale. (b)
and (b′) are not a class list. They test the storage type with
`is.atomic()` and `is.list()`. That is the boundary jsonlite's own method
table respects (fact 2). Every method jsonlite has is for a vector, a list,
or a data frame. When jsonlite "writes" a non-vector value, S3 dispatch
lands on a method meant for another type. The output is printed or
deparsed text or `null` (fact 4), never the value. So a non-vector rule
fits M040's purpose, which was to refuse what jsonlite cannot write. New jsonlite methods are for new vector classes, so the rule does not
depend on a list that goes stale. It does widen one sentence
in the `rlm_check_messages()` roxygen: "A function and a value that
jsonlite cannot write are the only field values the package judges". That
sentence needs a third item under (b) or (b′).

GP4 and D-003: `messages` is a named argument, so a check on it is inside
the package's remit. No disagreement to flag. D-020 narrowed D-003 the
same way for `ttl`.

**Values a user can send on `main` that (b) starts to refuse**, as
data-frame columns:

- Any non-vector value whose `class` attribute is one of the fact-4
  combinations. The list holds for jsonlite 2.0.0 and the four base types
  probed.
- A slotted S4 class definition, from `methods::getClass()` of a class
  with a slot. `main` sends it with a jsonlite warning and an `is.na()`
  warning.

Each of these needs a class attribute set by hand, or a class definition
object placed in a frame. No ordinary column from `data.frame()`, from
`$<-` on a vector, or from a modelling package is in the set.

**Sparse matrices:** not affected. A `dgCMatrix` column aborts at the trial
write on `main` and on the branch (fact 6), because jsonlite's `ANY`
method stops on every S4 object. (b) changes only which detail text the
user reads. The same holds for every other S4 object that is not a
`classRepresentation`. That includes reference-class objects and every S4
class from Matrix, S4Vectors, or Bioconductor.

## 3. Exact AC2 text under (a)

> AC2: A data-frame column for which `is.atomic()` and `is.list()` are
> both FALSE counts as not empty in each row of `empty_rows()`, and
> `empty_rows()` gives no R warning for it. This holds at the top level
> of `messages` and inside a data-frame column. The domain is the twelve
> column kinds that the test "empty_rows() finds no empty row in a column
> that is not a vector" builds:
>
> - an environment
> - a formula
> - a symbol
> - a call
> - an S4 object of a class with one numeric slot
> - a reference-class object
> - an external pointer
> - an expression vector
> - a function
> - a class generator
> - a class definition with a slot
> - a class definition with no slot
>
> Each kind sits at both depths in a one-row frame whose other column is
> `NA`. A three-row formula column is the thirteenth case. For each,
> `empty_rows()` returns all `FALSE` with no warning.
>
> In `lms_chat_openai()`, for each column kind that the test "a column
> that is not a vector is not empty and gives no warning" builds, in a
> frame whose other cells are `NA`, the call aborts before the server
> probe. The abort carries the value-fault header and the jsonlite-write
> detail, with no R warning. The kinds are:
>
> - an environment, a symbol, a call, and an expression vector, each with
>   no `class` attribute
> - a formula made with `~`
> - an object of an S4 class that `methods::setClass()` defines with one
>   numeric slot
> - a reference-class object
> - an external pointer
> - a symbol inside a data-frame column
>
> A function column in such a frame, at the top level or inside a
> data-frame column, aborts with the function detail, with no R warning.
>
> For any other column that is neither an atomic vector nor a list, this
> criterion promises only the first paragraph. The later rules and the
> trial write decide the call. AC2 does not state their result.

Domains and their coverage:

- Paragraph 1 quantifies over the twelve kinds at two depths plus the
  three-row formula. The test "empty_rows() finds no empty row in a
  column that is not a vector" enumerates them: 26 kind-by-depth checks
  and one three-row check. The predicate sentence names the code branch.
  The domain sentence bounds the claim to the list.
- Paragraph 2 quantifies over the kinds the test "a column that is not a
  vector is not empty and gives no warning" builds. That test has nine
  jsonlite-write cases and two function cases. It wraps each in a
  no-warning check and ends with a zero server-probe count.
- Paragraph 3 quantifies over nothing. It is the explicit non-promise.

The test "an S4 class-definition column is sent only when it has a slot"
stays. It pins current jsonlite behavior, and the pass-2 disposition P5
kept it for that reason. No criterion cites it. If jsonlite changes, that
test is edited, not AC2.

## 4. Help and NEWS under (a)

The help sentence in `R/chat.R` reads: "A column that is neither an
atomic vector nor a list, such as an environment, never counts as
empty." It is true as it stands. It does not change.

NEWS.md line 4 must change. It says: "So it aborts with the error for a value
that jsonlite cannot write, or with the error for a function". That is
the universal that failed. Its "the one exception" is false by fact 4.
Proposed text:

> * A data-frame column that is neither an atomic vector nor a list, such
>   as an environment, a symbol, or an expression vector, no longer gives
>   an R warning from the empty-row check. It never counts as empty. So a
>   row whose other cells are `NA` no longer aborts with the empty-row
>   error when it holds such a column. The later rules decide the call. A
>   function aborts with the error for a function. An environment, a
>   symbol, a call, an expression vector, a formula, an external pointer,
>   an S4 object, or a reference-class object, with no class attribute
>   added by hand, aborts with the error for a value that jsonlite cannot
>   write.

The sentence on the slotted class definition comes out. Its behavior is
unchanged from `main` apart from the `is.na()` warning. The first sentence
covers that warning, and the ROADMAP candidate row records the value.

One roxygen sentence also changes, because finding P1 named it. In the
`empty_rows()` comment, the sentence "The function rule or the trial
write refuses it later." changes. Its new form: "The function rule or
the trial write judges it later."

## 5. Faults in `empty_rows()` for a non-atomic, non-list column

None found in the branch itself. The predicate
`!is.atomic(column) && !is.list(column)` is exactly the domain on which
`is.na()` warns ("applied to non-(list or vector)"). Fact 8 verified that
on `main` for an S4 object and a class definition. The scalar `FALSE`
recycles correctly against `empty` for any row count. Three points sit
next to the question. None is a defect of this branch.

- `is.atomic()` and `is.list()` versus jsonlite: jsonlite dispatches on
  class, not type. The two can disagree only for an S4 object that
  `contains` a basic type. Such a column takes the `is.na()` path with no
  warning and then aborts at the trial write (fact 7). That is the right
  outcome, so it is not a fault.
- `is.atomic(NULL)` is FALSE from R 4.4.0 (fact 10). So a hand-built
  frame with a `NULL` column now takes the non-vector branch and counts
  as never empty. On R 4.3 and earlier it took the `is.na()` path, and
  `empty_rows()` returned `logical(0)`. The `NULL` column is Scope Out by
  the brief, so no work is recommended. The version dependence is
  recorded here for a future reader of that candidate.
- A classed `is.na()` method that returns something other than one
  logical per row was not found among real classes. `POSIXlt` and
  `vctrs_rcrd` both return one logical per row. Their `as.list()` methods
  split per row, so `vapply(column, is.null, ...)` also gives one value
  per row. Both behave on `main` and on the branch. The construction
  that misfires is a list-of-fields S3 class with `length()` and
  `is.na()` methods but no `as.list()` method. `vapply()` then walks
  fields, not rows, and the `|` warns "longer object length is not a
  multiple of shorter object length". That is a list column, not a
  non-vector one. It exists on `main`, and it needs a hand-written class.
  See B2 below.

## Beyond the brief

- **B1. Nested zero-column data-frame column.** `df$sub <- data.frame(a =
  1:2)[, 0]` gives a column with no columns. `empty_rows()` recurses into
  it and finds no column to clear `empty`. So it reports every row of it
  as empty, and a row whose other cells are `NA` aborts with the
  empty-row detail. jsonlite writes that row as `{"sub":{}}`, which is a
  field value. `main` does the same. The case is small and needs a
  subsetting step. But it is a false abort, unlike the other empty-row
  over-refusals, which are conservative.
- **B2. List column of a field-record S3 class without `as.list()`.** As
  in answer 5: a recycling warning and a wrong row count from
  `vapply(column, is.null, ...)`. `main` does the same. A loop over
  `seq_along(column)` with `[[` does not fix it, because `[[` also
  indexes fields for such a class. Only a check that the two lengths
  agree makes it fail cleanly.
- **B3. The hole is form-independent.** Fact 5: every classed non-vector
  value that a data-frame column sends as junk is also sent as junk from
  a list message. A refusal that treats it as a column problem needs a
  second milestone for the list form. That is the reason (b′) is proposed
  over (b).
- **B4. jsonlite's C stack.** `toJSON()` on an environment with class
  `array` or `matrix` overflowed the C stack ("C stack usage is too close
  to the limit") in place of a jsonlite message. The trial write catches
  it as an error, so the user gets the value-fault header with that text.
  Not actionable in this package. It is noted so a reviewer who probes it
  does not take it for a package bug.

## Recommendations

1. **apply** Adopt (a) with the AC2 text in section 3, the NEWS text in
   section 4, and the one-word roxygen change in section 4. No code
   change, no new tests. For the review evidence, re-run the three AC2
   tests and the whole-call probe on the listed kinds.
2. **apply** Keep the class-definition test as a pin of jsonlite behavior
   that no criterion cites. Leave the ROADMAP candidate row on the slotted
   class definition in place.
3. **consider** Add a ROADMAP candidate row for (b′): a value rule beside
   `has_function()`. It walks both forms at any depth. It aborts, with
   its own detail, on a value that is neither atomic, nor a list, nor
   `NULL`. It retires the slotted-class-definition row and closes the
   fact-4 and fact-5 junk sends. Record fact 2 in the row as the reason
   it is not the class list M040 rejected. Decide it at a plan gate, not
   inside M042.
4. **consider** A candidate row for B1, the zero-column nested data frame
   counted as empty. It is a false abort, not an over-refusal.
5. **reject** (b) as written, scoped to data-frame columns. It creates a
   column-versus-field asymmetry (fact 5). In practice it refuses only
   values with a hand-set class attribute. Every realistic value in its
   domain already aborts at the trial write with a message that names the
   class.
6. **reject** (c). It is (a) without the bounded pin and without the NEWS
   sentence on the user-visible change. It saves nothing, because the
   tests behind the pin exist either way.
7. **reject** any change for B2 or for the `NULL` column. Both need a
   hand-built value, and both are on `main`. B2 is recorded here so a
   future `vapply()` edit does not assume `as.list()` splits per row.
