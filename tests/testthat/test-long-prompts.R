# A load above the trained context, and a prompt longer than the loaded
# context.
#
# lms_load() reads the model list before it loads (force = FALSE). When the
# asked `context_length` is larger than the `max_context_length` of the
# model's row, it warns and still sends the load. The server loads such a
# value with no clamp and no message.

# One model-list entry as JSON text. `max` is JSON text for the
# `max_context_length` field, and `NULL` leaves the field out.
list_entry <- function(key = "a-model", max = "32768", loaded = FALSE) {
  instances <- if (loaded) sprintf('[{"id": "%s"}]', key) else "[]"
  max_field <- if (is.null(max)) "" else sprintf(', "max_context_length": %s', max)
  sprintf(
    '{"type": "llm", "key": "%s", "loaded_instances": %s%s}',
    key,
    instances,
    max_field
  )
}

# A model-list reply that holds the given entries.
list_reply <- function(...) {
  mock_response(200L, sprintf('{"models": [%s]}', paste(c(...), collapse = ", ")))
}

load_ok <- function() mock_response(200L, '{"status": "loaded"}')

# Run `expr` and keep every warning it gives, muffled, in the order given.
# withCallingHandlers() counts each warning once (M019 lesson), where
# expect_warning() stops at the first.
collect_warnings <- function(expr) {
  warnings <- list()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = warnings)
}

above_max <- function(warnings) {
  Filter(function(w) inherits(w, "rlmstudio_context_above_max"), warnings)
}

# Call lms_load() against a model list and a load reply, and return the
# recorder and the warnings. `replies` defaults to the two replies of a load
# that goes ahead.
run_load <- function(list_body, ..., replies = list(list_body, load_ok())) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(replies)
  res <- collect_warnings(suppressMessages(lms_load("a-model", ...)))
  list(recorder = recorder, warnings = res$warnings)
}

test_that("a context_length above the trained maximum warns and still loads", {
  for (asked in list(65536, "65536")) {
    info <- paste("context_length:", class(asked))
    res <- run_load(list_reply(list_entry()), context_length = asked)

    warned <- above_max(res$warnings)
    expect_length(warned, 1L)
    expect_length(res$warnings, 1L)
    msg <- conditionMessage(warned[[1]])
    expect_match(msg, "65536", fixed = TRUE, info = info)
    expect_match(msg, "32768", fixed = TRUE, info = info)

    expect_length(res$recorder$requests, 2L)
    list_req <- request_target(res$recorder$requests[[1]])
    expect_identical(list_req$path, "/api/v1/models", info = info)
    load_req <- request_target(res$recorder$requests[[2]])
    expect_identical(load_req$path, "/api/v1/models/load", info = info)
    expect_identical(load_req$body$context_length, 65536L, info = info)
  }
})

test_that("the warning names the asked value and the maximum in its text", {
  res <- run_load(list_reply(list_entry()), context_length = 65536)
  expect_match(
    conditionMessage(above_max(res$warnings)[[1]]),
    "65536.*32768"
  )
})

test_that("the context warning shows when the rlmstudio.quiet option is TRUE", {
  withr::local_options(rlmstudio.quiet = TRUE)
  res <- run_load(list_reply(list_entry()), context_length = 65536)
  expect_length(above_max(res$warnings), 1L)
  expect_length(res$recorder$requests, 2L)
})

test_that("no context warning at or below the maximum, or with no context_length", {
  cases <- list(
    "NULL" = NULL,
    "equal" = 32768,
    "below" = 4096
  )
  for (name in names(cases)) {
    test_that(name, {
      args <- list(list_reply(list_entry()))
      if (!is.null(cases[[name]])) {
        args$context_length <- cases[[name]]
      }
      res <- do.call(run_load, args)
      expect_length(above_max(res$warnings), 0L)
      expect_length(res$recorder$requests, 2L)
      expect_identical(
        request_target(res$recorder$requests[[2]])$path,
        "/api/v1/models/load",
        info = name
      )
    })
  }
})

