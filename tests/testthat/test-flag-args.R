# Each TRUE/FALSE argument of an exported function takes one TRUE or FALSE and
# nothing else. Which functions and arguments are under test is read from the
# formals of the NAMESPACE exports, so a flag argument added later joins the
# domain on its own. A flag is a formal whose default is the constant TRUE or
# FALSE.

flag_formals <- function() {
  out <- list()
  for (name in sort(getNamespaceExports("rlmstudio"))) {
    obj <- get(name, envir = asNamespace("rlmstudio"))
    if (!is.function(obj)) {
      next
    }
    fm <- formals(obj)
    is_flag <- vapply(
      names(fm),
      function(arg) identical(fm[[arg]], TRUE) || identical(fm[[arg]], FALSE),
      logical(1)
    )
    if (any(is_flag)) {
      out[[name]] <- names(fm)[is_flag]
    }
  }
  out
}

# A stand-in value for every formal with no default. A name missing here fails
# the test rather than skipping it, so no function leaves the domain unseen.
flag_placeholders <- list(
  model = "a-model",
  input = "a prompt",
  inputs = c("first", "second"),
  messages = list(list(role = "user", content = "a prompt"))
)

flag_baseline_args <- function(name) {
  fm <- formals(get(name, envir = asNamespace("rlmstudio")))
  needed <- setdiff(
    names(fm)[vapply(
      names(fm),
      function(arg) identical(fm[[arg]], quote(expr = )),
      logical(1)
    )],
    "..."
  )
  missing_from_table <- setdiff(needed, names(flag_placeholders))
  if (length(missing_from_table) > 0L) {
    testthat::fail(paste0(
      "No placeholder for the required argument(s) ",
      paste(missing_from_table, collapse = ", "),
      " of ",
      name,
      "(). Add one to flag_placeholders."
    ))
  }
  flag_placeholders[needed]
}

flag_bad_values <- list(
  list(label = "NA", value = NA, match = "You gave NA"),
  list(label = "a string", value = "yes", match = "a character value"),
  list(label = "a number", value = 1, match = "a numeric value"),
  list(
    label = "two values",
    value = c(TRUE, FALSE),
    match = "2 values rather than one"
  ),
  list(label = "no values", value = logical(0), match = "0 values rather than one"),
  list(label = "a list", value = list(TRUE), match = "a list value"),
  list(label = "NULL", value = NULL, match = "You gave NULL")
)

flag_good_values <- list(
  list(label = "TRUE", value = TRUE),
  list(label = "FALSE", value = FALSE),
  list(label = "a named TRUE", value = c(a = TRUE)),
  list(label = "a one-by-one FALSE matrix", value = matrix(FALSE))
)

# Stubs for each step past the argument checks. Each counts its calls, because
# an error raised inside `expect_error()` would pass for the expected abort
# (M015). The server probe answers FALSE, so a value that passes the checks
# ends in `rlmstudio_no_server`. `lms_chat()` runs no probe of its own, so its
# three delegates are stubbed out too. Its own check is then the only one that
# can stop the call (M003 and M013).
local_flag_stubs <- function(name, .env = parent.frame()) {
  calls <- new.env(parent = emptyenv())
  calls$server <- 0L
  calls$request <- 0L
  calls$cli <- 0L
  calls$delegate <- 0L
  testthat::local_mocked_bindings(
    is_server_running = function(...) {
      calls$server <- calls$server + 1L
      FALSE
    },
    .env = .env
  )
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      calls$request <- calls$request + 1L
      stop("a request left the process", call. = FALSE)
    },
    .package = "httr2",
    .env = .env
  )
  testthat::local_mocked_bindings(
    run = function(...) {
      calls$cli <- calls$cli + 1L
      stop("the lms CLI ran", call. = FALSE)
    },
    .package = "processx",
    .env = .env
  )
  if (identical(name, "lms_chat")) {
    delegate <- function(...) {
      calls$delegate <- calls$delegate + 1L
      stop("a delegate was reached", call. = FALSE)
    }
    testthat::local_mocked_bindings(
      lms_chat_openresponses = delegate,
      lms_chat_openai = delegate,
      lms_chat_native = delegate,
      .env = .env
    )
  }
  calls
}

