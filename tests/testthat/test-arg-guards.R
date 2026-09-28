# Which exported functions must guard which argument is read from the package
# NAMESPACE rather than from a list written here. A wrapper added later joins
# the domain on its own, which a hand-written list of names would not do.

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

# Force the server probe to succeed and make any request raise. What is left is
# the guard: an abort carrying one of its details can only have come from it.
# The one exception is the omitted-argument test below, whose abort is R's own
# missing-argument error, raised when the guard forces the promise.
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

test_that("the guarded domains are read from NAMESPACE and are not empty", {
  id_domain <- guarded_exports(c("model", "job_id"))
  text_domain <- guarded_exports(c("input", "inputs"))

  expect_gt(length(id_domain), 0)
  expect_gt(length(text_domain), 0)
  # Named here as a record of what the enumeration found on the day this was
  # written, never as the source of the domain. A new wrapper turns this red,
  # which is the signal to check that it carries a guard.
  expect_setequal(
    id_domain,
    c(
      "lms_chat",
      "lms_chat_batch",
      "lms_chat_native",
      "lms_chat_openai",
      "lms_chat_openresponses",
      "lms_download",
      "lms_download_status",
      "lms_embed",
      "lms_load",
      "lms_unload"
    )
  )
  expect_setequal(
    text_domain,
    c(
      "lms_chat",
      "lms_chat_batch",
      "lms_chat_native",
      "lms_chat_openresponses",
      "lms_embed"
    )
  )
})

test_that("every enumerated function has a placeholder for each required argument", {
  for (name in guarded_exports(c("model", "job_id", "input", "inputs"))) {
    expect_type(baseline_args(name), "list")
  }
})

test_that("a missing placeholder fails the test rather than skipping it", {
  expect_failure(
    baseline_args("lms_embed", table = list(model = "a-model")),
    "No placeholder for the required argument"
  )
  expect_failure(baseline_args("lms_embed", table = list()))
})

test_that("a bad model or job id aborts, named, before any request", {
  local_guard_only()

  for (name in guarded_exports(c("model", "job_id"))) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- baseline_args(name)
    target <- intersect(c("model", "job_id"), names(args))[[1]]

    for (probe in id_probes) {
      bad <- args
      bad[target] <- list(probe$value)
      expect_error(
        do.call(fn, bad),
        probe$match,
        info = paste(name, "with", probe$label, "by name")
      )
      expect_error(
        do.call(fn, bad),
        target,
        info = paste(name, "with", probe$label, "names the argument")
      )

      # The same value supplied positionally. Every function in this domain
      # carries the guarded argument first.
      expect_identical(names(formals(fn))[[1]], target)
      positional <- c(list(probe$value), bad[setdiff(names(bad), target)])
      expect_error(
        do.call(fn, positional),
        probe$match,
        info = paste(name, "with", probe$label, "positionally")
      )
    }
  }
})

# This one is not a test of the guards. R raises its own missing-argument
# error when the guard forces the promise, and that error already names the
# argument, so the guard could be deleted and this would still pass. It is
# kept because it pins the weaker fact the guards rely on: omitting the
# argument never reaches the request.
test_that("omitting the guarded identifier reaches no request, whoever aborts", {
  local_guard_only()

  for (name in guarded_exports(c("model", "job_id"))) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- baseline_args(name)
    target <- intersect(c("model", "job_id"), names(args))[[1]]
    err <- expect_error(
      do.call(fn, args[setdiff(names(args), target)]),
      target,
      info = paste(name, "without", target)
    )
    expect_no_match(
      conditionMessage(err),
      "a request left the process",
      info = paste(name, "without", target, "reached a request")
    )
  }
})

test_that("an argument fault aborts even when the server is down", {
  # `local_guard_only()` forces the server probe to succeed, so it cannot see
  # this. The guards now run above `stop_if_no_server()`, which means a bad
  # argument beats the server-down abort. Nothing else pins that order.
  local_no_request_allowed()
  testthat::local_mocked_bindings(
    is_server_running = function(...) FALSE
  )

  for (name in guarded_exports(c("model", "job_id"))) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- baseline_args(name)
    target <- intersect(c("model", "job_id"), names(args))[[1]]
    bad <- args
    bad[target] <- list("")
    err <- expect_error(
      do.call(fn, bad),
      "an empty string",
      info = paste(name, "with a bad", target, "and no server")
    )
    expect_false(
      inherits(err, "rlmstudio_no_server"),
      info = paste(name, "raised the server condition rather than the guard")
    )
  }
})

# The split between the two text rules is what the plan gate settled, so it is
# written out here. The enumeration above is what catches a sixth function
# arriving with an `input` formal: its domain assertion turns red.
strict_text <- list(
  lms_embed = "input",
  lms_chat_batch = "inputs"
)
loose_text <- list(
  lms_chat = "input",
  lms_chat_openresponses = "input",
  lms_chat_native = "input"
)

