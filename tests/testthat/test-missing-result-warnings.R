# A call that asks for a result and gets none says so with a classed
# warning that the `rlmstudio.quiet` option does not hide (D-043).

# lms_load(echo_load_config = TRUE) on a loaded model -------------------------

# A model-list reply that holds `a-model`, loaded or not.
echo_list_reply <- function(loaded) {
  instances <- if (loaded) '[{"id": "a-model"}]' else "[]"
  mock_response(
    200L,
    sprintf(
      '{"models": [{"type": "llm", "key": "a-model", "loaded_instances": %s}]}',
      instances
    )
  )
}

# Call lms_load() with `force = FALSE` against `replies`, and return its
# visible value, its warnings, and the requests it sent.
run_echo_load <- function(replies, echo) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(replies)
  res <- collect_warnings(
    suppressMessages(withVisible(lms_load("a-model", echo_load_config = echo)))
  )
  list(
    value = res$value,
    warnings = res$warnings,
    requests = recorder$requests
  )
}

test_that("echo_load_config = TRUE on a loaded model warns past quiet", {
  for (quiet in c(TRUE, FALSE)) {
    test_that(paste("rlmstudio.quiet =", quiet), {
      withr::local_options(rlmstudio.quiet = quiet)
      res <- run_echo_load(list(echo_list_reply(loaded = TRUE)), echo = TRUE)
      expect_identical(res$value$value, "a-model")
      expect_false(res$value$visible)
      expect_identical(length(res$requests), 1L)
      expect_identical(
        request_target(res$requests[[1]])$path,
        "/api/v1/models"
      )
      expect_identical(
        length(warnings_of_class(res$warnings, "rlmstudio_no_load_config")),
        1L
      )
    })
  }
})

test_that("echo_load_config = FALSE on a loaded model gives no echo warning", {
  withr::local_options(rlmstudio.quiet = FALSE)
  res <- run_echo_load(list(echo_list_reply(loaded = TRUE)), echo = FALSE)
  expect_identical(res$value$value, "a-model")
  expect_identical(length(res$requests), 1L)
  expect_length(warnings_of_class(res$warnings, "rlmstudio_no_load_config"), 0L)
})

test_that("echo_load_config = TRUE on a model that is not loaded returns the config", {
  withr::local_options(rlmstudio.quiet = FALSE)
  load_reply <- mock_response(
    200L,
    '{"status": "loaded", "load_config": {"context_length": 4096}}'
  )
  res <- run_echo_load(
    list(echo_list_reply(loaded = FALSE), load_reply),
    echo = TRUE
  )
  expect_identical(res$value$value, list(context_length = 4096L))
  expect_identical(length(res$requests), 2L)
  expect_identical(
    request_target(res$requests[[2]])$path,
    "/api/v1/models/load"
  )
  expect_length(warnings_of_class(res$warnings, "rlmstudio_no_load_config"), 0L)
})

# lms_chat_openai(logprobs = TRUE) ---------------------------------------------

# Call `fn` with `...` against `responses`, and return its value and its
# warnings. A call that raises returns the condition as its value.
# lms_chat_openai() takes messages, and lms_chat() takes one input string.
run_openai_call <- function(responses, fn = lms_chat_openai, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  prompt <- if (identical(fn, lms_chat_openai)) {
    list(list(role = "user", content = "hi"))
  } else {
    "hi"
  }
  collect_warnings(
    tryCatch(
      fn("a-model", prompt, ...),
      rlmstudio_api_error = identity,
      rlmstudio_bad_response = identity
    )
  )
}

no_logprobs <- function(warnings) {
  warnings_of_class(warnings, "rlmstudio_no_logprobs")
}

text_reply <- function(finish_reason = "stop") {
  mock_response(200L, completion_body(quoted("Blue"), finish_reason))
}

test_that("an OpenAI reply for logprobs = TRUE warns once past quiet", {
  settings <- list(
    list(quiet = TRUE, schema = NULL),
    list(quiet = FALSE, schema = NULL),
    list(quiet = TRUE, schema = score_schema),
    list(quiet = FALSE, schema = score_schema)
  )
  for (s in settings) {
    info <- paste("quiet:", s$quiet, "schema:", !is.null(s$schema))
    test_that(info, {
      withr::local_options(rlmstudio.quiet = s$quiet)
      reply <- if (is.null(s$schema)) {
        text_reply()
      } else {
        mock_response(200L, completion_body(quoted('{"score": 3}')))
      }
      res <- run_openai_call(list(reply), logprobs = TRUE, schema = s$schema)
      expect_s3_class(res$value, "lms_chat_result")
      expect_null(res$value$logprobs)
      expect_identical(length(res$warnings), 1L, info = info)
      expect_identical(length(no_logprobs(res$warnings)), 1L, info = info)
    })
  }
})

test_that("lms_chat() on the OpenAI route warns once for logprobs = TRUE", {
  withr::local_options(rlmstudio.quiet = TRUE)
  res <- run_openai_call(
    list(text_reply()),
    fn = lms_chat,
    api_type = "openai",
    logprobs = TRUE
  )
  expect_s3_class(res$value, "lms_chat_result")
  expect_identical(length(res$warnings), 1L)
  expect_identical(length(no_logprobs(res$warnings)), 1L)
})

