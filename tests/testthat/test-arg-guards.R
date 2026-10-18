# A run without NOT_CRAN=true skips this file, as CRAN's does, to keep CRAN's
# Windows R-devel check under its time limit. setup-r in CI, devtools::test(),
# and devtools::check() set NOT_CRAN=true if it is unset, so they run it.
testthat::skip_on_cran()

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

# Each loop below defines one block per function, so an error in one function
# fails that block alone and the blocks for the other functions still run.
for (name in guarded_exports(c("model", "job_id", "input", "inputs"))) {
  test_that(paste0(name, "() has a placeholder for each required argument"), {
    expect_type(baseline_args(name), "list")
  })
}

test_that("a missing placeholder fails the test rather than skipping it", {
  expect_failure(
    baseline_args("lms_embed", table = list(model = "a-model")),
    "No placeholder for the required argument"
  )
  expect_failure(baseline_args("lms_embed", table = list()))
})

for (name in guarded_exports(c("model", "job_id"))) {
  test_that(
    paste0(
      "a bad model or job id aborts ",
      name,
      "(), named, before any request"
    ),
    {
      local_guard_only()

      fn <- get(name, envir = asNamespace("rlmstudio"))
      # Not baseline_args(): a `fail()` that a block records before its nested
      # subtests is dropped from the results table. The placeholder block above
      # fails on a missing placeholder for each of these functions.
      args <- arg_placeholders[required_formals(name)]
      target <- intersect(c("model", "job_id"), names(args))[[1]]

      for (probe in id_probes) {
        test_that(probe$label, {
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
        })
      }
    }
  )
}

