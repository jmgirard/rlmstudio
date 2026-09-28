# Extracted from test-arg-guards.R:1420

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "rlmstudio", path = "..")
attach(test_env, warn.conflicts = FALSE)

# prequel ----------------------------------------------------------------------
guarded_exports <- function(arg_names) {
  exports <- sort(getNamespaceExports("rlmstudio"))
  out <- Filter(
    function(name) {
      obj <- get(name, envir = asNamespace("rlmstudio"))
      is.function(obj) && any(arg_names %in% names(formals(obj)))
    },
    exports
  )
  out
}
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
local_guard_only <- function(.env = parent.frame()) {
  testthat::local_mocked_bindings(
    is_server_running = function(...) TRUE,
    .env = .env
  )
  local_no_request_allowed(.env = .env)
}
id_probes <- list(
  list(
    label = "two values",
    value = c("a", "b"),
    match = "2 values rather than one"
  ),
  list(
    label = "no values",
    value = character(0),
    match = "0 values rather than one"
  ),
  list(label = "NA", value = NA_character_, match = "You gave NA"),
  list(label = "empty string", value = "", match = "an empty string"),
  list(label = "whitespace", value = "   ", match = "whitespace only"),
  # `trimws()` does not strip either of these two, so they are the probes that
  # hold the rule to the whole `[[:space:]]` class rather than to four bytes.
  list(label = "form feed", value = "\f", match = "whitespace only"),
  list(label = "vertical tab", value = "\v", match = "whitespace only"),
  list(
    label = "a one-by-one matrix",
    value = matrix("a-model"),
    match = "an array rather than a single string"
  ),
  list(label = "NULL", value = NULL, match = "You gave NULL"),
  list(label = "a number", value = 42, match = "a numeric value"),
  list(label = "a logical", value = TRUE, match = "a logical value"),
  list(label = "a list", value = list("a"), match = "a list value"),
  list(label = "a factor", value = factor("a"), match = "a factor value")
)
strict_text <- list(
  lms_embed = "input",
  lms_chat_batch = "inputs"
)
loose_text <- list(
  lms_chat = "input",
  lms_chat_openresponses = "input",
  lms_chat_native = "input"
)
schema_calls <- list(
  lms_chat_openai = function(...) {
    lms_chat_openai("a-model", list(list(role = "user", content = "hi")), ...)
  },
  lms_chat = function(...) {
    lms_chat("a-model", "hi", api_type = "openai", ...)
  },
  lms_chat_batch = function(...) {
    lms_chat_batch("a-model", "hi", api_type = "openai", ...)
  }
)
local_counting_probe <- function(.env = parent.frame()) {
  probe <- new.env(parent = emptyenv())
  probe$calls <- 0L
  testthat::local_mocked_bindings(
    is_server_running = function(...) {
      probe$calls <- probe$calls + 1L
      FALSE
    },
    .env = .env
  )
  local_no_request_allowed(.env = .env)
  probe
}
schema_probes <- list(
  list(label = "a string", value = "object", match = "a character value"),
  list(label = "an unnamed list", value = list("a"), match = "has no name"),
  list(
    label = "a partly named list",
    value = list(type = "object", "a"),
    match = "has no name"
  ),
  list(
    label = "a list with an NA name",
    value = structure(list("object"), names = NA_character_),
    match = "has no name"
  ),
  list(label = "a data frame", value = data.frame(a = 1), match = "a data frame")
)
route_calls <- list(
  lms_chat = function(route) {
    args <- list("a-model", "hi", schema = list(type = "object"))
    if (!is.null(route)) args$api_type <- route
    do.call(lms_chat, args)
  },
  lms_chat_batch = function(route) {
    args <- list("a-model", "hi", schema = list(type = "object"))
    if (!is.null(route)) args$api_type <- route
    do.call(lms_chat_batch, args)
  }
)
ttl_calls <- list(
  lms_chat_openai = function(...) {
    lms_chat_openai("a-model", list(list(role = "user", content = "hi")), ...)
  },
  lms_embed = function(...) {
    lms_embed("a-model", "hi", ...)
  },
  lms_chat = function(...) {
    lms_chat("a-model", "hi", api_type = "openai", ...)
  },
  lms_chat_batch = function(...) {
    lms_chat_batch("a-model", "hi", api_type = "openai", ...)
  }
)
ttl_domain <- function() {
  exports <- guarded_exports("ttl")
  missing_call <- setdiff(exports, names(ttl_calls))
  if (length(missing_call) > 0) {
    testthat::fail(paste0(
      "No call in ttl_calls for ",
      paste(missing_call, collapse = ", "),
      "()."
    ))
  }
  c(exports, "lms_chat_batch")
}
ttl_bad_values <- list(
  "300",
  TRUE,
  list(300),
  factor(300),
  numeric(0),
  c(60, 120),
  0,
  0L,
  -5,
  0.5,
  1.5,
  NA_real_,
  NA_integer_,
  NaN,
  Inf,
  -Inf,
  2^31,
  1e22
)
ttl_route_calls <- list(
  lms_chat = function(route) {
    args <- list("a-model", "hi", ttl = 300)
    if (!is.null(route)) args$api_type <- route
    do.call(lms_chat, args)
  },
  lms_chat_batch = function(route) {
    args <- list("a-model", "hi", ttl = 300)
    if (!is.null(route)) args$api_type <- route
    do.call(lms_chat_batch, args)
  }
)
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
  if (!is.null(route)) args$api_type <- route
  do.call(fn, c(args, dots))
}
stream_label <- function(name, route, dots) {
  paste(name, "on", if (is.null(route)) "its route" else route, "with", deparse1(dots))
}
stream_bad_dots <- list(
  list(stream = TRUE),
  list(stream = 1),
  list(stream = 0),
  list(stream = "true"),
  list(stream = "false"),
  list(stream = NA),
  list(stream = logical(0)),
  list(stream = c(FALSE, TRUE)),
  # `utils::modifyList()` and `[[` read the first of two same-named dots. A
  # later bad one is refused by policy, and a first-match check misses it.
  list(stream = FALSE, stream = TRUE)
)
stream_reply <- function(name, route) {
  if (!is.null(route)) {
    name <- paste0("lms_chat_", route)
  }
  switch(
    name,
    lms_chat_openresponses = responses_reply(),
    lms_chat_openai = openai_reply(),
    lms_chat_native = native_reply()
  )
}
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
  rule12 = "You gave a field value that is a function, which jsonlite would send as its source text."
)
good_message <- list(role = "user", content = "hi")
messages_probes <- list(
  list(label = "NULL", value = NULL, rule = "rule1"),
  list(label = "a string", value = "hi", rule = "rule1"),
  list(label = "a character vector", value = c("a", "b"), rule = "rule1"),
  list(label = "a number", value = 5, rule = "rule1"),
  list(label = "NA", value = NA, rule = "rule1"),
  list(label = "a function", value = function() NULL, rule = "rule1"),
  list(
    label = "a data frame of zero rows",
    value = data.frame(role = character(), content = character()),
    rule = "rule2"
  ),
  list(label = "an empty list", value = list(), rule = "rule2"),
  list(
    label = "a fully named list",
    value = list(a = good_message),
    rule = "rule3"
  ),
  list(
    label = "a list whose names are all empty",
    value = structure(list(good_message), names = ""),
    rule = "rule3"
  ),
  list(label = "one unwrapped message", value = good_message, rule = "rule3"),
  list(label = "a string element", value = list("hi"), rule = "rule4"),
  list(
    label = "a named character element",
    value = list(c(role = "user", content = "hi")),
    rule = "rule4"
  ),
  list(
    label = "an unnamed list element",
    value = list(list("user", "hi")),
    rule = "rule4"
  ),
  list(
    label = "a partly named list element",
    value = list(list(role = "user", "hi")),
    rule = "rule4"
  ),
  list(
    label = "a list element with an NA name",
    value = list(structure(list("user", "hi"), names = c("role", NA))),
    rule = "rule4"
  ),
  list(label = "an empty list element", value = list(list()), rule = "rule4"),
  list(
    label = "a data frame element",
    value = list(data.frame(role = "user", content = "hi")),
    rule = "rule4"
  ),
  list(
    label = "a bad element after a good one",
    value = list(good_message, "hi"),
    rule = "rule4"
  ),
  list(
    label = "a POSIXlt element",
    value = list(as.POSIXlt("2026-01-01", tz = "UTC")),
    rule = "rule4"
  ),
  list(
    label = "a classed data frame element",
    value = list(
      structure(data.frame(role = "user"), class = c("foo", "data.frame"))
    ),
    rule = "rule4"
  ),
  # The column rule is checked first, so a data frame with no columns, which
  # also has rows in which every cell is NA, gets the column text alone.
  list(
    label = "a data frame with rows and no columns",
    value = data.frame(row.names = 1:2),
    rule = "rule5"
  ),
  list(
    label = "a data frame with a column named NA",
    value = stats::setNames(
      data.frame(a = "user", b = "hi"),
      c("role", NA)
    ),
    rule = "rule5"
  ),
  list(
    label = "a data frame with a column named \"\"",
    value = stats::setNames(data.frame(a = "user", b = "hi"), c("role", "")),
    rule = "rule5"
  ),
  list(
    label = "a data frame with two columns of the same name",
    value = stats::setNames(
      data.frame(a = "user", b = "hi"),
      c("role", "role")
    ),
    rule = "rule5"
  ),
  list(
    label = "a tibble-classed data frame with no columns",
    value = structure(
      data.frame(row.names = 1L),
      class = c("tbl_df", "tbl", "data.frame")
    ),
    rule = "rule5"
  ),
  list(
    label = "an NA character row first",
    value = data.frame(role = c(NA, "user"), content = c(NA, "hi")),
    rule = "rule6"
  ),
  list(
    label = "a NaN numeric row in the middle",
    value = data.frame(
      role = c("user", NA, "user"),
      n = c(1, NaN, 2)
    ),
    rule = "rule6"
  ),
  list(
    label = "an NA factor row last",
    value = data.frame(
      role = factor(c("user", NA)),
      content = c("hi", NA)
    ),
    rule = "rule6"
  ),
  list(
    label = "an NA Date row",
    value = data.frame(
      role = c("user", NA),
      date = as.Date(c("2026-01-01", NA))
    ),
    rule = "rule6"
  ),
  list(
    label = "an NA list-column row",
    value = local({
      df <- data.frame(role = c("user", NA))
      df$content <- list("hi", NA)
      df
    }),
    rule = "rule6"
  ),
  # The dim rules run before the names rule at their level, so a list array
  # of one dimension with dimnames, which names() reads, gets the dim text.
  list(
    label = "a list-matrix of messages",
    value = matrix(
      list(good_message, good_message, good_message, good_message),
      2
    ),
    rule = "rule7"
  ),
  list(
    label = "a one-dimensional list array",
    value = array(list(good_message, good_message), dim = 2),
    rule = "rule7"
  ),
  list(
    label = "a one-dimensional list array with names",
    value = array(
      list(good_message, good_message),
      dim = 2,
      dimnames = list(c("a", "b"))
    ),
    rule = "rule7"
  ),
  list(
    label = "a message that is a one-dimensional list array with names",
    value = list(
      good_message,
      array(
        list("user", "hi"),
        dim = 2,
        dimnames = list(c("role", "content"))
      )
    ),
    rule = "rule8"
  ),
  # jsonlite writes an NA or empty name under a number and renames a repeated
  # name "a" to "a.1", at the message level and below.
  list(
    label = "a repeated field name in a message",
    value = list(list(role = "user", role = "system", content = "hi")),
    rule = "rule9"
  ),
  list(
    label = "a partly named list in content",
    value = list(list(role = "user", content = list(a = "x", "y"))),
    rule = "rule9"
  ),
  list(
    label = "a list in content whose names are all empty",
    value = list(
      list(role = "user", content = stats::setNames(list("x", "y"), c("", "")))
    ),
    rule = "rule9"
  ),
  list(
    label = "an NA name two levels down",
    value = list(list(
      role = "user",
      content = list(list(type = "text", text = stats::setNames(list("x"), NA)))
    )),
    rule = "rule9"
  ),
  list(
    label = "an I() list with a repeated name",
    value = list(
      good_message,
      list(role = "user", content = I(list(a = "x", a = "y")))
    ),
    rule = "rule9"
  ),
  list(
    label = "a list-column cell with a repeated name",
    value = local({
      df <- data.frame(role = c("user", "user"))
      df$content <- list("hi", list(a = "x", a = "y"))
      df
    }),
    rule = "rule9"
  ),
  list(
    label = "a nested data-frame column with an empty name",
    value = local({
      df <- data.frame(role = "user")
      df$content <- stats::setNames(data.frame(a = "x", b = "y"), c("a", ""))
      df
    }),
    rule = "rule9"
  ),
  # The trial write runs last. Each value below fails it, and the first four
  # also break a rule of their own, which wins.
  list(
    label = "a NULL-cell row and a foo-classed cell",
    value = local({
      df <- data.frame(role = c("user", NA))
      df$content <- list(structure("x", class = "foo"), NULL)
      df
    }),
    rule = "rule6"
  ),
  list(
    label = "a list-matrix with an environment field",
    value = matrix(
      list(list(role = "user", content = new.env()), good_message),
      1
    ),
    rule = "rule7"
  ),
  list(
    label = "a list-array message with an environment field",
    value = list(
      array(list("user", new.env()), 2, list(c("role", "content")))
    ),
    rule = "rule8"
  ),
  list(
    label = "a repeated name and an environment field",
    value = list(list(role = "user", role = "system", content = new.env())),
    rule = "rule9"
  ),
  list(
    label = "a foo-classed field",
    value = list(list(role = "user", content = structure("x", class = "foo"))),
    rule = "rule10"
  ),
  list(
    label = "foo-classed content parts",
    value = list(list(
      role = "user",
      content = structure(list(list(type = "text", text = "x")), class = "foo")
    )),
    rule = "rule10"
  ),
  list(
    label = "a foo-classed data-frame column",
    value = local({
      df <- data.frame(content = "hi")
      df$role <- structure("user", class = "foo")
      df
    }),
    rule = "rule10"
  ),
  list(
    label = "an environment field",
    value = list(list(role = "user", content = new.env())),
    rule = "rule10"
  ),
  list(
    label = "a quote() field",
    value = list(list(role = "user", content = quote(x))),
    rule = "rule10"
  ),
  # A NULL list cell is written as null, the same as an NA cell.
  list(
    label = "a row of NA and a NULL list cell",
    value = local({
      df <- data.frame(role = c("user", NA))
      df$content <- list("hi", NULL)
      df
    }),
    rule = "rule6"
  ),
  list(
    label = "a row of NA and a NULL cell in an I() list column",
    value = local({
      df <- data.frame(role = c(NA, "user"))
      df$content <- I(list(NULL, "hi"))
      df
    }),
    rule = "rule6"
  ),
  list(
    label = "a row of NA, an NA matrix row, and a NULL list cell",
    value = local({
      df <- data.frame(role = c("user", NA))
      df$m <- matrix(c(1, NA, 2, NA), 2)
      df$content <- list("hi", NULL)
      df
    }),
    rule = "rule6"
  ),
  list(
    label = "a row of NA and a list-matrix row of NULL cells",
    value = local({
      df <- data.frame(role = c("user", NA))
      df$m <- matrix(list(1, NULL, 2, NULL), 2)
      df
    }),
    rule = "rule6"
  ),
  list(
    label = "a row of NA and a NULL list cell in a nested data frame",
    value = local({
      inner <- data.frame(a = c(1, NA))
      inner$b <- list(1, NULL)
      df <- data.frame(role = c("user", NA))
      df$sub <- inner
      df
    }),
    rule = "rule6"
  ),
  list(
    label = "a data frame of one NA row",
    value = data.frame(role = NA_character_, content = NA_character_),
    rule = "rule6"
  ),
  list(
    label = "a foo-classed data frame with an NA row",
    value = structure(
      data.frame(role = c("user", NA), content = c("hi", NA)),
      class = c("foo", "data.frame")
    ),
    rule = "rule6"
  ),
  # jsonlite writes a list with a dim inside a message as nested arrays with
  # each cell boxed. The rule runs before the names rule, so repeated
  # dimnames, which names() reads, get the dim text.
  list(
    label = "a list-matrix field",
    value = list(list(role = "user", content = matrix(list(1, 2, 3, 4), 2))),
    rule = "rule11"
  ),
  list(
    label = "a one-dimensional list array field",
    value = list(list(role = "user", content = array(list("a", "b"), 2))),
    rule = "rule11"
  ),
  list(
    label = "a three-dimensional list array field",
    value = list(
      list(role = "user", content = array(as.list(1:8), c(2, 2, 2)))
    ),
    rule = "rule11"
  ),
  list(
    label = "a list array field with repeated dimnames",
    value = list(list(
      role = "user",
      content = array(list("a", "b"), 2, list(c("x", "x")))
    )),
    rule = "rule11"
  ),
  list(
    label = "a list array inside a list field",
    value = list(list(
      role = "user",
      content = list(list(type = "text", text = array(list("a"), 1)))
    )),
    rule = "rule11"
  ),
  list(
    label = "a list array in a list-column cell",
    value = local({
      df <- data.frame(role = c("user", "user"))
      df$content <- list("hi", matrix(list(1, 2), 1))
      df
    }),
    rule = "rule11"
  ),
  list(
    label = "a one-dimensional list-array column",
    value = local({
      df <- data.frame(role = c("user", "user"))
      df$content <- array(list("a", "b"), 2)
      df
    }),
    rule = "rule11"
  ),
  list(
    label = "a three-dimensional list-array column",
    value = local({
      df <- data.frame(role = c("user", "user"))
      df$content <- array(as.list(1:8), c(2, 2, 2))
      df
    }),
    rule = "rule11"
  ),
  list(
    label = "a list array in a list-column cell of a data-frame field",
    value = list(list(
      role = "user",
      content = local({
        inner <- data.frame(a = 1)
        inner$b <- list(array(list("x"), 1))
        inner
      })
    )),
    rule = "rule11"
  ),
  # jsonlite writes a function as an array of its source lines, with no error.
  list(
    label = "a closure field",
    value = list(list(role = "user", content = function(x) x)),
    rule = "rule12"
  ),
  list(
    label = "a primitive field",
    value = list(list(role = "user", content = sum)),
    rule = "rule12"
  ),
  list(
    label = "a function inside a list field",
    value = list(list(
      role = "user",
      content = list(list(type = "text", text = function() "x"))
    )),
    rule = "rule12"
  ),
  list(
    label = "a function in a list-column cell",
    value = local({
      df <- data.frame(role = c("user", "user"))
      df$content <- list("hi", mean)
      df
    }),
    rule = "rule12"
  ),
  list(
    label = "a function in a list-matrix column cell",
    value = local({
      df <- data.frame(role = c("user", "user"))
      df$m <- matrix(list(1, sum, 2, 3), 2)
      df
    }),
    rule = "rule12"
  ),
  list(
    label = "a function as a data-frame column",
    value = local({
      df <- data.frame(role = "user")
      df$content <- function() "x"
      df
    }),
    rule = "rule12"
  ),
  list(
    label = "a function column in a nested data frame",
    value = local({
      inner <- data.frame(a = 1)
      inner$f <- function() "x"
      df <- data.frame(role = "user")
      df$sub <- inner
      df
    }),
    rule = "rule12"
  ),
  # A function with a class jsonlite has no method for gets the function
  # rule, which runs before the trial write.
  list(
    label = "a foo-classed function field",
    value = list(
      list(role = "user", content = structure(function() "x", class = "foo"))
    ),
    rule = "rule12"
  ),
  # The rules before the function rule win.
  list(
    label = "a function and a repeated name",
    value = list(list(role = "user", role = "system", content = sum)),
    rule = "rule9"
  ),
  list(
    label = "a list-matrix field that holds a function",
    value = list(list(role = "user", content = matrix(list(sum, 1), 1))),
    rule = "rule11"
  )
)

# test -------------------------------------------------------------------------
probe <- local_counting_probe()
top <- data.frame(role = "user")
top$content <- function() "x"
inner <- data.frame(a = 1)
inner$f <- function() "x"
nested <- data.frame(role = "user")
nested$sub <- inner
for (value in list(top, nested)) {
    expect_no_warning(
      expect_error(
        lms_chat_openai("a-model", value),
        messages_rule_details[["rule12"]],
        fixed = TRUE
      )
    )
  }