steps_taken <- function(calls) {
  calls$server + calls$request + calls$cli + calls$delegate
}

# A call that got past the argument checks ends at the stopped server, or at
# the stub for the CLI run or the delegate.
passed_the_checks <- function(err) {
  inherits(err, "rlmstudio_no_server") ||
    conditionMessage(err) %in%
      c("the lms CLI ran", "a delegate was reached")
}

expect_flag_abort <- function(call, arg, probe, calls, info) {
  err <- expect_error(call, probe$match, info = info)
  expect_match(
    conditionMessage(err),
    paste0(arg, "` must be"),
    fixed = TRUE,
    info = paste(info, "names the argument")
  )
  expect_identical(
    class(err),
    c("rlang_error", "error", "condition"),
    info = paste(info, "has no condition class")
  )
  expect_identical(calls$server, 0L, info = paste(info, "probed the server"))
  expect_identical(calls$request, 0L, info = paste(info, "sent a request"))
  expect_identical(calls$cli, 0L, info = paste(info, "ran the lms CLI"))
  expect_identical(calls$delegate, 0L, info = paste(info, "reached a delegate"))
}

flag_domain <- flag_formals()

test_that("the flag scan finds functions and arguments", {
  expect_gt(length(flag_domain), 0)
  expect_gt(length(unlist(flag_domain)), 0)
  # A record of what the scan found on the day this was written, never the
  # source of the domain. A new flag turns this red, which is the signal to
  # check that it carries a check.
  expect_setequal(
    names(flag_domain),
    c(
      "list_models",
      "lms_chat",
      "lms_chat_batch",
      "lms_chat_native",
      "lms_chat_openai",
      "lms_chat_openresponses",
      "lms_daemon_stop",
      "lms_embed",
      "lms_load",
      "lms_server_start",
      "lms_server_status"
    )
  )
})

for (name in names(flag_domain)) {
  test_that(paste0("each flag of ", name, "() takes only TRUE or FALSE"), {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- flag_baseline_args(name)

    for (arg in flag_domain[[name]]) {
      for (probe in flag_bad_values) {
        calls <- local_flag_stubs(name)
        bad <- args
        bad[arg] <- list(probe$value)
        expect_flag_abort(
          do.call(fn, bad),
          arg,
          probe,
          calls,
          info = paste0(name, "(", arg, ") with ", probe$label)
        )
      }

      for (probe in flag_good_values) {
        calls <- local_flag_stubs(name)
        good <- args
        good[arg] <- list(probe$value)
        info <- paste0(name, "(", arg, ") with ", probe$label)
        err <- tryCatch(do.call(fn, good), error = identity)
        expect_s3_class(err, "error")
        expect_true(passed_the_checks(err), info = info)
        expect_gt(steps_taken(calls), 0)
      }
    }
  })
}

# `lms_chat_batch()` passes its `...` to `lms_chat()`, which matches a
# shortened name to `logprobs`. Each such name is checked before the server
# probe, and `NULL` fails as it would in `lms_chat()`.
test_that("a logprobs in the dots of lms_chat_batch() takes only TRUE or FALSE", {
  prefixes <- substring("logprobs", 1, seq_len(nchar("logprobs")))
  expect_identical(prefixes[[1]], "l")
  for (field in prefixes) {
    for (probe in flag_bad_values) {
      calls <- local_flag_stubs("lms_chat_batch")
      dots <- list(probe$value)
      names(dots) <- field
      expect_flag_abort(
        do.call(lms_chat_batch, c(list("a-model", c("a", "b")), dots)),
        "logprobs",
        probe,
        calls,
        info = paste0("lms_chat_batch(", field, " = ", probe$label, ")")
      )
    }
  }

  for (probe in flag_good_values) {
    calls <- local_flag_stubs("lms_chat_batch")
    err <- tryCatch(
      lms_chat_batch("a-model", c("a", "b"), logprobs = probe$value),
      error = identity
    )
    expect_s3_class(err, "rlmstudio_no_server")
    expect_identical(calls$server, 1L, info = probe$label)
  }
})

