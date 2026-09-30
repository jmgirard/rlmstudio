# Lists each `for` loop that sits in a `test_that()` block of
# tests/testthat/test-*.R with no other `for` loop between them, and whose
# body calls an `expect_*()` function. Written for M065. Run from the repo
# root:
#   Rscript cairn/tools/loop-sweep.R
# Output: one tab-separated row per loop, with the file, the block
# description, the loop header, and a status. The block description is the
# deparsed first argument of the innermost enclosing `test_that()`. If each
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

files <- list.files("tests/testthat", "^test-.*\\.R$", full.names = TRUE)
for (f in sort(files)) {
  for (e in parse(f, keep.source = FALSE)) walk(e, f)
}
writeLines(rows)