test_that("force = TRUE sends the load alone and gives no context warning", {
  res <- run_load(NULL, context_length = 65536, force = TRUE, replies = list(load_ok()))
  expect_length(above_max(res$warnings), 0L)
  expect_length(res$recorder$requests, 1L)
  load_req <- request_target(res$recorder$requests[[1]])
  expect_identical(load_req$path, "/api/v1/models/load")
  expect_identical(load_req$body$context_length, 65536L)
})

test_that("a model already loaded gives no context warning and no load", {
  res <- run_load(
    NULL,
    context_length = 65536,
    replies = list(list_reply(list_entry(loaded = TRUE)))
  )
  expect_length(above_max(res$warnings), 0L)
  expect_length(res$recorder$requests, 1L)
})

test_that("a model list with no maximum for the model gives no context warning", {
  lists <- list(
    "empty list" = mock_response(200L, '{"models": []}'),
    "no row for the model" = list_reply(list_entry(key = "other-model")),
    "null maximum, one row" = list_reply(list_entry(max = "null")),
    "null maximum beside a number" = list_reply(
      list_entry(max = "null"),
      list_entry(key = "other-model", max = "2048")
    ),
    "no max_context_length column" = list_reply(list_entry(max = NULL))
  )
  for (name in names(lists)) {
    test_that(name, {
      res <- run_load(lists[[name]], context_length = 65536)
      expect_length(above_max(res$warnings), 0L)
      expect_length(res$recorder$requests, 2L)
      expect_identical(
        request_target(res$recorder$requests[[2]])$path,
        "/api/v1/models/load",
        info = name
      )
    })
  }
})

test_that("a context_length that as.integer() cannot read gives no context warning", {
  values <- list(NA, "abc", c(4096, 8192))
  for (value in values) {
    info <- paste(format(value), collapse = " ")
    res <- run_load(list_reply(list_entry(max = "2048")), context_length = value)
    expect_length(above_max(res$warnings), 0L)
    expect_length(res$recorder$requests, 2L)
    expect_identical(
      request_target(res$recorder$requests[[2]])$path,
      "/api/v1/models/load",
      info = info
    )
  }
})

test_that("a context_length of \"abc\" gives R's coercion warning once", {
  res <- run_load(list_reply(list_entry(max = "2048")), context_length = "abc")
  coercion <- Filter(
    function(w) grepl("NAs introduced by coercion", conditionMessage(w), fixed = TRUE),
    res$warnings
  )
  expect_length(coercion, 1L)
  expect_length(res$warnings, 1L)
})

test_that("the warning text says the load goes out and counts one token", {
  res <- run_load(list_reply(list_entry(max = "0")), context_length = 1)
  msg <- conditionMessage(above_max(res$warnings)[[1]])
  expect_match(msg, "The load request goes out with 1 token.", fixed = TRUE)
  res <- run_load(list_reply(list_entry()), context_length = 65536)
  msg <- conditionMessage(above_max(res$warnings)[[1]])
  expect_match(msg, "The load request goes out with 65536 tokens.", fixed = TRUE)
})

test_that("a bad max_context_length also aborts list_instances() and lms_unload_all()", {
  body <- list_reply(list_entry(max = '"32768"', loaded = TRUE))
  callers <- list(
    list_instances = function() list_instances(quiet = TRUE),
    lms_unload_all = function() lms_unload_all()
  )
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  for (name in names(callers)) {
    test_that(name, {
      recorder <- local_request_sequence(list(body))
      err <- expect_error(
        suppressMessages(callers[[name]]()),
        class = "rlmstudio_bad_response"
      )
      expect_match(conditionMessage(err), "max_context_length", fixed = TRUE, info = name)
      # The abort comes from the model list, before any unload is sent.
      expect_length(recorder$requests, 1L)
    })
  }
})