test_that("the two text rules together cover the whole text domain", {
  expect_setequal(
    c(names(strict_text), names(loose_text)),
    guarded_exports(c("input", "inputs"))
  )
})

test_that("a text vector argument must be a non-empty character vector", {
  local_guard_only()

  for (name in names(strict_text)) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    target <- strict_text[[name]]
    args <- baseline_args(name)

    bad_values <- list(1:3, list("a"), TRUE, character(0), NULL, factor("a"))
    for (bad_value in bad_values) {
      bad <- args
      bad[target] <- list(bad_value)
      expect_error(
        do.call(fn, bad),
        "non-empty character vector",
        info = paste(name, "with", class(bad_value)[[1]])
      )
      expect_error(do.call(fn, bad), target, info = name)
    }
  }
})

test_that("an NA anywhere in a text vector argument aborts", {
  local_guard_only()

  na_probes <- list(
    list(label = "alone", value = NA_character_, match = "1 NA value\\."),
    list(label = "first", value = c(NA, "b", "c"), match = "1 NA value\\."),
    list(label = "middle", value = c("a", NA, "c"), match = "1 NA value\\."),
    list(label = "last", value = c("a", "b", NA), match = "1 NA value\\."),
    list(
      label = "all",
      value = c(NA_character_, NA_character_),
      match = "2 NA values\\."
    )
  )

  for (name in c(names(strict_text), names(loose_text))) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    target <- c(strict_text, loose_text)[[name]]
    args <- baseline_args(name)

    for (probe in na_probes) {
      bad <- args
      bad[target] <- list(probe$value)
      expect_error(
        do.call(fn, bad),
        probe$match,
        info = paste(name, "with NA", probe$label)
      )
      expect_error(
        do.call(fn, bad),
        target,
        info = paste(name, "with NA", probe$label, "names the argument")
      )
    }
  }
})

# `lms_chat()` delegates to `lms_chat_openresponses()` and to
# `lms_chat_native()`, and both re-check what it checked, so the probes above
# stay green with the guards in `lms_chat()` itself deleted. The `openai` route
# is the exception: `lms_chat_openai()` does not check `input`, which
# it never takes, so the check in `lms_chat()` is the only one on that path. These probes are what make it
# load-bearing.
test_that("the openai route of lms_chat() carries its own guards", {
  local_guard_only()

  expect_error(
    lms_chat("a-model", c("a", NA), api_type = "openai"),
    "1 NA value\\."
  )
  expect_error(
    lms_chat("a-model", c("a", NA), api_type = "openai"),
    "input"
  )
  expect_error(
    lms_chat(c("a", "b"), "a prompt", api_type = "openai"),
    "2 values rather than one"
  )
  # A clean call on the same route must reach the request mock. Without this
  # the two probes above would also pass if the route were simply broken.
  expect_error(
    lms_chat("a-model", "a prompt", api_type = "openai"),
    "a request left the process"
  )
})

test_that("the chat wrappers pass a non-character input through to the server", {
  local_guard_only()

  structured <- list(list(role = "user", content = "a prompt"))

  for (name in names(loose_text)) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- baseline_args(name)
    args["input"] <- list(structured)
    # Reaching the request mock is the proof: the guard let the value past.
    expect_error(
      do.call(fn, args),
      "a request left the process",
      info = paste(name, "with a structured input")
    )
  }
})

# The functions that take `schema`, directly or through `...`, and a call to
# each that is valid apart from `schema`. `api_type = "openai"` keeps the route
# check out of the way for the two that route, so a form fault is the only
# fault in each call.
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

# A server probe that reports a stopped server and counts its calls. A test
# that reaches it gets `rlmstudio_no_server`, and the count says so even where
# `expect_error()` would accept that condition (LESSONS, M015).
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

test_that("a schema in the wrong form aborts before the server probe", {
  probe <- local_counting_probe()

  for (name in names(schema_calls)) {
    call <- schema_calls[[name]]
    for (p in schema_probes) {
      err <- expect_error(
        call(schema = p$value),
        p$match,
        info = paste(name, "with", p$label)
      )
      expect_match(conditionMessage(err), "schema", info = name)
      expect_false(
        inherits(err, "rlmstudio_no_server"),
        info = paste(name, "with", p$label)
      )
      # No package class on an argument fault (D-008).
      expect_false(
        any(grepl("^rlmstudio_", class(err))),
        info = paste(name, "with", p$label)
      )
    }
  }
  expect_identical(probe$calls, 0L)
})

test_that("a schema with a response_format in the dots aborts before the probe", {
  probe <- local_counting_probe()

  for (name in names(schema_calls)) {
    err <- expect_error(
      schema_calls[[name]](
        schema = list(type = "object"),
        response_format = list(type = "json_object")
      ),
      "not both",
      info = name
    )
    expect_false(any(grepl("^rlmstudio_", class(err))), info = name)
  }
  expect_identical(probe$calls, 0L)
})