test_that("a logprobs in the dots of lms_chat_native() is TRUE, FALSE, or NULL", {
  for (probe in flag_bad_values) {
    if (is.null(probe$value)) {
      next
    }
    calls <- local_flag_stubs("lms_chat_native")
    expect_flag_abort(
      lms_chat_native("a-model", "a prompt", logprobs = probe$value),
      "logprobs",
      probe,
      calls,
      info = paste("lms_chat_native(logprobs =", probe$label, ")")
    )

    # Every element named `logprobs` is read, not only the first.
    calls <- local_flag_stubs("lms_chat_native")
    expect_flag_abort(
      lms_chat_native(
        "a-model",
        "a prompt",
        logprobs = FALSE,
        logprobs = probe$value
      ),
      "logprobs",
      probe,
      calls,
      info = paste("lms_chat_native(logprobs = FALSE, logprobs =", probe$label, ")")
    )
  }
})

test_that("no logprobs field of lms_chat_native() reaches the request body", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(body = native_reply()))

  cases <- list(
    list(label = "NULL", dots = list(logprobs = NULL), warns = FALSE),
    list(label = "TRUE", dots = list(logprobs = TRUE), warns = TRUE),
    list(label = "FALSE", dots = list(logprobs = FALSE), warns = FALSE),
    list(label = "a named TRUE", dots = list(logprobs = c(a = TRUE)), warns = TRUE),
    list(
      label = "a one-by-one FALSE matrix",
      dots = list(logprobs = matrix(FALSE)),
      warns = FALSE
    ),
    list(
      label = "two elements",
      dots = list(logprobs = FALSE, logprobs = TRUE),
      warns = TRUE
    )
  )
  for (case in cases) {
    before <- length(recorder$requests)
    # `temperature` is the control. It shows that a field in `...` does reach
    # the body, so the absent `logprobs` is not an artifact of the read.
    call_args <- c(
      list("a-model", "a prompt", temperature = 0.5),
      case$dots
    )
    warnings <- collect_warnings(do.call(lms_chat_native, call_args))$warnings
    shown <- vapply(warnings, conditionMessage, character(1))
    expect_identical(
      any(grepl("does not support logprobs", shown)),
      case$warns,
      info = case$label
    )
    expect_identical(length(recorder$requests), before + 1L, info = case$label)
    sent <- request_target(recorder$requests[[before + 1L]])$body
    expect_false("logprobs" %in% names(sent), info = case$label)
    expect_identical(sent$temperature, 0.5, info = case$label)
  }

  # Only an exact name is read as the flag, so a longer name goes to the
  # server unchecked (D-029).
  lms_chat_native("a-model", "a prompt", logprobs_x = "yes")
  sent <- request_target(recorder$requests[[length(recorder$requests)]])$body
  expect_identical(sent$logprobs_x, "yes")
})

# quiet ------------------------------------------------------------------------

quiet_exports <- function() {
  Filter(
    function(name) {
      obj <- get(name, envir = asNamespace("rlmstudio"))
      is.function(obj) && "quiet" %in% names(formals(obj))
    },
    sort(getNamespaceExports("rlmstudio"))
  )
}

# The four whose `quiet` hides package output. `lms_server_status()` passes
# its `quiet` to the lms CLI instead, and it is in the flag scan above.
output_quiet <- c("list_instances", "list_models", "lms_chat_batch", "lms_embed")

test_that("quiet is in five functions, and four default to NULL", {
  expect_setequal(quiet_exports(), c(output_quiet, "lms_server_status"))
  for (name in output_quiet) {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    expect_true("quiet" %in% names(formals(fn)), info = name)
    expect_null(formals(fn)$quiet)
  }
  expect_false(formals(lms_server_status)$quiet)
})

for (name in output_quiet) {
  test_that(paste0("quiet of ", name, "() is TRUE, FALSE, or NULL"), {
    fn <- get(name, envir = asNamespace("rlmstudio"))
    args <- flag_baseline_args(name)
    for (probe in flag_bad_values) {
      if (is.null(probe$value)) {
        next
      }
      calls <- local_flag_stubs(name)
      bad <- args
      bad["quiet"] <- list(probe$value)
      expect_flag_abort(
        do.call(fn, bad),
        "quiet",
        probe,
        calls,
        info = paste0(name, "(quiet) with ", probe$label)
      )
    }
  })
}