test_that("a max_context_length that is not a number or null is a bad response", {
  bad <- list(string = '"32768"', object = '{"value": 32768}')
  for (name in names(bad)) {
    test_that(name, {
      body <- list_reply(list_entry(max = bad[[name]]))

      testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
      recorder <- local_request_sequence(list(body, load_ok()))
      err <- expect_error(
        suppressMessages(lms_load("a-model", context_length = 65536)),
        class = "rlmstudio_bad_response"
      )
      expect_match(conditionMessage(err), "max_context_length", fixed = TRUE)
      # The abort comes from the model list, before any load is sent.
      expect_length(recorder$requests, 1L)

      recorder <- local_request_sequence(list(body))
      err <- expect_error(
        list_models(quiet = TRUE),
        class = "rlmstudio_bad_response"
      )
      expect_match(conditionMessage(err), "max_context_length", fixed = TRUE)
    })
  }
})

test_that("a null max_context_length passes the model-list check", {
  body <- list_reply(list_entry(max = "null"))
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  local_request_sequence(list(body))
  out <- list_models(detailed = TRUE, quiet = TRUE)
  expect_identical(out$key, "a-model")

  recorder <- local_request_sequence(list(body, load_ok()))
  expect_no_error(suppressMessages(lms_load("a-model", context_length = 4096)))
  expect_length(recorder$requests, 2L)
})

# The overflow replies recorded on 2026-09-30 with google/gemma-3-1b loaded at
# 512 tokens on LM Studio 0.4.25+1. The raw bodies are in
# cairn/references/lmstudio-api-surface.md.
overflow_text <- paste(
  "The number of tokens to keep from the initial prompt is greater than the",
  "context length. Try to load the model with a larger context length, or",
  "provide a shorter input"
)
overflow_responses <- paste0(
  '{"error":{"message":"', overflow_text, '","type":"internal_error",',
  '"param":null,"code":"unknown"}}'
)
overflow_native <- paste0(
  '{"error":{"message":"', overflow_text, '","type":"internal_error",',
  '"code":"unknown","param":null}}'
)
overflow_openai <- paste0('{"error":"', overflow_text, '"}')

overflow_start <- paste(
  "The number of tokens to keep from the initial prompt is greater than the",
  "context length"
)

test_that("an overflow reply raises an API error with the server text", {
  cases <- list(
    openresponses = list(
      status = 500L,
      body = overflow_responses,
      call = function() lms_chat_openresponses("a-model", "long prompt")
    ),
    native = list(
      status = 500L,
      body = overflow_native,
      call = function() lms_chat_native("a-model", "long prompt")
    ),
    openai = list(
      status = 400L,
      body = overflow_openai,
      call = function() {
        lms_chat_openai(
          "a-model",
          list(list(role = "user", content = "long prompt"))
        )
      }
    )
  )
  for (name in names(cases)) {
    test_that(name, {
      case <- cases[[name]]
      testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
      local_request_sequence(list(mock_response(case$status, case$body)))
      err <- expect_error(case$call(), class = "rlmstudio_api_error")
      expect_identical(err$status, case$status, info = name)
      expect_match(
        conditionMessage(err),
        overflow_start,
        fixed = TRUE,
        info = name
      )
    })
  }
})

test_that("an overflow reply in a batch fails that input alone", {
  ok <- function(i) {
    mock_response(
      200L,
      output_body(responses_message(output_text(quoted(sprintf("reply %d", i)))))
    )
  }
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(
    ok(1L),
    mock_response(500L, overflow_responses),
    ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch(
      "a-model",
      c("first", "second", "third"),
      format = "list",
      quiet = TRUE
    ),
    "1 input failed, at position 2\\."
  )
  expect_length(recorder$requests, 3L)
  expect_identical(out[[1]], "reply 1")
  expect_s3_class(out[[2]], "rlmstudio_api_error")
  expect_identical(out[[2]]$status, 500L)
  expect_match(conditionMessage(out[[2]]), overflow_start, fixed = TRUE)
  expect_identical(out[[3]], "reply 3")
})