test_that("a valid schema passes the form check and reaches the server probe", {
  probe <- local_counting_probe()

  valid <- list(
    list(type = "object", properties = list(score = list(type = "integer"))),
    list(),
    NULL
  )
  for (name in names(schema_calls)) {
    for (value in valid) {
      expect_error(
        schema_calls[[name]](schema = value),
        class = "rlmstudio_no_server",
        info = name
      )
    }
  }
  expect_identical(probe$calls, length(schema_calls) * length(valid))
})

# The two functions that route, each called with a valid schema. `api_type` is
# left out when `route` is NULL, so the default route is probed as the caller
# would meet it.
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

test_that("a schema on a route other than openai aborts before the probe", {
  probe <- local_counting_probe()

  for (name in names(route_calls)) {
    for (route in list("openresponses", "native", NULL)) {
      label <- paste(name, "with", if (is.null(route)) "the default" else route)
      err <- expect_error(
        route_calls[[name]](route),
        'api_type = "openai"',
        fixed = TRUE,
        info = label
      )
      expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
    }
  }
  expect_identical(probe$calls, 0L)
})

test_that("the form check runs before the route check", {
  probe <- local_counting_probe()

  # The default route is not openai, so both checks have a fault to report.
  expect_error(lms_chat("a-model", "hi", schema = "object"), "a character value")
  expect_error(
    lms_chat_batch("a-model", "hi", schema = "object"),
    "a character value"
  )
  expect_identical(probe$calls, 0L)
})

test_that("a batch format that simplify = FALSE cannot fill aborts before the server probe", {
  probe <- local_counting_probe()

  err <- expect_error(
    lms_chat_batch("a-model", "hi", format = "data.frame", simplify = FALSE),
    "requires"
  )
  expect_match(conditionMessage(err), "simplify = TRUE", fixed = TRUE)
  # No package class on an argument fault (D-008).
  expect_false(any(grepl("^rlmstudio_", class(err))))

  err <- expect_error(
    lms_chat_batch("a-model", "hi", format = "table"),
    "should be one of"
  )
  expect_false(any(grepl("^rlmstudio_", class(err))))
  expect_identical(probe$calls, 0L)

  # The same call with a format that simplify = FALSE can fill reaches it.
  expect_error(
    lms_chat_batch("a-model", "hi", format = "list", simplify = FALSE),
    class = "rlmstudio_no_server"
  )
  expect_identical(probe$calls, 1L)
})

# A call to each function that takes `ttl`, valid apart from `ttl`, keyed by
# function name. `lms_chat_batch()` takes it through `...`, so the NAMESPACE
# enumeration below cannot find it, and it is added by hand. The two routing
# functions are called on the openai route, so a value fault is the only fault.
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

# The functions whose `ttl` is checked: every export with a `ttl` formal, read
# from NAMESPACE, and `lms_chat_batch()`. An export with no call above fails
# the test rather than leaving the domain.
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

test_that("the ttl domain is read from NAMESPACE and is not empty", {
  domain <- ttl_domain()
  # A record of what the enumeration found on the day this was written, never
  # the source of the domain.
  expect_setequal(
    domain,
    c("lms_chat", "lms_chat_batch", "lms_chat_openai", "lms_embed")
  )
})

test_that("a ttl that is not one whole number in range aborts before the probe", {
  probe <- local_counting_probe()

  for (name in ttl_domain()) {
    for (value in ttl_bad_values) {
      label <- paste(name, "with", deparse(value))
      err <- expect_error(
        ttl_calls[[name]](ttl = value),
        "must be one whole number",
        info = label
      )
      expect_match(conditionMessage(err), "ttl", info = label)
      # No package class on an argument fault (D-008).
      expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
    }
  }
  expect_identical(probe$calls, 0L)
})

test_that("a valid ttl passes the value check and reaches the server probe", {
  probe <- local_counting_probe()

  valid <- list(NULL, 1, 300L, .Machine$integer.max)
  domain <- ttl_domain()
  for (name in domain) {
    for (value in valid) {
      expect_error(
        ttl_calls[[name]](ttl = value),
        class = "rlmstudio_no_server",
        info = paste(name, "with", deparse(value))
      )
    }
  }
  expect_identical(probe$calls, length(domain) * length(valid))
})

# The two functions that route, each called with a valid ttl. `api_type` is
# left out when `route` is NULL, so the default route is probed as the caller
# would meet it.
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