# The nine pairs of a `quiet` value and an option value. With `quiet = NULL`
# the option decides, and `TRUE` or `FALSE` decides over it (D-028).
quiet_pairs <- expand.grid(
  quiet = c("TRUE", "FALSE", "NULL"),
  option = c("TRUE", "FALSE", "unset"),
  stringsAsFactors = FALSE
)

quiet_value <- function(text) switch(text, "TRUE" = TRUE, "FALSE" = FALSE, NULL)
option_value <- function(text) switch(text, "TRUE" = TRUE, "FALSE" = FALSE, NULL)

output_expected <- function(quiet, option) {
  if (quiet == "NULL") {
    return(option != "TRUE")
  }
  quiet == "FALSE"
}

# Run `code` under each of the nine pairs, with `quiet` bound to its value.
# `check` gets the expected show or hide and a label.
for_each_quiet_pair <- function(run, check) {
  expect_identical(nrow(quiet_pairs), 9L)
  for (i in seq_len(nrow(quiet_pairs))) {
    pair <- quiet_pairs[i, ]
    label <- paste0("quiet = ", pair$quiet, ", option = ", pair$option)
    withr::with_options(
      list(rlmstudio.quiet = option_value(pair$option)),
      check(run(quiet_value(pair$quiet)), output_expected(pair$quiet, pair$option), label)
    )
  }
}

expect_shown <- function(shown, expected, label) {
  expect_identical(shown, expected, info = label)
}

# The messages that `run` gives, as text.
messages_of <- function(run) {
  shown <- character()
  withCallingHandlers(
    run,
    message = function(m) {
      shown <<- c(shown, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  shown
}

one_llm <- paste0(
  '{"models": [{"type": "llm", "key": "m1", "display_name": "M1", ',
  '"size_bytes": 1073741824, "loaded_instances": [{"id": "i1"}]}]}'
)

test_that("quiet of list_models() hides or shows its two messages", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(body = '{"models": []}'))
  for_each_quiet_pair(
    function(quiet) messages_of(list_models(quiet = quiet)),
    function(shown, expected, label) {
      expect_shown(any(grepl("No models found on host", shown)), expected, label)
    }
  )

  local_request_recorder(mock_response(body = one_llm))
  for_each_quiet_pair(
    function(quiet) messages_of(list_models(type = "embedding", quiet = quiet)),
    function(shown, expected, label) {
      expect_shown(
        any(grepl("No models found matching criteria", shown)),
        expected,
        label
      )
    }
  )
})

test_that("quiet of list_instances() hides or shows its message", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(body = '{"models": []}'))
  for_each_quiet_pair(
    function(quiet) messages_of(list_instances(quiet = quiet)),
    function(shown, expected, label) {
      expect_shown(any(grepl("No loaded model instances", shown)), expected, label)
    }
  )
})

# Count the progress bars started, without drawing any.
local_bar_count <- function(.env = parent.frame()) {
  count <- new.env(parent = emptyenv())
  count$bars <- 0L
  testthat::local_mocked_bindings(
    cli_progress_bar = function(...) {
      count$bars <- count$bars + 1L
      "bar-id"
    },
    cli_progress_update = function(...) invisible(),
    cli_progress_done = function(...) invisible(),
    .package = "cli",
    .env = .env
  )
  count
}

test_that("quiet of lms_chat_batch() starts or skips its progress bar", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(body = completion_body(quoted("a reply"))))
  count <- local_bar_count()
  for_each_quiet_pair(
    function(quiet) {
      before <- count$bars
      lms_chat_batch("a-model", c("a", "b"), api_type = "openai", quiet = quiet)
      count$bars - before
    },
    function(started, expected, label) {
      expect_identical(started, if (expected) 1L else 0L, info = label)
    }
  )
})