test_that("a cut-off OpenAI reply for logprobs = TRUE warns cut-off first", {
  withr::local_options(rlmstudio.quiet = TRUE)
  res <- run_openai_call(list(text_reply("length")), logprobs = TRUE)
  expect_s3_class(res$value, "lms_chat_result")
  expect_identical(length(res$warnings), 2L)
  expect_s3_class(res$warnings[[1]], "rlmstudio_reply_cut_off")
  expect_s3_class(res$warnings[[2]], "rlmstudio_no_logprobs")
})

test_that("an OpenAI call that returns no lms_chat_result gives no logprobs warning", {
  withr::local_options(rlmstudio.quiet = FALSE)
  cases <- list(
    "logprobs = FALSE" = list(
      responses = list(text_reply()),
      args = list(logprobs = FALSE),
      class = "character"
    ),
    "simplify = FALSE" = list(
      responses = list(text_reply()),
      args = list(logprobs = TRUE, simplify = FALSE),
      class = "list"
    ),
    "null content" = list(
      responses = list(mock_response(200L, completion_body("null"))),
      args = list(logprobs = TRUE),
      class = "rlmstudio_bad_response"
    ),
    "status 500" = list(
      responses = list(mock_response(500L, '{"error": {"message": "boom"}}')),
      args = list(logprobs = TRUE),
      class = "rlmstudio_api_error"
    )
  )
  for (name in names(cases)) {
    case <- cases[[name]]
    res <- do.call(run_openai_call, c(list(case$responses), case$args))
    expect_true(inherits(res$value, case$class), info = name)
    expect_length(no_logprobs(res$warnings), 0L)
  }
})

# lms_chat_batch(api_type = "openai", logprobs = TRUE) -------------------------

fail_reply <- function() mock_response(500L, '{"error": {"message": "boom"}}')

# Run an OpenAI batch over one input per entry of `responses`, and return its
# value and its warnings in the order given.
run_openai_batch <- function(responses, ...) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  inputs <- letters[seq_along(responses)]
  collect_warnings(
    lms_chat_batch("a-model", inputs, api_type = "openai", logprobs = TRUE, ...)
  )
}

test_that("an OpenAI logprobs batch gives one logprobs warning past quiet", {
  for (format in c("list", "vector", "data.frame")) {
    for (how in c("option", "argument")) {
      info <- paste(format, "quiet by", how)
      test_that(info, {
        if (how == "option") {
          withr::local_options(rlmstudio.quiet = TRUE)
          res <- run_openai_batch(
            list(text_reply(), text_reply()),
            format = format
          )
        } else {
          withr::local_options(rlmstudio.quiet = FALSE)
          res <- run_openai_batch(
            list(text_reply(), text_reply()),
            format = format,
            quiet = TRUE
          )
        }
        found <- no_logprobs(res$warnings)
        expect_identical(length(found), 1L, info = info)
        expect_match(
          conditionMessage(found[[1]]),
          "2 replies",
          fixed = TRUE,
          info = info
        )
      })
    }
  }
})

test_that("the batch logprobs warning comes after the failed and cut-off warnings", {
  withr::local_options(rlmstudio.quiet = TRUE)
  res <- run_openai_batch(
    list(fail_reply(), text_reply("length"), text_reply()),
    format = "list"
  )
  classes <- vapply(
    res$warnings,
    function(w) {
      if (inherits(w, "rlmstudio_no_logprobs")) {
        "logprobs"
      } else if (inherits(w, "rlmstudio_reply_cut_off")) {
        "cut-off"
      } else {
        "other"
      }
    },
    character(1)
  )
  expect_identical(classes, c("other", "cut-off", "logprobs"))
  expect_match(conditionMessage(res$warnings[[1]]), "1 input failed", fixed = TRUE)
  expect_match(conditionMessage(res$warnings[[3]]), "2 replies", fixed = TRUE)
})

test_that("a batch that loses the server gives the logprobs warning before the abort", {
  withr::local_options(rlmstudio.quiet = TRUE)
  # The batch probes once before the loop, and each call probes again, so the
  # third probe is the second call's.
  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes < 3L
  })
  local_request_sequence(list(text_reply()))
  warnings <- list()
  err <- expect_error(
    withCallingHandlers(
      lms_chat_batch("a-model", c("a", "b"), api_type = "openai", logprobs = TRUE),
      warning = function(w) {
        warnings[[length(warnings) + 1L]] <<- w
        invokeRestart("muffleWarning")
      }
    ),
    class = "rlmstudio_no_server"
  )
  expect_s3_class(err$results[[1]], "lms_chat_result")
  found <- no_logprobs(warnings)
  expect_identical(length(found), 1L)
  expect_match(conditionMessage(found[[1]]), "1 reply", fixed = TRUE)
})

test_that("an OpenAI logprobs batch with no result gives no logprobs warning", {
  withr::local_options(rlmstudio.quiet = TRUE)
  res <- run_openai_batch(list(fail_reply(), fail_reply()), format = "list")
  expect_length(no_logprobs(res$warnings), 0L)
  for (format in c("list", "vector")) {
    res <- run_openai_batch(
      list(text_reply(), text_reply()),
      format = format,
      simplify = FALSE
    )
    expect_type(res$value[[1]], "list")
    expect_length(no_logprobs(res$warnings), 0L)
  }
})