test_that("a ttl on a route other than openai aborts before the probe", {
  probe <- local_counting_probe()

  for (name in names(ttl_route_calls)) {
    for (route in list("openresponses", "native", NULL)) {
      label <- paste(name, "with", if (is.null(route)) "the default" else route)
      err <- expect_error(
        ttl_route_calls[[name]](route),
        'api_type = "openai"',
        fixed = TRUE,
        info = label
      )
      expect_match(conditionMessage(err), "ttl", info = label)
      expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
    }
  }
  expect_identical(probe$calls, 0L)
})

test_that("the ttl value check runs before the route check", {
  probe <- local_counting_probe()

  expect_error(
    lms_chat("a-model", "hi", api_type = "native", ttl = "300"),
    "must be one whole number"
  )
  expect_error(
    lms_chat_batch("a-model", "hi", api_type = "native", ttl = "300"),
    "must be one whole number"
  )
  expect_identical(probe$calls, 0L)
})

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

test_that("the stream domain is read from NAMESPACE and is not empty", {
  # A record of what the enumeration found when this was written, never the
  # source of the domain. A new chat function turns this red.
  expect_setequal(
    stream_domain(),
    c(
      "lms_chat",
      "lms_chat_batch",
      "lms_chat_native",
      "lms_chat_openai",
      "lms_chat_openresponses"
    )
  )
})

test_that("a stream other than FALSE or NULL aborts before the server probe", {
  probe <- local_counting_probe()

  for (name in stream_domain()) {
    for (route in stream_routes(name)) {
      for (dots in stream_bad_dots) {
        label <- stream_label(name, route, dots)
        err <- expect_error(
          stream_call(name, route, dots),
          "must be `FALSE` or `NULL`",
          fixed = TRUE,
          info = label
        )
        expect_match(conditionMessage(err), "stream", info = label)
        expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
      }
    }
  }
  expect_identical(probe$calls, 0L)
})

# A reply that the route of `name` reads as text.
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

test_that("stream = FALSE is sent and stream = NULL is left out", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  for (name in stream_domain()) {
    for (route in stream_routes(name)) {
      for (value in list(FALSE, NULL)) {
        dots <- list(stream = value)
        label <- stream_label(name, route, dots)
        recorder <- local_request_recorder(
          mock_response(200L, stream_reply(name, route))
        )
        expect_no_error(stream_call(name, route, dots))
        expected <- if (identical(name, "lms_chat_batch")) 2L else 1L
        expect_identical(length(recorder$requests), expected, info = label)
        for (req in recorder$requests) {
          body <- request_target(req)$body
          if (is.null(value)) {
            expect_false("stream" %in% names(body), info = label)
          } else {
            expect_identical(body[["stream"]], FALSE, info = label)
          }
        }
      }
    }
  }
})

test_that("a FALSE with names or attributes passes, as isFALSE() reads it", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  for (value in list(c(a = FALSE), structure(FALSE, foo = 1))) {
    label <- deparse1(value)
    recorder <- local_request_recorder(mock_response(200L, openai_reply()))
    expect_no_error(
      lms_chat_openai("a-model", arg_placeholders$messages, stream = value)
    )
    expect_identical(length(recorder$requests), 1L, info = label)
    body <- request_target(recorder$requests[[1]])$body
    expect_identical(body[["stream"]], FALSE, info = label)
  }
})

test_that("a long stream value is cut short in the message", {
  probe <- local_counting_probe()

  err <- expect_error(
    lms_chat_openai(
      "a-model",
      arg_placeholders$messages,
      stream = seq_len(1000) + 0.5
    ),
    "must be `FALSE` or `NULL`",
    fixed = TRUE
  )
  expect_lt(nchar(conditionMessage(err)), 300)
  expect_match(conditionMessage(err), "...", fixed = TRUE)
  expect_identical(probe$calls, 0L)
})


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
  rule12 = "You gave a field value that is a function, which jsonlite would send as its source text."
)

# The function rule and the trial-write rule report a value fault under their
# own header, with no hint. Every other rule reports a shape fault.
messages_value_rules <- c("rule10", "rule12")
messages_headers <- c(
  shape = "`messages` must be a data frame or an unnamed list of messages.",
  value = "`messages` holds a field value that cannot be sent as JSON."
)
messages_shape_hint <- "Each message is a named list"

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