# These blocks do not test the guards. R raises its own missing-argument
# error when the guard forces the promise, and that error already names the
# argument, so the guard could be deleted and they would still pass. They are
# kept because they pin the weaker fact the guards rely on: omitting the
# argument never reaches the request.
for (name in guarded_exports(c("model", "job_id"))) {
  test_that(
    paste0(
      "omitting the guarded identifier of ",
      name,
      "() reaches no request, whoever aborts"
    ),
    {
      local_guard_only()

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
  )
}

# `local_guard_only()` forces the server probe to succeed, so it cannot see
# this. The guards now run above `stop_if_no_server()`, which means a bad
# argument beats the server-down abort. Nothing else pins that order.
for (name in guarded_exports(c("model", "job_id"))) {
  test_that(
    paste0(
      "an argument fault aborts ",
      name,
      "() even when the server is down"
    ),
    {
      local_no_request_allowed()
      testthat::local_mocked_bindings(
        is_server_running = function(...) FALSE
      )

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
  )
}

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

for (name in names(strict_text)) {
  test_that(
    paste0(
      "the text vector argument of ",
      name,
      "() must be a non-empty character vector"
    ),
    {
      local_guard_only()

      fn <- get(name, envir = asNamespace("rlmstudio"))
      target <- strict_text[[name]]
      # Not baseline_args(), for the reason given at the model and job id block.
      args <- arg_placeholders[required_formals(name)]

      bad_values <- list(1:3, list("a"), TRUE, character(0), NULL, factor("a"))
      for (bad_value in bad_values) {
        test_that(deparse1(bad_value), {
          bad <- args
          bad[target] <- list(bad_value)
          expect_error(
            do.call(fn, bad),
            "non-empty character vector",
            info = paste(name, "with", class(bad_value)[[1]])
          )
          expect_error(do.call(fn, bad), target, info = name)
        })
      }
    }
  )
}

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
  test_that(
    paste0("an NA anywhere in the text argument of ", name, "() aborts"),
    {
      local_guard_only()

      fn <- get(name, envir = asNamespace("rlmstudio"))
      target <- c(strict_text, loose_text)[[name]]
      # Not baseline_args(), for the reason given at the model and job id block.
      args <- arg_placeholders[required_formals(name)]

      for (probe in na_probes) {
        test_that(probe$label, {
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
        })
      }
    }
  )
}

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

for (name in names(loose_text)) {
  test_that(
    paste0(name, "() passes a non-character input through to the server"),
    {
      local_guard_only()

      structured <- list(list(role = "user", content = "a prompt"))
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
  )
}

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

# local_counting_probe() lives in helper-mock-http.R.

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
  list(
    label = "a data frame",
    value = data.frame(a = 1),
    match = "a data frame"
  )
)

for (name in names(schema_calls)) {
  test_that(
    paste0(
      "a schema in the wrong form aborts ",
      name,
      "() before the server probe"
    ),
    {
      probe <- local_counting_probe()

      call <- schema_calls[[name]]
      for (p in schema_probes) {
        test_that(p$label, {
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
        })
      }
      expect_identical(probe$calls, 0L)
    }
  )
}

for (name in names(schema_calls)) {
  test_that(
    paste0(
      "a schema with a response_format in the dots aborts ",
      name,
      "() before the probe"
    ),
    {
      probe <- local_counting_probe()

      err <- expect_error(
        schema_calls[[name]](
          schema = list(type = "object"),
          response_format = list(type = "json_object")
        ),
        "not both",
        info = name
      )
      expect_false(any(grepl("^rlmstudio_", class(err))), info = name)
      expect_identical(probe$calls, 0L)
    }
  )
}

for (name in names(schema_calls)) {
  test_that(
    paste0(
      "a valid schema passes the form check of ",
      name,
      "() and reaches the server probe"
    ),
    {
      probe <- local_counting_probe()

      valid <- list(
        list(
          type = "object",
          properties = list(score = list(type = "integer"))
        ),
        list(),
        NULL
      )
      for (value in valid) {
        test_that(deparse1(value), {
          expect_error(
            schema_calls[[name]](schema = value),
            class = "rlmstudio_no_server",
            info = name
          )
        })
      }
      expect_identical(probe$calls, length(valid))
    }
  )
}

# The two functions that route, each called with a valid schema. `api_type` is
# left out when `route` is NULL, so the default route is probed as the caller
# would meet it.
route_calls <- list(
  lms_chat = function(route) {
    args <- list("a-model", "hi", schema = list(type = "object"))
    if (!is.null(route)) {
      args$api_type <- route
    }
    do.call(lms_chat, args)
  },
  lms_chat_batch = function(route) {
    args <- list("a-model", "hi", schema = list(type = "object"))
    if (!is.null(route)) {
      args$api_type <- route
    }
    do.call(lms_chat_batch, args)
  }
)

for (name in names(route_calls)) {
  test_that(
    paste0(
      "a schema on a route other than openai aborts ",
      name,
      "() before the probe"
    ),
    {
      probe <- local_counting_probe()

      for (route in list("openresponses", "native", NULL)) {
        test_that(paste("route", deparse1(route)), {
          label <- paste(
            name,
            "with",
            if (is.null(route)) "the default" else route
          )
          err <- expect_error(
            route_calls[[name]](route),
            'api_type = "openai"',
            fixed = TRUE,
            info = label
          )
          expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
        })
      }
      expect_identical(probe$calls, 0L)
    }
  )
}

test_that("the form check runs before the route check", {
  probe <- local_counting_probe()

  # The default route is not openai, so both checks have a fault to report.
  expect_error(
    lms_chat("a-model", "hi", schema = "object"),
    "a character value"
  )
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

test_that("a schema property name that cannot name a column aborts before the server probe", {
  # The probe finds a server and the recorder answers every request, so a
  # batch that got past the name check would send a request.
  probes <- 0L
  local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    TRUE
  })
  recorder <- local_request_recorder(
    mock_response(200L, completion_body(quoted('{"a": "x"}')))
  )
  batch <- function(properties, format = "data.frame") {
    lms_chat_batch(
      "a-model",
      "hi",
      format = format,
      quiet = TRUE,
      api_type = "openai",
      schema = list(type = "object", properties = properties)
    )
  }
  one <- list(type = "string")
  taken <- c(
    "input",
    "output",
    "response_id",
    "input_tokens",
    "total_output_tokens",
    "reasoning_output_tokens"
  )
  cases <- c(
    lapply(taken, function(name) {
      list(
        label = name,
        properties = stats::setNames(list(one, one), c("a", name)),
        match = sprintf('"%s" has the name of a column', name)
      )
    }),
    list(
      list(
        label = "an empty name",
        properties = stats::setNames(list(one, one), c("a", "")),
        match = "A property name is empty."
      ),
      list(
        label = "an NA name",
        properties = stats::setNames(list(one, one), c("a", NA)),
        match = "A property name is `NA`."
      ),
      list(
        label = "a repeated name",
        properties = stats::setNames(list(one, one), c("a", "a")),
        match = '"a" is there more than once'
      )
    )
  )
  for (case in cases) {
    test_that(paste(case$label, "in a data frame"), {
      err <- expect_error(
        batch(case$properties),
        class = "rlang_error",
        info = case$label
      )
      message <- gsub("\\s+", " ", conditionMessage(err))
      expect_match(message, case$match, fixed = TRUE, info = case$label)
      # No package class on an argument fault (D-008).
      expect_false(any(grepl("^rlmstudio_", class(err))), info = case$label)
    })
  }
  # In a subtest, so testthat keeps a failure here in its results.
  test_that("the data frame format probes and sends nothing", {
    expect_identical(probes, 0L)
    expect_length(recorder$requests, 0L)
  })

  # The list and vector formats keep the replies as parsed, so the same
  # schemas send their requests.
  for (case in cases) {
    test_that(paste(case$label, "in a list and a vector"), {
      out <- batch(case$properties, "list")
      expect_identical(out, list(list(a = "x")), info = case$label)
      expect_warning(
        out <- batch(case$properties, "vector"),
        "cannot store replies parsed",
        info = case$label
      )
      expect_identical(out, list(list(a = "x")), info = case$label)
    })
  }
  expect_length(recorder$requests, 2L * length(cases))

  # A data frame with logprobs holds text replies and adds no property
  # column, so it does not check the names either.
  out <- lms_chat_batch(
    "a-model",
    "hi",
    format = "data.frame",
    quiet = TRUE,
    api_type = "openai",
    logprobs = TRUE,
    schema = list(type = "object", properties = list(output = one))
  )
  expect_identical(names(out)[1:3], c("input", "output", "logprobs"))
  expect_identical(out$output, '{"a": "x"}')
  expect_length(recorder$requests, 2L * length(cases) + 1L)
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
# from NAMESPACE, and `lms_chat_batch()`. The loops below call this outside any
# block, where a `fail()` would end the file, so the domain test holds the check
# for an export with no call above. Such an export also errors in its own block.
ttl_domain <- function() {
  c(guarded_exports("ttl"), "lms_chat_batch")
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
  # An export with no call fails here rather than leaving the domain.
  missing_call <- setdiff(domain, names(ttl_calls))
  expect(
    length(missing_call) == 0,
    paste0(
      "No call in ttl_calls for ",
      paste(missing_call, collapse = ", "),
      "()."
    )
  )
})

for (name in ttl_domain()) {
  test_that(
    paste0(
      "a ttl that is not one whole number in range aborts ",
      name,
      "() before the probe"
    ),
    {
      probe <- local_counting_probe()

      for (value in ttl_bad_values) {
        test_that(deparse1(value), {
          label <- paste(name, "with", deparse(value))
          err <- expect_error(
            ttl_calls[[name]](ttl = value),
            "must be one whole number",
            info = label
          )
          expect_match(conditionMessage(err), "ttl", info = label)
          # No package class on an argument fault (D-008).
          expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
        })
      }
      expect_identical(probe$calls, 0L)
    }
  )
}

for (name in ttl_domain()) {
  test_that(
    paste0(
      "a valid ttl passes the value check of ",
      name,
      "() and reaches the server probe"
    ),
    {
      probe <- local_counting_probe()

      valid <- list(NULL, 1, 300L, .Machine$integer.max)
      for (value in valid) {
        test_that(deparse1(value), {
          expect_error(
            ttl_calls[[name]](ttl = value),
            class = "rlmstudio_no_server",
            info = paste(name, "with", deparse(value))
          )
        })
      }
      expect_identical(probe$calls, length(valid))
    }
  )
}

# The two functions that route, each called with a valid ttl. `api_type` is
# left out when `route` is NULL, so the default route is probed as the caller
# would meet it.
ttl_route_calls <- list(
  lms_chat = function(route) {
    args <- list("a-model", "hi", ttl = 300)
    if (!is.null(route)) {
      args$api_type <- route
    }
    do.call(lms_chat, args)
  },
  lms_chat_batch = function(route) {
    args <- list("a-model", "hi", ttl = 300)
    if (!is.null(route)) {
      args$api_type <- route
    }
    do.call(lms_chat_batch, args)
  }
)

for (name in names(ttl_route_calls)) {
  test_that(
    paste0(
      "a ttl on a route other than openai aborts ",
      name,
      "() before the probe"
    ),
    {
      probe <- local_counting_probe()

      for (route in list("openresponses", "native", NULL)) {
        test_that(paste("route", deparse1(route)), {
          label <- paste(
            name,
            "with",
            if (is.null(route)) "the default" else route
          )
          err <- expect_error(
            ttl_route_calls[[name]](route),
            'api_type = "openai"',
            fixed = TRUE,
            info = label
          )
          expect_match(conditionMessage(err), "ttl", info = label)
          expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
        })
      }
      expect_identical(probe$calls, 0L)
    }
  )
}

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

for (name in stream_domain()) {
  test_that(
    paste0(
      "a stream other than FALSE or NULL aborts ",
      name,
      "() before the server probe"
    ),
    {
      probe <- local_counting_probe()

      for (route in stream_routes(name)) {
        test_that(paste("route", deparse1(route)), {
          for (dots in stream_bad_dots) {
            test_that(deparse1(dots), {
              label <- stream_label(name, route, dots)
              err <- expect_error(
                stream_call(name, route, dots),
                "must be `FALSE` or `NULL`",
                fixed = TRUE,
                info = label
              )
              expect_match(conditionMessage(err), "stream", info = label)
              expect_false(any(grepl("^rlmstudio_", class(err))), info = label)
            })
          }
        })
      }
      expect_identical(probe$calls, 0L)
    }
  )
}

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

# The detail of rule13 in full, for a value of the given type.
non_vector_detail <- function(type) {
  paste0(
    "You gave a field value of type \"",
    type,
    "\", which is not an atomic vector, a list, or NULL."
  )
}

# The function rule, the non-vector rule, and the trial-write rule report a
# value fault under their own header, with no hint. Every other rule reports
# a shape fault.
messages_value_rules <- c("rule10", "rule12", "rule13")

messages_headers <- c(
  shape = "`messages` must be a data frame or an unnamed list of messages.",
  value = "`messages` holds a field value that cannot be sent as JSON."
)

messages_shape_hint <- "Each message is a named list"

good_message <- list(role = "user", content = "hi")

# A 2-row messages frame with a role column and one probe column x.
two_row_frame <- function(x) {
  df_of_rows(2L, role = c("user", "user"), x = x)
}

# Each probe holds a column whose row count differs from the row count of the
# data frame that holds it. The column is at the top level or inside a
# data-frame column. Each such column has no class but "AsIs", or is a data
# frame. The row count is the first extent of a dim, the row count of a data
# frame, and the length of any other column. The NA matrix is the only column
# of its frame. Before the row-count rule, the empty-row rule refused this
# frame with its own detail.
row_count_probes <- list(
  list(label = "a 3-by-2 character matrix column", x = matrix("a", 3, 2)),
  list(label = "a 1-by-2 character matrix column", x = matrix("a", 1, 2)),
  list(label = "a 3-by-0 matrix column", x = matrix("a", 3, 0)),
  list(
    label = "a 3-by-2 NA matrix that is the only column",
    value = df_of_rows(2L, x = matrix(NA, 3, 2))
  ),
  list(
    label = "a one-dimensional array column of length 3",
    x = structure(c("a", "b", "c"), dim = 3L)
  ),
  list(
    label = "a one-dimensional array column of length 1",
    x = structure("a", dim = 1L)
  ),
  list(
    label = "a 3-by-1 list-matrix column",
    x = matrix(list("a", "b", "c"), 3, 1)
  ),
  list(label = "a list column of length 3", x = list("a", "b", "c")),
  list(label = "a character column of length 1", x = "a"),
  list(label = "a character(0) column", x = character(0)),
  list(
    label = "an I() character column of length 3",
    x = I(c("a", "b", "c"))
  ),
  list(
    label = "a data-frame column of 3 rows",
    x = data.frame(a = c("a", "b", "c"))
  ),
  list(
    label = "a data-frame column of 0 rows",
    x = data.frame(a = character())
  ),
  list(
    label = "a 2-row data-frame column that holds a 3-by-2 matrix",
    x = df_of_rows(2L, m = matrix("a", 3, 2))
  ),
  list(
    label = "a 2-row data-frame column that holds a list column of length 3",
    x = df_of_rows(2L, l = list("a", "b", "c"))
  )
)

row_count_probes <- lapply(row_count_probes, function(p) {
  list(
    label = p$label,
    value = if (is.null(p$value)) two_row_frame(p$x) else p$value,
    rule = "rule14"
  )
})

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
    rule = "rule13"
  ),
  list(
    label = "a quote() field",
    value = list(list(role = "user", content = quote(x))),
    rule = "rule13"
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

messages_probes <- c(messages_probes, row_count_probes)

test_that("a messages value that breaks a rule aborts before the server probe", {
  probe <- local_counting_probe()

  for (p in messages_probes) {
    test_that(p$label, {
      err <- expect_error(
        lms_chat_openai("a-model", p$value),
        messages_rule_details[[p$rule]],
        fixed = TRUE,
        info = p$label
      )
      expect_match(
        conditionMessage(err),
        "`messages`",
        fixed = TRUE,
        info = p$label
      )
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
      # A failure lists the other rules whose detail the message holds.
      others <- setdiff(names(messages_rule_details), p$rule)
      named <- others[vapply(
        messages_rule_details[others],
        grepl,
        NA,
        x = conditionMessage(err),
        fixed = TRUE
      )]
      expect_identical(named, character(), info = p$label)
    })
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
    test_that(paste("columns", toString(names(value))), {
      expect_no_warning(
        expect_error(
          lms_chat_openai("a-model", value),
          messages_rule_details[["rule12"]],
          fixed = TRUE
        )
      )
    })
  }
  expect_identical(probe$calls, 0L)
})

test_that("a column with a wrong row count aborts with no warning", {
  probe <- local_counting_probe()
  for (p in row_count_probes) {
    test_that(p$label, {
      out <- chat_openai_outcome(p$value)
      expect_identical(out$n_warnings, 0L, info = p$label)
      expect_identical(
        class(out$error),
        c("rlang_error", "error", "condition"),
        info = p$label
      )
      expect_match(
        conditionMessage(out$error),
        messages_rule_details[["rule14"]],
        fixed = TRUE,
        info = p$label
      )
    })
  }
  # After the subtests, so testthat keeps a failure here in its results.
  expect_length(row_count_probes, 15L)
  expect_identical(probe$calls, 0L)
})

# A column with a class other than "AsIs" alone is not read by the row-count
# rule. jsonlite writes it by its class. A wrong-length one fails the trial
# write, with no warning and no R error from outside the package on the way.
test_that("a classed column with a wrong length reaches the trial write", {
  probe <- local_counting_probe()
  probes <- list(
    "a Date column of length 3" = as.Date(c("2026-01-01", "2026-01-02", "2026-01-03")),
    "a factor column of length 3" = factor(c("a", "b", "c")),
    "a one-dimensional Date array of length 1" = structure(
      as.Date("2026-01-01"),
      dim = 1L
    )
  )
  for (label in names(probes)) {
    test_that(label, {
      out <- chat_openai_outcome(two_row_frame(probes[[label]]))
      expect_identical(out$n_warnings, 0L, info = label)
      expect_identical(
        class(out$error),
        c("rlang_error", "error", "condition"),
        info = label
      )
      expect_true(
        startsWith(conditionMessage(out$error), messages_headers[["value"]]),
        info = label
      )
      expect_match(
        conditionMessage(out$error),
        messages_rule_details[["rule10"]],
        fixed = TRUE,
        info = label
      )
    })
  }
  expect_identical(probe$calls, 0L)
})

# The columns that the column lines of a messages abort name, in order. The
# line text is stated here rather than read from the package.
column_line_names <- function(message) {
  lines <- regmatches(
    message,
    gregexpr(
      "Column \"[^\n]*\" is the first column that jsonlite cannot write on its own\\.",
      message
    )
  )[[1]]
  sub("^Column \"(.*)\" is the first column.*$", "\\1", lines)
}

# When the trial write of a data frame fails, each top-level column is written
# alone, in column order, and the abort names the first that fails. Each probe
# column comes after a role column that writes. The 2-by-2 Date matrix inside
# the data-frame column sub fails before the later foo matrix is reached.
test_that("a failed trial write of a data frame names the first column that fails", {
  probe <- local_counting_probe()
  foo_matrix <- structure(matrix(1:2, 2), class = "foo")
  date_matrix <- structure(
    as.Date(c("2026-01-01", "2026-01-02", "2026-01-03", "2026-01-04")),
    dim = c(2L, 2L)
  )
  roles <- c("user", "user")
  cases <- list(
    list(
      label = "a 2-by-0 Date matrix",
      value = two_row_frame(structure(as.Date(character()), dim = c(2L, 0L))),
      column = "x"
    ),
    list(
      label = "a 2-by-2 Date matrix",
      value = two_row_frame(date_matrix),
      column = "x"
    ),
    list(
      label = "a 2-by-1 matrix with the class foo alone",
      value = two_row_frame(foo_matrix),
      column = "x"
    ),
    list(
      label = "a foo matrix in a column named {a}",
      value = df_of_rows(2L, role = roles, `{a}` = foo_matrix),
      column = "{a}"
    ),
    list(
      label = "a data-frame column with a Date matrix, then a foo matrix",
      value = df_of_rows(
        2L,
        role = roles,
        sub = df_of_rows(2L, d = date_matrix),
        x = foo_matrix
      ),
      column = "sub"
    ),
    list(
      label = "a Date column of length 3",
      value = two_row_frame(
        as.Date(c("2026-01-01", "2026-01-02", "2026-01-03"))
      ),
      column = "x"
    ),
    list(
      label = "a factor column of length 3",
      value = two_row_frame(factor(c("a", "b", "c"))),
      column = "x"
    ),
    list(
      label = "a one-dimensional Date array of length 1",
      value = two_row_frame(structure(as.Date("2026-01-01"), dim = 1L)),
      column = "x"
    )
  )
  for (case in cases) {
    test_that(case$label, {
      err <- expect_error(
        lms_chat_openai("a-model", case$value),
        messages_rule_details[["rule10"]],
        fixed = TRUE,
        info = case$label
      )
      expect_true(
        startsWith(conditionMessage(err), messages_headers[["value"]]),
        info = case$label
      )
      expect_identical(
        column_line_names(conditionMessage(err)),
        case$column,
        info = case$label
      )
    })
  }

  # A messages list that is not a data frame keeps the jsonlite text alone.
  err <- expect_error(
    lms_chat_openai(
      "a-model",
      list(list(role = "user", content = structure(1L, class = "foo")))
    ),
    messages_rule_details[["rule10"]],
    fixed = TRUE
  )
  expect_identical(column_line_names(conditionMessage(err)), character())
  expect_no_match(conditionMessage(err), "Column", fixed = TRUE)
  expect_identical(probe$calls, 0L)
})

# The empty-row rule reads a classed column of a wrong length other than 1 as
# not empty in each row. So a row whose other cells are NA is not empty, and
# the frame reaches the trial write. A reading of the column as empty would
# give the empty-row detail instead.
test_that("a classed column with a wrong length is not empty in any row", {
  probe <- local_counting_probe()
  value <- df_of_rows(
    2L,
    role = c("user", NA),
    x = as.Date(c("2026-01-01", "2026-01-02", "2026-01-03"))
  )
  out <- chat_openai_outcome(value)
  expect_identical(out$n_warnings, 0L)
  expect_true(
    startsWith(conditionMessage(out$error), messages_headers[["value"]])
  )
  expect_match(
    conditionMessage(out$error),
    messages_rule_details[["rule10"]],
    fixed = TRUE
  )
  expect_no_match(
    conditionMessage(out$error),
    messages_rule_details[["rule6"]],
    fixed = TRUE
  )
  expect_identical(column_line_names(conditionMessage(out$error)), "x")
  expect_identical(probe$calls, 0L)
})

# Each kind below is neither an atomic vector, a list, nor NULL. The last
# five carry a class set by hand. jsonlite writes each of those five as
# printed text or null, so the trial write alone does not refuse them. The
# kinds are built fresh for each case, because a class set on an environment
# or an external pointer changes the object in place.
non_vector_kinds <- function() {
  class_env <- new.env()
  generator <- methods::setClass(
    "rlmstudioM043Probe",
    representation(v = "numeric"),
    where = class_env
  )
  ref_generator <- methods::setRefClass(
    "rlmstudioM043RefProbe",
    fields = list(v = "numeric"),
    where = class_env
  )
  methods::setClass(
    "rlmstudioM043Slotted",
    representation(v = "numeric"),
    where = class_env
  )
  list(
    "an environment" = function() new.env(),
    "a symbol" = function() quote(x),
    "a call" = function() quote(f(x)),
    "a formula" = function() y ~ x,
    "an expression vector" = function() expression(1),
    "an external pointer" = function() methods::new("externalptr"),
    "an S4 object" = function() generator(v = 1),
    "a reference-class object" = function() ref_generator(v = 1),
    "a class definition with a slot" = function() {
      methods::getClass("rlmstudioM043Slotted", where = class_env)
    },
    "a class definition with no slot" = function() methods::getClass("numeric"),
    "an environment with class POSIXt" = function() {
      structure(new.env(), class = "POSIXt")
    },
    "an environment with class classRepresentation" = function() {
      structure(new.env(), class = "classRepresentation")
    },
    "a call with class function" = function() {
      structure(quote(f(x)), class = "function")
    },
    "an expression vector with class json" = function() {
      structure(expression(1), class = "json")
    },
    "an external pointer with class NULL" = function() {
      structure(methods::new("externalptr"), class = "NULL")
    }
  )
}

# Each position puts a value somewhere the walk must reach. `$<-` refuses
# an environment in a frame with rows, so a frame that holds the value as a
# column is built with structure().
one_row_frame <- function(first, value) {
  structure(
    list(first, value),
    names = c("role", "x"),
    class = "data.frame",
    row.names = 1L
  )
}

non_vector_positions <- list(
  "a field of a list message" = function(v) {
    list(list(role = "user", content = v))
  },
  "an element of a list below a field" = function(v) {
    list(list(role = "user", content = list(list(type = "text", data = v))))
  },
  "a column of a data-frame messages whose other cell is NA" = function(v) {
    one_row_frame(NA_character_, v)
  },
  "a column of a data-frame column" = function(v) {
    df <- data.frame(role = "user")
    df$sub <- one_row_frame("a", v)
    df
  },
  "a cell of a list column" = function(v) {
    df <- data.frame(role = "user")
    df$x <- list(v)
    df
  },
  "a cell of a list-matrix column" = function(v) {
    df <- data.frame(role = "user")
    df$m <- matrix(list(v, "a"), 1)
    df
  },
  "a column of a data-frame field of a list message" = function(v) {
    list(list(role = "user", content = one_row_frame("a", v)))
  }
)

# The type the error names for each kind, stated apart from the value, so a
# wrong type in the detail fails the test.
non_vector_types <- c(
  "an environment" = "environment",
  "a symbol" = "symbol",
  "a call" = "language",
  "a formula" = "language",
  "an expression vector" = "expression",
  "an external pointer" = "externalptr",
  "an S4 object" = "S4",
  "a reference-class object" = "S4",
  "a class definition with a slot" = "S4",
  "a class definition with no slot" = "S4",
  "an environment with class POSIXt" = "environment",
  "an environment with class classRepresentation" = "environment",
  "a call with class function" = "language",
  "an expression vector with class json" = "expression",
  "an external pointer with class NULL" = "externalptr"
)

test_that("a value that is not a vector, a list, or NULL aborts with its own detail", {
  probe <- local_counting_probe()
  kinds <- non_vector_kinds()
  n_cases <- 0L

  for (kind in names(kinds)) {
    test_that(kind, {
      for (position in names(non_vector_positions)) {
        test_that(position, {
          value <- kinds[[kind]]()
          type <- non_vector_types[[kind]]
          label <- paste(kind, "as", position)
          messages <- non_vector_positions[[position]](value)
          err <- expect_no_warning(
            expect_error(
              lms_chat_openai("a-model", messages),
              non_vector_detail(type),
              fixed = TRUE,
              info = label
            )
          )
          expect_true(
            startsWith(conditionMessage(err), messages_headers[["value"]]),
            info = label
          )
          expect_no_match(
            conditionMessage(err),
            messages_rule_details[["rule10"]],
            fixed = TRUE,
            info = label
          )
          n_cases <<- n_cases + 1L
        })
      }
    })
  }
  # After the subtests, so testthat keeps a failure here in its results.
  expect_setequal(names(kinds), names(non_vector_types))
  expect_identical(n_cases, 105L)
  expect_identical(probe$calls, 0L)
})

# The non-vector rule runs after the function rule and before the trial
# write, and a value with no shape fault reaches it past the empty-row rule.
test_that("the non-vector rule sits between the function rule and the trial write", {
  probe <- local_counting_probe()
  expect_value_fault <- function(messages, detail, label) {
    err <- expect_error(
      lms_chat_openai("a-model", messages),
      detail,
      fixed = TRUE,
      info = label
    )
    expect_true(
      startsWith(conditionMessage(err), messages_headers[["value"]]),
      info = label
    )
    err
  }

  expect_value_fault(
    list(list(role = "user", f = function() "x", e = new.env())),
    messages_rule_details[["rule12"]],
    "a function field before an environment field"
  )
  expect_value_fault(
    list(list(role = "user", e = new.env(), f = function() "x")),
    messages_rule_details[["rule12"]],
    "an environment field before a function field"
  )
  err <- expect_value_fault(
    list(list(
      role = "user",
      content = structure("x", class = "foo"),
      e = new.env()
    )),
    non_vector_detail("environment"),
    "a foo-classed field and an environment field"
  )
  expect_no_match(
    conditionMessage(err),
    messages_rule_details[["rule10"]],
    fixed = TRUE
  )
  err <- expect_value_fault(
    one_row_frame(NA_character_, new.env()),
    non_vector_detail("environment"),
    "a row that is NA apart from an environment column"
  )
  expect_no_match(
    conditionMessage(err),
    messages_rule_details[["rule6"]],
    fixed = TRUE
  )
  expect_identical(probe$calls, 0L)
})

# jsonlite writes an NA, NaN, Inf, or -Inf in a plain number as the string
# "NA", "NaN", "Inf", or "-Inf" in each of these positions.
number_positions <- list(
  "a field of a list message" = function(v) {
    list(list(role = "user", content = v))
  },
  "one element of a longer field vector" = function(v) {
    list(list(role = "user", content = c(1L, v)))
  },
  "a field of a list nested in a field" = function(v) {
    list(list(role = "user", content = list(list(type = "text", data = v))))
  },
  "a cell of a list column" = function(v) {
    df <- data.frame(role = "user")
    df$x <- list(v)
    df
  },
  "a cell of a list-matrix column" = function(v) {
    df <- data.frame(role = "user")
    df$m <- matrix(list(v, "a"), 1)
    df
  },
  "a matrix column" = function(v) {
    df <- data.frame(role = "user")
    df$m <- matrix(c(1L, v), 1)
    df
  },
  "a three-dimensional array column" = function(v) {
    df <- data.frame(role = "user")
    df$a <- array(c(1L, v), c(1L, 2L, 1L))
    df
  },
  "a matrix column of a data-frame column" = function(v) {
    sub <- data.frame(k = "a")
    sub$m <- matrix(c(1L, v), 1)
    df <- data.frame(role = "user")
    df$sub <- sub
    df
  }
)

test_that("a number jsonlite cannot send as a number aborts", {
  probe <- local_counting_probe()
  expect_number_fault <- function(messages, label) {
    err <- expect_error(
      lms_chat_openai("a-model", messages),
      number_detail,
      fixed = TRUE,
      info = label
    )
    expect_true(
      startsWith(conditionMessage(err), messages_headers[["value"]]),
      info = label
    )
  }
  n_cases <- 0L

  numbers <- list(
    "a double NA" = NA_real_,
    "NaN" = NaN,
    "Inf" = Inf,
    "-Inf" = -Inf,
    "an integer NA" = NA_integer_
  )
  for (number in names(numbers)) {
    test_that(number, {
      for (position in names(number_positions)) {
        test_that(position, {
          expect_number_fault(
            number_positions[[position]](numbers[[number]]),
            paste(number, "as", position)
          )
          n_cases <<- n_cases + 1L
        })
      }
    })
  }

  # In a subtest, so testthat keeps a failure here in its results.
  test_that("a double NA in I() as a field", {
    expect_number_fault(
      list(list(role = "user", content = I(NA_real_))),
      "a double NA in I() as a field"
    )
    n_cases <<- n_cases + 1L
  })

  for (number in c(Inf, -Inf)) {
    test_that(paste("number", number), {
      for (place in names(plain_column_places)) {
        test_that(place, {
          expect_number_fault(
            plain_column_places[[place]](number),
            paste(number, "in a plain column at", place)
          )
          n_cases <<- n_cases + 1L
        })
      }
    })
  }

  expect_identical(n_cases, 49L)
  expect_identical(probe$calls, 0L)
})

# jsonlite writes a list whose class vector ends in "list" as a plain list,
# so a number inside it is written as a string. The POSIXlt case of the test
# "numbers jsonlite leaves out, and classed values, still reach the request"
# in test-request-body.R is the classed list that the rule must not enter.
test_that("a number in a classed list that jsonlite writes as a list aborts", {
  probe <- local_counting_probe()
  classed_list <- function(v) structure(list(a = v), class = c("foo", "list"))
  df <- data.frame(role = "user")
  df$c <- list(classed_list(Inf))
  cases <- list(
    "a double NA in a classed list field" = list(
      list(role = "user", content = classed_list(NA_real_))
    ),
    "Inf in a classed list in a list-column cell" = df
  )
  for (label in names(cases)) {
    test_that(label, {
      err <- expect_error(
        lms_chat_openai("a-model", cases[[label]]),
        number_detail,
        fixed = TRUE,
        info = label
      )
      expect_true(
        startsWith(conditionMessage(err), messages_headers[["value"]]),
        info = label
      )
    })
  }
  expect_identical(probe$calls, 0L)
})

# The number rule runs after the non-vector rule and before the trial write.
test_that("the number rule sits between the non-vector rule and the trial write", {
  probe <- local_counting_probe()

  err <- expect_error(
    lms_chat_openai(
      "a-model",
      list(list(role = "user", n = NA_real_, e = new.env()))
    ),
    non_vector_detail("environment"),
    fixed = TRUE
  )
  expect_no_match(conditionMessage(err), number_detail, fixed = TRUE)

  err <- expect_error(
    lms_chat_openai(
      "a-model",
      list(list(
        role = "user",
        content = structure("x", class = "foo"),
        n = NA_real_
      ))
    ),
    number_detail,
    fixed = TRUE
  )
  expect_true(startsWith(conditionMessage(err), messages_headers[["value"]]))
  expect_no_match(
    conditionMessage(err),
    messages_rule_details[["rule10"]],
    fixed = TRUE
  )
  expect_identical(probe$calls, 0L)
})

# A column that is neither an atomic vector nor a list is never empty, and
# is.na() is not called on it, so it gives no warning. Each column sits in
# rows that are otherwise NA, so the empty-row rule would win if the column
# counted as empty. The non-vector rule refuses each such column that is not
# a function. `$<-` builds the frame where it accepts the value. It
# refuses an environment in a frame with one or more rows, so that frame
# uses structure().
test_that("a column that is not a vector is not empty and gives no warning", {
  probe <- local_counting_probe()
  s4_env <- new.env()
  s4_class <- methods::setClass(
    "rlmstudioM042Probe",
    representation(v = "numeric"),
    where = s4_env
  )
  ref_generator <- methods::setRefClass(
    "rlmstudioM042RefProbe",
    fields = list(v = "numeric"),
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
    "a reference-class object" = structure(
      list(role = NA_character_, x = ref_generator(v = 1)),
      class = "data.frame",
      row.names = 1L
    ),
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
    test_that(label, {
      err <- expect_no_warning(
        expect_error(
          lms_chat_openai("a-model", cases[[label]]),
          messages_rule_details[["rule13"]],
          fixed = TRUE,
          info = label
        )
      )
      expect_true(
        startsWith(conditionMessage(err), messages_headers[["value"]]),
        info = label
      )
    })
  }

  function_cases <- list(
    "a function" = na_frame(1L, function() "x"),
    "a function in a data-frame column" = local({
      df <- data.frame(role = NA_character_)
      df$sub <- na_frame(1L, function() "x")
      df
    })
  )
  for (label in names(function_cases)) {
    test_that(label, {
      expect_no_warning(
        expect_error(
          lms_chat_openai("a-model", function_cases[[label]]),
          messages_rule_details[["rule12"]],
          fixed = TRUE,
          info = label
        )
      )
    })
  }
  expect_identical(probe$calls, 0L)
})

# empty_rows() reads a column that is neither an atomic vector nor a list as
# not empty in each row, with no warning, at top level and one level down.
# The whole call cannot show this for an S4 class definition with a slot,
# because jsonlite warns when it writes one.
test_that("empty_rows() finds no empty row in a column that is not a vector", {
  class_env <- new.env()
  methods::setClass(
    "rlmstudioM042Slotted",
    representation(v = "numeric"),
    where = class_env
  )
  generator <- methods::setClass(
    "rlmstudioM042Generator",
    representation(v = "numeric"),
    where = class_env
  )
  ref_generator <- methods::setRefClass(
    "rlmstudioM042Ref",
    fields = list(v = "numeric"),
    where = class_env
  )
  na_frame <- function(n, column) {
    df <- data.frame(role = rep(NA_character_, n))
    df$x <- column
    df
  }

  columns <- list(
    "an environment" = new.env(),
    "a formula" = y ~ x,
    "a symbol" = quote(x),
    "a call" = quote(f(x)),
    "an S4 object" = generator(v = 1),
    "a reference-class object" = ref_generator(v = 1),
    "an external pointer" = methods::new("externalptr"),
    "an expression vector" = expression(1),
    "a function" = function() "x",
    "a class generator" = generator,
    "a class definition with a slot" = methods::getClass(
      "rlmstudioM042Slotted",
      where = class_env
    ),
    "a class definition with no slot" = methods::getClass("numeric")
  )

  for (label in names(columns)) {
    test_that(label, {
      # `$<-` refuses an environment in a frame with rows.
      top <- structure(
        list(role = NA_character_, x = columns[[label]]),
        class = "data.frame",
        row.names = 1L
      )
      nested <- data.frame(role = NA_character_)
      nested$sub <- top
      frames <- list("at top level" = top, "one level down" = nested)
      for (where in names(frames)) {
        test_that(where, {
          expect_no_warning(result <- empty_rows(frames[[where]]))
          expect_identical(result, FALSE, info = paste(label, where))
        })
      }
    })
  }
  expect_no_warning(formula_result <- empty_rows(na_frame(3L, y ~ x)))
  expect_identical(formula_result, rep(FALSE, 3L))
})

# A data-frame column counts as empty in a row when each of its own columns
# is empty in that row. A data frame with no columns has no such column, so
# it counts as empty. The cell in row 2 of each column below is written as
# `{}`, or as an object whose only field holds `{}`, and the rule counts that
# cell as empty. The written form is stated here and checked against
# jsonlite.
test_that("a data-frame column with only empty columns counts as empty", {
  probe <- local_counting_probe()

  nested_empty <- local({
    inner <- data.frame(row.names = 1:2)
    inner$m <- data.frame(row.names = 1:2)
    inner
  })
  cases <- list(
    list(
      label = "a data frame with no columns",
      column = data.frame(row.names = 1:2),
      row2 = "{}"
    ),
    list(
      label = "a data frame whose numeric column is NA in row 2",
      column = data.frame(a = c(1, NA)),
      row2 = "{}"
    ),
    list(
      label = "a data frame whose column is a data frame with no columns",
      column = nested_empty,
      row2 = '{"m":{}}'
    )
  )
  for (case in cases) {
    test_that(case$label, {
      written <- jsonlite::parse_json(
        rlm_json_text(case$column),
        simplifyVector = FALSE
      )
      expect_identical(
        written[[2]],
        jsonlite::parse_json(case$row2, simplifyVector = FALSE),
        info = case$label
      )
      expect_error(
        lms_chat_openai("a-model", no_cell_frame(case$column)),
        messages_rule_details[["rule6"]],
        fixed = TRUE,
        info = case$label
      )
    })
  }
  expect_identical(probe$calls, 0L)
})

# A list array of three dimensions with no cells in a row is not empty in
# that row, so the empty-row rule passes it. The list-array rule then
# refuses it, because the column has three dimensions.
test_that("a list array with no cells in a row gets the list-array detail", {
  probe <- local_counting_probe()

  cases <- list(
    "a 2-by-0-by-3 list array" = array(list(), c(2L, 0L, 3L)),
    "a 2-by-3-by-0 list array" = array(list(), c(2L, 3L, 0L))
  )
  for (label in names(cases)) {
    test_that(label, {
      err <- expect_error(
        lms_chat_openai("a-model", no_cell_frame(cases[[label]])),
        messages_rule_details[["rule11"]],
        fixed = TRUE,
        info = label
      )
      expect_no_match(
        conditionMessage(err),
        messages_rule_details[["rule6"]],
        fixed = TRUE
      )
    })
  }
  expect_identical(probe$calls, 0L)
})

# A column with a dim attribute is read row by row, through the cells whose
# first index is the row. The frames are built with `$<-`, because
# data.frame() spreads an array of two or more dimensions over several
# columns and drops the dim of a one-dimensional array. Row 2 of `role` is
# NA, so the array column alone decides whether row 2 is empty. An outcome
# of "server" means the value passes every messages rule and reaches the
# server probe.
dim_column_frame <- function(column) {
  df <- data.frame(role = c("user", NA))
  df$x <- column
  df
}

test_that("a column with a dim attribute is read row by row", {
  # Row 2 of a c(2, 2, 2) array holds the cells at even positions 2, 4, 6, 8.
  row2_cells <- c(2L, 4L, 6L, 8L)
  one_null_list3 <- as.list(1:8)
  one_null_list3[2L] <- list(NULL)
  all_null_list3 <- as.list(1:8)
  all_null_list3[row2_cells] <- list(NULL)
  # Character, because the number rule refuses a numeric NA in an array.
  one_na_atomic3 <- replace(letters[1:8], 2L, NA)
  all_na_atomic3 <- replace(letters[1:8], row2_cells, NA)
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
      value = dim_column_frame(matrix(c("a", "b", "c", NA), 2)),
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
    test_that(case$label, {
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
    })
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
  for (p in messages_probes[labels %in% order_labels]) {
    test_that(p$label, {
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
    })
  }
  # After the subtests, so testthat keeps a failure here in its results.
  expect_true(all(order_labels %in% labels))
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
