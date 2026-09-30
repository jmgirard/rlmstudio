# Lists each `for` loop that sits in a `test_that()` block of
# tests/testthat/test-*.R with no other `for` loop between them, and whose
# body calls an `expect_*()` function. Written for M065. Run from the repo
# root:
#   Rscript cairn/tools/loop-sweep.R
# Output: one tab-separated row per loop, with the file, the block
# description, the loop header, and a status. The second report below adds
# rows of its own, with a call in place of the loop header. The block
# description is the deparsed first argument of the innermost enclosing
# `test_that()`. If each
# statement of the loop body is a `test_that()` call, the status is "nested".
# Otherwise it is "flat". Under testthat edition 3, an error in a flat body
# ends its block, and the passes after it do not run. An `expect_error()`
# whose class or pattern does not match raises its error again, so it ends
# the block too. A nested body keeps the error inside one subtest.

calls_expect <- function(e) {
  if (!is.call(e)) return(FALSE)
  if (is.name(e[[1]]) && startsWith(as.character(e[[1]]), "expect_")) {
    return(TRUE)
  }
  any(vapply(as.list(e), function(a) !missing(a) && calls_expect(a), NA))
}

statements <- function(b) {
  if (is.call(b) && identical(b[[1]], as.name("{"))) {
    return(unlist(lapply(as.list(b)[-1], statements), recursive = FALSE))
  }
  list(b)
}

is_subtest <- function(s) {
  is.call(s) && identical(s[[1]], as.name("test_that"))
}

one_line <- function(e) gsub("\\s+", " ", paste(deparse(e), collapse = " "))

rows <- character()
walk <- function(e, file, block = NA, in_for = FALSE) {
  if (!is.call(e)) return(invisible())
  if (identical(e[[1]], as.name("test_that"))) {
    block <- one_line(e[[2]])
    in_for <- FALSE
  }
  if (identical(e[[1]], as.name("for"))) {
    if (!is.na(block) && !in_for && calls_expect(e[[4]])) {
      nested <- all(vapply(statements(e[[4]]), is_subtest, NA))
      header <- sprintf("for (%s in %s)", one_line(e[[2]]), one_line(e[[3]]))
      rows <<- c(rows, paste(basename(file), block, header,
                             if (nested) "nested" else "flat", sep = "\t"))
    }
    in_for <- TRUE
  }
  for (a in as.list(e)[-1]) if (!missing(a)) walk(a, file, block, in_for)
}

# Second report, added for the M065 review: each `expect_*()` call that a
# `test_that()` block runs before or between its nested `test_that()` calls.
# Under testthat 3.3.2 the results table drops a failure that a block records
# before its last nested subtest, so `test_check()` does not stop on it. A
# call counts if a nested call follows it in the source, or if the two share
# a loop inside the block. The row gives the file, the block description,
# the call and its line, and the status "before-subtest".
# The report does not see these, so 0 rows does not prove 0 sites:
# - a helper that records a result (for example with `fail()`) but whose name
#   does not start with `expect_`
# - a call inside a function literal, even one that runs in place, as in
#   `lapply(xs, function(x) expect_true(x))`
# - a call written `testthat::expect_*()`
# - a subtest written `testthat::test_that()`, or one that a helper makes

events <- NULL
scan_block <- function(body, file, block) {
  ev <- list()
  n_loops <- 0L
  visit <- function(e, loops, line, in_fun) {
    if (!is.call(e)) return(invisible())
    head <- e[[1]]
    if (identical(head, as.name("test_that"))) {
      ev[[length(ev) + 1]] <<- list(sub = TRUE, loops = loops)
      scan_block(e[[3]], file, one_line(e[[2]]))
      return(invisible())
    }
    if (is.name(head) && startsWith(as.character(head), "expect_")) {
      if (!in_fun) {
        ev[[length(ev) + 1]] <<- list(sub = FALSE, loops = loops,
                                      line = line, name = as.character(head))
      }
      return(invisible())
    }
    if (is.name(head) &&
        as.character(head) %in% c("for", "while", "repeat", "function")) {
      n_loops <<- n_loops + 1L
      loops <- c(loops, n_loops)
      in_fun <- in_fun || identical(head, as.name("function"))
    }
    refs <- if (identical(head, as.name("{"))) attr(e, "srcref")
    args <- as.list(e)[-1]
    for (i in seq_along(args)) {
      a <- args[[i]]
      if (missing(a)) next
      visit(a, loops,
            if (length(refs) > i) refs[[i + 1]][1] else line, in_fun)
    }
  }
  visit(body, integer(), NA, FALSE)
  subs <- Filter(function(x) x$sub, ev)
  for (k in seq_along(ev)) {
    x <- ev[[k]]
    if (x$sub) next
    later <- any(vapply(ev[-seq_len(k)], function(y) y$sub, NA))
    shared <- any(vapply(subs, function(y) any(y$loops %in% x$loops), NA))
    if (later || shared) {
      events <<- c(events, paste(basename(file), block,
                                 sprintf("%s() at line %d", x$name, x$line),
                                 "before-subtest", sep = "\t"))
    }
  }
}

find_blocks <- function(e, file, line) {
  if (!is.call(e)) return(invisible())
  if (identical(e[[1]], as.name("test_that"))) {
    return(scan_block(e[[3]], file, one_line(e[[2]])))
  }
  refs <- if (identical(e[[1]], as.name("{"))) attr(e, "srcref")
  args <- as.list(e)[-1]
  for (i in seq_along(args)) {
    a <- args[[i]]
    if (missing(a)) next
    find_blocks(a, file,
                if (length(refs) > i) refs[[i + 1]][1] else line)
  }
}

files <- list.files("tests/testthat", "^test-.*\\.R$", full.names = TRUE)
for (f in sort(files)) {
  for (e in parse(f, keep.source = FALSE)) walk(e, f)
  exprs <- parse(f, keep.source = TRUE)
  refs <- attr(exprs, "srcref")
  for (i in seq_along(exprs)) find_blocks(exprs[[i]], f, refs[[i]][1])
}
writeLines(c(rows, events))