test_that("a messages value that breaks a rule aborts before the server probe", {
  probe <- local_counting_probe()

  for (p in messages_probes) {
    err <- expect_error(
      lms_chat_openai("a-model", p$value),
      messages_rule_details[[p$rule]],
      fixed = TRUE,
      info = p$label
    )
    expect_match(conditionMessage(err), "`messages`", fixed = TRUE, info = p$label)
    # The header of the rule's kind opens the message, and the other kind's
    # header is absent. Only a shape fault carries the named-list hint.
    kind <- if (p$rule %in% messages_value_rules) "value" else "shape"
    expect_true(
      startsWith(conditionMessage(err), messages_headers[[kind]]),
      info = p$label
    )
    expect_no_match(
      conditionMessage(err),
      messages_headers[[setdiff(names(messages_headers), kind)]],
      fixed = TRUE,
      info = p$label
    )
    if (kind == "shape") {
      expect_match(
        conditionMessage(err),
        messages_shape_hint,
        fixed = TRUE,
        info = p$label
      )
    } else {
      expect_no_match(
        conditionMessage(err),
        messages_shape_hint,
        fixed = TRUE,
        info = p$label
      )
    }
    # No package class on an argument fault (D-008).
    expect_identical(
      class(err),
      c("rlang_error", "error", "condition"),
      info = p$label
    )
    # The detail of every other rule is absent, so the abort names one rule.
    for (other in setdiff(names(messages_rule_details), p$rule)) {
      expect_no_match(
        conditionMessage(err),
        messages_rule_details[[other]],
        fixed = TRUE,
        info = paste(p$label, "names", other)
      )
    }
  }
  expect_identical(probe$calls, 0L)
})

test_that("a function column aborts with no warning on the way", {
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
  expect_identical(probe$calls, 0L)
})

# A column that is neither an atomic vector nor a list is never empty, and
# is.na() is not called on it, so it gives no warning. Each column sits in
# rows that are otherwise NA, so the empty-row rule would win if the column
# counted as empty. `$<-` builds the frame where it accepts the value. It
# refuses an environment at any row count, so that frame uses structure().
test_that("a column that is not a vector is not empty and gives no warning", {
  probe <- local_counting_probe()
  s4_env <- new.env()
  s4_class <- methods::setClass(
    "rlmstudioM042Probe",
    representation(v = "numeric"),
    where = s4_env
  )
  na_frame <- function(n, column) {
    df <- data.frame(role = rep(NA_character_, n))
    df$x <- column
    df
  }

  cases <- list(
    "an environment" = structure(
      list(role = NA_character_, x = new.env()),
      class = "data.frame",
      row.names = 1L
    ),
    "a formula" = na_frame(3L, y ~ x),
    "a symbol" = na_frame(1L, quote(x)),
    "a call" = na_frame(2L, quote(f(x))),
    "an S4 object" = na_frame(1L, s4_class(v = 1)),
    "an external pointer" = na_frame(1L, methods::new("externalptr")),
    "an expression vector" = na_frame(1L, expression(1)),
    "a symbol in a data-frame column" = local({
      inner <- na_frame(1L, quote(x))
      df <- data.frame(role = NA_character_)
      df$sub <- inner
      df
    })
  )

  for (label in names(cases)) {
    err <- expect_no_warning(
      expect_error(
        lms_chat_openai("a-model", cases[[label]]),
        messages_rule_details[["rule10"]],
        fixed = TRUE,
        info = label
      )
    )
    expect_true(
      startsWith(conditionMessage(err), messages_headers[["value"]]),
      info = label
    )
  }

  expect_error(
    lms_chat_openai("a-model", na_frame(1L, function() "x")),
    messages_rule_details[["rule12"]],
    fixed = TRUE
  )
  expect_identical(probe$calls, 0L)
})

# A column with a dim attribute is read row by row, through the cells whose
# first index is the row. The frames are built with `$<-`, because
# data.frame() recycles an array to its length. Row 2 of `role` is NA, so the
# array column alone decides whether row 2 is empty. An outcome of "server"
# means the value passes every messages rule and reaches the server probe.
dim_column_frame <- function(column) {
  df <- data.frame(role = c("user", NA))
  df$x <- column
  df
}

