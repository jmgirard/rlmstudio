# Helpers that test-arg-guards.R and test-request-body.R both use. CRAN skips
# the first file and runs the second, so these live outside both.

# A stand-in value for every formal that has no default. The table is keyed by
# formal name, and a name it does not carry is a test failure rather than a
# skip: a silent skip would let a whole function leave the domain unnoticed.
arg_placeholders <- list(
  model = "a-model",
  job_id = "a-job",
  input = "a prompt",
  inputs = c("first", "second"),
  messages = list(list(role = "user", content = "a prompt"))
)

required_formals <- function(name) {
  formal_args <- formals(get(name, envir = asNamespace("rlmstudio")))
  needed <- vapply(
    formal_args,
    function(default) identical(default, quote(expr = )),
    logical(1)
  )
  setdiff(names(formal_args)[needed], "...")
}

# The table is an argument so a test can drive the missing-placeholder branch
# without mocking, the way httpuv_absence_action() takes both of its inputs.
baseline_args <- function(name, table = arg_placeholders) {
  needed <- required_formals(name)
  missing_from_table <- setdiff(needed, names(table))
  if (length(missing_from_table) > 0) {
    testthat::fail(paste0(
      "No placeholder for the required argument(s) ",
      paste(missing_from_table, collapse = ", "),
      " of ",
      name,
      "(). Add one to arg_placeholders, or the guard for that ",
      "function goes untested."
    ))
  }
  table[needed]
}

# The functions that send a chat request, read from NAMESPACE. Each is called
# with its placeholders, an `api_type` when `route` is not NULL, and `dots`.
stream_domain <- function() {
  grep("^lms_chat", sort(getNamespaceExports("rlmstudio")), value = TRUE)
}

stream_routes <- function(name) {
  if (name %in% c("lms_chat", "lms_chat_batch")) {
    list("openresponses", "openai", "native")
  } else {
    list(NULL)
  }
}

stream_call <- function(name, route, dots) {
  fn <- get(name, envir = asNamespace("rlmstudio"))
  args <- baseline_args(name)
  if (!is.null(route)) {
    args$api_type <- route
  }
  do.call(fn, c(args, dots))
}

stream_label <- function(name, route, dots) {
  paste(
    name,
    "on",
    if (is.null(route)) "its route" else route,
    "with",
    deparse1(dots)
  )
}

# lms_chat_openai(messages =) is checked before the server probe. Each rule has
# one detail text, stated here rather than read from the package, so a detail
# that names the wrong rule turns the test red.
messages_rule_details <- c(
  rule1 = "You gave a value that is neither a list nor a data frame.",
  rule2 = "You gave no messages.",
  rule3 = "You gave a list with names, which is sent as one JSON object.",
  rule4 = "You gave a message that is not a list with a name on each field.",
  rule5 = "You gave a data frame that has no columns or a column name that is missing or repeated.",
  rule6 = "You gave a data frame with a row in which every cell is NA or a NULL list cell.",
  rule7 = "You gave a list with a dim attribute, such as a matrix of messages.",
  rule8 = "You gave a message with a dim attribute, such as a list array.",
  rule9 = "You gave a message, or a list or data frame inside one, with a name that is NA, empty, or repeated.",
  rule10 = "You gave a value that jsonlite cannot write:",
  rule11 = "You gave a list with a dim attribute inside a message, such as a list-matrix field.",
  rule12 = "You gave a field value that is a function, which jsonlite would send as its source text.",
  rule13 = "You gave a field value of type \"",
  rule14 = "You gave a data frame with a column whose row count differs from the row count of the data frame."
)

# A data frame of n rows, built by hand, so a column may hold a row count
# that differs from n. data.frame() would recycle or refuse such a column.
df_of_rows <- function(n, ...) {
  structure(list(...), class = "data.frame", row.names = c(NA, -n))
}

# Runs lms_chat_openai() on a messages value and returns the condition it
# raises, or NULL, with the number of warnings raised on the way. Each
# warning is counted and muffled, so none reaches the test output.
chat_openai_outcome <- function(messages) {
  n_warnings <- 0L
  err <- tryCatch(
    withCallingHandlers(
      {
        lms_chat_openai("a-model", messages)
        NULL
      },
      warning = function(w) {
        n_warnings <<- n_warnings + 1L
        invokeRestart("muffleWarning")
      }
    ),
    error = function(e) e
  )
  list(error = err, n_warnings = n_warnings)
}

# The detail of the number rule, stated here rather than read from the
# package.
number_detail <- paste(
  "You gave a number that is NA, NaN, or infinite, which jsonlite would",
  "send as a string or leave out."
)

# In an atomic data-frame column with no dim attribute, jsonlite leaves an
# NA, NaN, Inf, or -Inf cell out of the row. These are four of the places
# such a column can sit. The column is `x`, beside a column `k` that keeps
# the row of a nested data frame from being empty.
plain_column_places <- list(
  "the top level" = function(v) {
    data.frame(role = "user", x = v)
  },
  "a data-frame column" = function(v) {
    df <- data.frame(role = "user")
    df$sub <- data.frame(k = "a", x = v)
    df
  },
  "a data frame as a list field" = function(v) {
    list(list(role = "user", content = data.frame(k = "a", x = v)))
  },
  "a data frame in a list-column cell" = function(v) {
    df <- data.frame(role = "user")
    df$c <- list(data.frame(k = "a", x = v))
    df
  }
)

# A column with a dim attribute and no cells in a row is written as `[]`, or
# as nested empty arrays, which are field values. Row 2 of `role` and
# `content` is NA, so the extra column alone decides whether row 2 is empty.
no_cell_frame <- function(column) {
  df <- data.frame(role = c("user", NA), content = c("Hi", NA))
  df$x <- column
  df
}