test_that("quiet of lms_embed() starts or skips the bar of a call of two requests", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  reply <- paste0(
    '{"object": "list", "model": "test-embed", "data": ',
    '[{"object": "embedding", "index": 0, "embedding": [0.1, 0.2]}]}'
  )
  recorder <- local_request_recorder(mock_response(body = reply))
  count <- local_bar_count()
  for_each_quiet_pair(
    function(quiet) {
      before <- c(count$bars, length(recorder$requests))
      lms_embed("test-embed", c("a", "b"), batch_size = 1, quiet = quiet)
      # Two requests, so the call is one that can show a bar.
      expect_identical(length(recorder$requests) - before[[2]], 2L)
      count$bars - before[[1]]
    },
    function(started, expected, label) {
      expect_identical(started, if (expected) 1L else 0L, info = label)
    }
  )
})

test_that("quiet of lms_server_status() sets --quiet whatever the option says", {
  sent <- NULL
  testthat::local_mocked_bindings(
    run = function(command, args, ...) {
      sent <<- args
      list(status = 0L, stdout = "running", stderr = "")
    },
    .package = "processx"
  )
  cases <- list(
    list(quiet = TRUE, option = FALSE, flag = TRUE),
    list(quiet = TRUE, option = TRUE, flag = TRUE),
    list(quiet = FALSE, option = TRUE, flag = FALSE),
    list(quiet = FALSE, option = FALSE, flag = FALSE)
  )
  for (case in cases) {
    label <- paste0("quiet = ", case$quiet, ", option = ", case$option)
    withr::with_options(list(rlmstudio.quiet = case$option), {
      built <- build_args_server_status(quiet = case$quiet)
      expect_identical("--quiet" %in% built, case$flag, info = label)
      sent <- NULL
      lms_server_status(quiet = case$quiet)
      expect_identical(sent, built, info = label)
      expect_identical("--quiet" %in% sent, case$flag, info = label)
    })
  }
})

load_settings <- c("flash_attention", "offload_kv_cache_to_gpu")

test_that("the two load settings of lms_load() are TRUE, FALSE, or NULL", {
  probes <- c(
    Filter(function(p) !is.null(p$value), flag_bad_values),
    # `as.logical()` once read this as TRUE.
    list(list(label = "the string true", value = "true", match = "a character value"))
  )
  for (arg in load_settings) {
    for (probe in probes) {
      calls <- local_flag_stubs("lms_load")
      bad <- list(model = "a-model")
      bad[arg] <- list(probe$value)
      expect_flag_abort(
        do.call(lms_load, bad),
        arg,
        probe,
        calls,
        info = paste0("lms_load(", arg, ") with ", probe$label)
      )
    }

    passing <- list(NULL, TRUE, FALSE)
    for (value in passing) {
      calls <- local_flag_stubs("lms_load")
      good <- list(model = "a-model")
      good[arg] <- list(value)
      err <- tryCatch(do.call(lms_load, good), error = identity)
      expect_s3_class(err, "rlmstudio_no_server")
      expect_identical(calls$server, 1L, info = paste(arg, deparse(value)))
    }
  }
})

test_that("the two load settings reach the load body as plain true or false", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(body = '{"status": "loaded"}'))
  withr::local_options(rlmstudio.quiet = TRUE)

  cases <- list(
    list(label = "TRUE", value = TRUE, sent = "true"),
    list(label = "a named TRUE", value = c(x = TRUE), sent = "true"),
    list(label = "a one-by-one TRUE matrix", value = matrix(TRUE), sent = "true"),
    list(label = "FALSE", value = FALSE, sent = "false"),
    list(label = "a one-by-one FALSE matrix", value = matrix(FALSE), sent = "false"),
    list(label = "NULL", value = NULL, sent = NULL)
  )
  for (arg in load_settings) {
    for (case in cases) {
      call_args <- list(model = "a-model", force = TRUE)
      call_args[arg] <- list(case$value)
      do.call(lms_load, call_args)
      req <- recorder$requests[[length(recorder$requests)]]
      expect_identical(req$url, "http://localhost:1234/api/v1/models/load")
      text <- request_body_text(req)
      info <- paste(arg, "with", case$label)
      if (is.null(case$sent)) {
        expect_no_match(text, arg, fixed = TRUE, info = info)
      } else {
        # The field ends at a comma or brace, so `[true]` or `{"x":true}`
        # cannot match.
        expect_match(
          text,
          paste0('"', arg, '":', case$sent, "[,}]"),
          info = info
        )
      }
    }
  }
})