test_that("a column with a dim attribute is read row by row", {
  # Row 2 of a c(2, 2, 2) array holds the cells at odd positions 2, 4, 6, 8.
  row2_cells <- c(2L, 4L, 6L, 8L)
  one_null_list3 <- as.list(1:8)
  one_null_list3[2L] <- list(NULL)
  all_null_list3 <- as.list(1:8)
  all_null_list3[row2_cells] <- list(NULL)
  one_na_atomic3 <- replace(1:8, 2L, NA)
  all_na_atomic3 <- replace(1:8, row2_cells, NA)
  one_null_list4 <- as.list(1:16)
  one_null_list4[4L] <- list(NULL)

  nested_one_na <- local({
    inner <- data.frame(a = c(1, NA))
    inner$x <- array(one_na_atomic3, c(2, 2, 2))
    df <- data.frame(role = c("user", NA))
    df$sub <- inner
    df
  })
  nested_all_na <- local({
    inner <- data.frame(a = c(1, NA))
    inner$x <- array(all_na_atomic3, c(2, 2, 2))
    df <- data.frame(role = c("user", NA))
    df$sub <- inner
    df
  })

  cases <- list(
    list(
      label = "a 3-D list column with one NULL cell in row 2",
      value = dim_column_frame(array(one_null_list3, c(2, 2, 2))),
      outcome = "rule11"
    ),
    list(
      label = "a 3-D atomic column with one NA cell in row 2",
      value = dim_column_frame(array(one_na_atomic3, c(2, 2, 2))),
      outcome = "server"
    ),
    list(
      label = "a 3-D atomic column with NA in every cell of row 2",
      value = dim_column_frame(array(all_na_atomic3, c(2, 2, 2))),
      outcome = "rule6"
    ),
    list(
      label = "a 3-D list column with NULL in every cell of row 2",
      value = dim_column_frame(array(all_null_list3, c(2, 2, 2))),
      outcome = "rule6"
    ),
    list(
      label = "a 4-D list column with one NULL cell in row 2",
      value = dim_column_frame(array(one_null_list4, c(2, 2, 2, 2))),
      outcome = "rule11"
    ),
    list(
      label = "a 3-D atomic column with one NA cell in a nested data frame",
      value = nested_one_na,
      outcome = "server"
    ),
    list(
      label = "a 3-D atomic column with an NA row in a nested data frame",
      value = nested_all_na,
      outcome = "rule6"
    ),
    # Controls whose result the change leaves as it was.
    list(
      label = "a 2-D atomic column with one NA cell in row 2",
      value = dim_column_frame(matrix(c(1, 2, 3, NA), 2)),
      outcome = "server"
    ),
    list(
      label = "a 1-D atomic column with NA in row 2",
      value = dim_column_frame(array(c("a", NA), 2)),
      outcome = "rule6"
    ),
    list(
      label = "a 1-D list column with NULL in row 2",
      value = dim_column_frame(array(list("a", NULL), 2)),
      outcome = "rule6"
    )
  )

  for (case in cases) {
    probe <- local_counting_probe()
    if (case$outcome == "server") {
      expect_error(
        lms_chat_openai("a-model", case$value),
        class = "rlmstudio_no_server",
        info = case$label
      )
      expect_identical(probe$calls, 1L, info = case$label)
    } else {
      err <- expect_error(
        lms_chat_openai("a-model", case$value),
        messages_rule_details[[case$outcome]],
        fixed = TRUE,
        info = case$label
      )
      other <- setdiff(c("rule6", "rule11"), case$outcome)
      expect_no_match(
        conditionMessage(err),
        messages_rule_details[[other]],
        fixed = TRUE,
        info = case$label
      )
      expect_identical(probe$calls, 0L, info = case$label)
    }
  }
})

# The messages field of the body a captured request sends, parsed back with no
# simplification, so a list of objects stays a list of lists.
sent_messages <- function(req) {
  require_httpuv()
  out <- httr2::req_dry_run(req, quiet = TRUE, redact_headers = FALSE)
  jsonlite::parse_json(rawToChar(out$body), simplifyVector = FALSE)$messages
}

first_msg <- list(role = "system", content = "Be brief.")
later_msg <- list(role = "user", content = "hi")
classed_sent <- list(first_msg, later_msg)
class_forms <- list(
  "an S3 class" = function(x) structure(x, class = "foo"),
  "a class vector of two entries" = function(x) {
    structure(x, class = c("foo", "bar"))
  },
  "the class \"list\"" = function(x) structure(x, class = "list"),
  "I()" = function(x) I(x)
)

test_that("a messages value that keeps every rule reaches the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  passes <- list(
    list(
      label = "a data frame with role and content",
      value = data.frame(
        role = c("system", "user"),
        content = c("Be brief.", "hi")
      ),
      sent = list(
        list(role = "system", content = "Be brief."),
        list(role = "user", content = "hi")
      )
    ),
    list(
      label = "a data frame with one column x",
      value = data.frame(x = "a"),
      sent = list(list(x = "a"))
    ),
    list(
      label = "string content",
      value = list(list(role = "user", content = "hi")),
      sent = list(list(role = "user", content = "hi"))
    ),
    list(
      label = "content parts",
      value = list(
        list(role = "user", content = list(list(type = "text", text = "hi")))
      ),
      sent = list(
        list(role = "user", content = list(list(type = "text", text = "hi")))
      )
    ),
    list(
      label = "number content",
      value = list(list(role = "user", content = 5)),
      sent = list(list(role = "user", content = 5L))
    ),
    list(
      label = "an I() field, sent as an array",
      value = list(list(role = I("user"), content = "hi")),
      sent = list(list(role = list("user"), content = "hi"))
    ),
    list(
      label = "a data frame with an NA cell in every row",
      value = data.frame(
        role = c("user", "user"),
        content = c(NA, "hi"),
        name = c("a", NA)
      ),
      sent = list(
        list(role = "user", name = "a"),
        list(role = "user", content = "hi")
      )
    ),
    list(
      label = "a data frame row with one cell that is not NA",
      value = data.frame(role = c("user", NA), content = c("hi", "yo")),
      sent = list(list(role = "user", content = "hi"), list(content = "yo"))
    ),
    # A list() cell is written as [] and a list(NA) cell as [null]. Both are
    # field values, so such a row is not empty.
    list(
      label = "a row of NA and a list() cell",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$content <- list("hi", list())
        df
      }),
      sent = list(list(role = "user", content = "hi"), list(content = list()))
    ),
    list(
      label = "a fully named nested list",
      value = list(list(role = "user", content = list(a = "x", b = "y"))),
      sent = list(list(role = "user", content = list(a = "x", b = "y")))
    ),
    list(
      label = "an unnamed nested list",
      value = list(list(role = "user", content = list("x", "y"))),
      sent = list(list(role = "user", content = list("x", "y")))
    ),
    # jsonlite does not write the names of a list column, so they are not
    # read, even when one of them is empty.
    list(
      label = "a list column with names, one of them empty",
      value = local({
        df <- data.frame(role = c("user", "user"))
        df$content <- list(p = "hi", "yo")
        stopifnot(identical(names(df$content), c("p", "")))
        df
      }),
      sent = list(
        list(role = "user", content = "hi"),
        list(role = "user", content = "yo")
      )
    ),
    # is.na() on the whole data frame spreads the matrix over two columns, so
    # a rule that reads it by column position looks at the wrong cells.
    list(
      label = "a NULL list cell after a matrix column, and a later value",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$m <- matrix(c(1, NA, 2, NA), 2)
        df$content <- list("hi", NULL)
        df$name <- c("a", "b")
        df
      }),
      sent = list(
        list(role = "user", m = list(1L, 2L), content = "hi", name = "a"),
        list(m = list("NA", "NA"), content = NULL, name = "b")
      )
    ),
    list(
      label = "a row of NA and a list(NA) cell",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$content <- list("hi", list(NA))
        df
      }),
      sent = list(
        list(role = "user", content = "hi"),
        list(content = list(NULL))
      )
    ),
    # A list-matrix column is read per row, so a NULL cell beside a value in
    # the same row leaves the row with a field value.
    list(
      label = "a row of NA and a list-matrix row with one value",
      value = local({
        df <- data.frame(role = c("user", NA))
        df$m <- matrix(list(1, NULL, NULL, 2), 2)
        df
      }),
      sent = list(
        list(role = "user", m = list(list(1L), NULL)),
        list(m = list(NULL, list(2L)))
      )
    ),
    list(
      label = "a tibble-classed data frame",
      value = structure(
        data.frame(role = c("system", "user"), content = c("Be brief.", "hi")),
        class = c("tbl_df", "tbl", "data.frame")
      ),
      sent = classed_sent
    ),
    list(
      label = "a foo-classed data frame",
      value = structure(
        data.frame(role = c("system", "user"), content = c("Be brief.", "hi")),
        class = c("foo", "data.frame")
      ),
      sent = classed_sent
    )
  )
  # A class on the outer list or on a message is removed before the body is
  # built. Each form sits at the outer level and on a later message, and one
  # S3 class also sits on the first message and on both levels at once.
  for (form in names(class_forms)) {
    add <- class_forms[[form]]
    passes <- c(passes, list(
      list(
        label = paste(form, "on the outer list"),
        value = add(list(first_msg, later_msg)),
        sent = classed_sent
      ),
      list(
        label = paste(form, "on a later message"),
        value = list(first_msg, add(later_msg)),
        sent = classed_sent
      )
    ))
  }
  passes <- c(passes, list(
    list(
      label = "an S3 class on the first message",
      value = list(structure(first_msg, class = "foo"), later_msg),
      sent = classed_sent
    ),
    list(
      label = "an S3 class on both levels",
      value = structure(
        list(structure(first_msg, class = "foo"), later_msg),
        class = "foo"
      ),
      sent = classed_sent
    )
  ))

  for (p in passes) {
    recorder <- local_request_recorder(mock_response(200L, openai_reply()))
    expect_no_error(lms_chat_openai("a-model", p$value))
    expect_identical(length(recorder$requests), 1L, info = p$label)
    expect_identical(
      sent_messages(recorder$requests[[1]]),
      p$sent,
      info = p$label
    )
  }
})

# The rule-order probes above get the text of their own rule. Each of them
# also fails the trial write, so the rule wins over the write for its reason.
test_that("each rule-order probe also fails the jsonlite write", {
  order_labels <- c(
    "a NULL-cell row and a foo-classed cell",
    "a list-matrix with an environment field",
    "a list-array message with an environment field",
    "a repeated name and an environment field"
  )
  labels <- vapply(messages_probes, `[[`, character(1), "label")
  expect_true(all(order_labels %in% labels))
  for (p in messages_probes[labels %in% order_labels]) {
    expect_error(
      jsonlite::toJSON(
        unclass_messages(p$value),
        auto_unbox = TRUE,
        digits = 22,
        null = "null"
      ),
      "No method asJSON S3 class",
      fixed = TRUE,
      info = p$label
    )
  }
})

# A class below the outer list and its messages is not removed, so a class
# that jsonlite has no method for fails the trial write before the server
# probe. The abort carries the jsonlite message as it is, braces included.
test_that("a value jsonlite cannot write aborts with the jsonlite message", {
  probe <- local_counting_probe()

  err <- expect_error(
    lms_chat_openai(
      "a-model",
      list(list(role = "user", content = structure("x", class = "{x}")))
    ),
    "You gave a value that jsonlite cannot write: No method asJSON S3 class: {x}",
    fixed = TRUE
  )
  expect_match(conditionMessage(err), "`messages`", fixed = TRUE)
  expect_identical(class(err), c("rlang_error", "error", "condition"))
  expect_identical(probe$calls, 0L)
})

# The list-array rule leaves an atomic matrix field and a list-matrix column
# of any data frame alone, and the function rule leaves a message with no
# function alone. Each value below reaches the request.
test_that("matrix forms the list-array rule allows reach the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  top <- data.frame(role = "user")
  top$m <- matrix(list("a", "b"), 1)
  inner <- data.frame(a = 1)
  inner$m <- matrix(list("a", "b"), 1)
  nested <- data.frame(role = "user")
  nested$sub <- inner

  cases <- list(
    list(
      label = "a message with a nested list and no function",
      value = list(list(
        role = "user",
        content = list(list(type = "text", text = "hi"))
      )),
      sent = list(list(
        role = "user",
        content = list(list(type = "text", text = "hi"))
      ))
    ),
    list(
      label = "an atomic matrix field",
      value = list(list(role = "user", m = matrix(1:4, 2))),
      sent = list(list(role = "user", m = list(list(1L, 3L), list(2L, 4L))))
    ),
    list(
      label = "a list-matrix column",
      value = top,
      sent = list(list(role = "user", m = list(list("a"), list("b"))))
    ),
    list(
      label = "a list-matrix column of a nested data frame",
      value = nested,
      sent = list(list(
        role = "user",
        sub = list(a = 1L, m = list(list("a"), list("b")))
      ))
    ),
    list(
      label = "a data-frame field with a list-matrix column",
      value = list(list(role = "user", content = inner)),
      sent = list(list(
        role = "user",
        content = list(list(a = 1L, m = list(list("a"), list("b"))))
      ))
    )
  )

  for (case in cases) {
    recorder <- local_request_recorder(mock_response(200L, openai_reply()))
    expect_no_error(lms_chat_openai("a-model", case$value), message = NULL)
    expect_identical(
      sent_messages(recorder$requests[[1]]),
      case$sent,
      info = case$label
    )
  }
})

# The lms_chat_openai() help gives the sent form of one list-matrix row. The
# form is stated here as JSON text, so a change to what jsonlite sends turns
# the test red. A boxed value parses back as a list, so the comparison sees
# the boxing.
test_that("a list-matrix column is sent with its cells boxed", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  help_row <- data.frame(role = "user", content = "hi")
  help_row$tags <- matrix(list("a", NULL, list(k = "v")), 1)
  help_form <- '{"role":"user","content":"hi","tags":[["a"],null,{"k":["v"]}]}'

  # unbox() unboxes a cell and a value in a list at any depth. A data frame
  # in a cell is sent as an array of objects with its values not boxed.
  other_row <- data.frame(role = "user")
  other_row$m <- matrix(
    list(
      jsonlite::unbox("a"),
      list(list(z = 1)),
      list(q = jsonlite::unbox("b")),
      data.frame(k = "v")
    ),
    1
  )
  other_form <- '{"role":"user","m":["a",[{"z":[1]}],{"q":"b"},[{"k":"v"}]]}'

  cases <- list(
    list(label = "the help example", value = help_row, form = help_form),
    list(label = "unbox and a data frame", value = other_row, form = other_form)
  )
  for (case in cases) {
    recorder <- local_request_recorder(mock_response(200L, openai_reply()))
    expect_no_error(lms_chat_openai("a-model", case$value))
    expect_identical(
      sent_messages(recorder$requests[[1]]),
      list(jsonlite::parse_json(case$form, simplifyVector = FALSE)),
      info = case$label
    )
  }
})

test_that("a Date, a factor, and an I() field reach the request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  recorder <- local_request_recorder(mock_response(200L, openai_reply()))
  expect_no_error(lms_chat_openai(
    "a-model",
    list(list(
      role = I("user"),
      content = factor("hi"),
      date = as.Date("2026-01-01")
    ))
  ))
  expect_identical(
    sent_messages(recorder$requests[[1]]),
    list(list(role = list("user"), content = "hi", date = "2026-01-01"))
  )
})
