# Tests for claims that `vignettes/text-analysis.Rmd`,
# `vignettes/getting-started.Rmd`, and `vignettes/headless-config.Rmd` make
# about package functions. Some of them repeat a check that another test file
# makes.

# The messages that `expr` gives, as text, with each one muffled.
claim_messages <- function(expr) {
  shown <- character()
  withCallingHandlers(
    expr,
    message = function(m) {
      shown <<- c(shown, conditionMessage(m))
      invokeRestart("muffleMessage")
    }
  )
  shown
}

test_that("lms_load() prints its messages, and the quiet option hides them", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  # The messages of one load, and the number of requests that it sent.
  load_messages <- function(option) {
    withr::local_options(rlmstudio.quiet = option)
    recorder <- local_request_sequence(list(
      mock_response(200L, '{"models": []}'),
      mock_response(200L, '{"status": "loaded"}')
    ))
    shown <- claim_messages(lms_load("a-model"))
    list(shown = shown, requests = length(recorder$requests))
  }

  loud <- load_messages(FALSE)
  expect_true(any(grepl("Loading model", loud$shown, fixed = TRUE)))
  expect_true(any(grepl("loaded and verified", loud$shown, fixed = TRUE)))
  expect_identical(loud$requests, 2L)

  # The quiet load still sends both requests.
  quiet <- load_messages(TRUE)
  expect_identical(quiet$shown, character())
  expect_identical(quiet$requests, 2L)
})

test_that("lms_chat_batch() sends each input as its own request, one row each", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  inputs <- c("first", "second", "third")
  reply <- function(i) {
    mock_response(
      200L,
      output_body(responses_message(output_text(quoted(sprintf("reply %d", i)))))
    )
  }
  recorder <- local_request_sequence(lapply(1:3, reply))

  out <- lms_chat_batch("a-model", inputs, format = "data.frame", quiet = TRUE)

  expect_length(recorder$requests, 3L)
  targets <- lapply(recorder$requests, request_target)
  expect_identical(
    vapply(targets, function(t) t[["path"]], character(1)),
    rep("/v1/responses", 3L)
  )
  expect_identical(
    vapply(targets, function(t) t[["body"]][["input"]], character(1)),
    inputs
  )
  expect_identical(nrow(out), 3L)
  expect_identical(out$input, inputs)
  expect_identical(out$output, sprintf("reply %d", 1:3))
})

test_that("lms_chat() on the default route sends the dots and lists the candidates", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  steps <- json_array(
    step_json(
      quoted("3"),
      "-0.3",
      json_array(candidate_json(quoted("3"), "-0.3"), candidate_json(quoted("4"), "-1.5"))
    ),
    step_json(
      quoted("\n"),
      "-0.1",
      json_array(
        candidate_json(quoted("\n"), "-0.1"),
        candidate_json(quoted("/"), "-4"),
        candidate_json(quoted("."), "-5")
      )
    )
  )
  recorder <- local_request_recorder(
    mock_response(200L, output_body(responses_message(output_text(quoted("3\n"), steps))))
  )

  res <- lms_chat(
    "a-model",
    "Rate it.",
    logprobs = TRUE,
    top_logprobs = 10,
    temperature = 0
  )

  sent <- request_target(recorder$requests[[1]])
  # A parse of the body cannot tell 10 from 10L, so the values are compared
  # with expect_equal().
  expect_identical(sent[["path"]], "/v1/responses")
  expect_equal(sent[["body"]][["top_logprobs"]], 10)
  expect_equal(sent[["body"]][["temperature"]], 0)

  expect_s3_class(res, "lms_chat_result")
  expect_identical(res$text, "3\n")
  expect_s3_class(res$logprobs, "data.frame")
  expect_identical(
    names(res$logprobs),
    c("step_token", "step_logprob", "candidate_token", "candidate_logprob", "step")
  )
  expect_identical(res$logprobs$step_token, c("3", "3", "\n", "\n", "\n"))
  expect_identical(res$logprobs$step, c(1L, 1L, 2L, 2L, 2L))
  expect_identical(res$logprobs$candidate_token, c("3", "4", "\n", "/", "."))
  expect_identical(res$logprobs$candidate_logprob, c(-0.3, -1.5, -0.1, -4, -5))

  # A reply that carries no log probabilities gives the text alone.
  local_request_recorder(
    mock_response(200L, output_body(responses_message(output_text(quoted("3")))))
  )
  res <- lms_chat("a-model", "Rate it.", logprobs = TRUE)
  expect_identical(without_response_id(res), "3")
})

test_that("lms_score_expected() without a step column reads the first run of the first step token, keeps the scale, and rescales", {
  # The frame has no `step` column, as a frame saved before that column did.
  # The first run of "3" rows holds "3", "4", a number outside the scale, and
  # a newline. The "\n" rows end the run and hold a "5". The last "3" row
  # holds a "2". It has the same token as the first row but sits after the
  # run, so it does not count.
  lp_df <- data.frame(
    step_token = c("3", "3", "3", "3", "\n", "\n", "3"),
    step_logprob = c(-0.5, -0.5, -0.5, -0.5, -0.1, -0.1, -0.2),
    candidate_token = c("3", "4", "6", "\n", "\n", "5", "2"),
    candidate_logprob = log(c(0.4, 0.2, 0.1, 0.1, 0.9, 0.1, 0.2)),
    stringsAsFactors = FALSE
  )

  res <- lms_score_expected(lp_df, scale = 1:5)

  # Kept: 3 (0.4) and 4 (0.2) from the first run of "3" rows.
  # Rescaled to sum to 1: 0.4 / 0.6 = 2/3 and 0.2 / 0.6 = 1/3.
  expect_identical(names(res), c("expected_value", "weighted_sd", "entropy", "probabilities"))
  expect_identical(res$probabilities$label, c(3, 4))
  expect_equal(res$probabilities$prob, c(2 / 3, 1 / 3))
  expect_equal(sum(res$probabilities$prob), 1)
  # Expected value: 3 * 2/3 + 4 * 1/3 = 10/3.
  expect_equal(res$expected_value, 10 / 3)
  # Weighted SD: sqrt(2/3 * (1/3)^2 + 1/3 * (2/3)^2) = sqrt(2/9).
  expect_equal(res$weighted_sd, sqrt(2 / 9))
  # Entropy in bits: -(2/3 log2 2/3 + 1/3 log2 1/3) = 0.9182958.
  expect_equal(res$entropy, 0.9182958, tolerance = 1e-6)
})

test_that("a logprobs data-frame batch sends top_logprobs and temperature with each input", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  # Each reply carries one step with two candidates, so each cell is a data
  # frame whose step column starts at 1.
  reply <- function(digit) {
    steps <- json_array(step_json(
      quoted(digit),
      "-0.3",
      json_array(candidate_json(quoted(digit), "-0.3"), candidate_json(quoted("4"), "-1.5"))
    ))
    mock_response(200L, output_body(responses_message(output_text(quoted(digit), steps))))
  }
  recorder <- local_request_sequence(list(reply("3"), reply("2")))

  out <- lms_chat_batch(
    "a-model",
    c("first", "second"),
    format = "data.frame",
    logprobs = TRUE,
    top_logprobs = 10,
    temperature = 0,
    quiet = TRUE
  )

  expect_length(recorder$requests, 2L)
  for (k in 1:2) {
    sent <- request_target(recorder$requests[[k]])
    at <- paste("request", k)
    expect_identical(sent[["path"]], "/v1/responses", info = at)
    expect_equal(sent[["body"]][["top_logprobs"]], 10, info = at)
    expect_equal(sent[["body"]][["temperature"]], 0, info = at)
  }
  expect_identical(out$output, c("3", "2"))
  expect_true(is.list(out$logprobs))
  expect_s3_class(out$logprobs[[2]], "data.frame")
  expect_identical(out$logprobs[[2]]$step, c(1L, 1L))
  expect_identical(out$logprobs[[2]]$candidate_token, c("2", "4"))
})

test_that("a schema batch on the openai route asks the default local host and adds the fields as columns", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  schema <- list(
    type = "object",
    properties = list(
      sentiment = list(type = "string"),
      stars = list(type = "integer")
    )
  )
  recorder <- local_request_sequence(list(
    mock_response(200L, completion_body(quoted('{"sentiment": "positive", "stars": 4}'))),
    mock_response(200L, completion_body(quoted('{"sentiment": "negative", "stars": 1}')))
  ))

  out <- lms_chat_batch(
    "a-model",
    c("first", "second"),
    format = "data.frame",
    api_type = "openai",
    schema = schema,
    quiet = TRUE
  )

  for (k in 1:2) {
    sent <- request_target(recorder$requests[[k]])
    at <- paste("request", k)
    expect_identical(sent[["host"]], "localhost:1234", info = at)
    expect_identical(sent[["path"]], "/v1/chat/completions", info = at)
    expect_identical(
      sent[["body"]][["response_format"]][["json_schema"]][["schema"]][["type"]],
      "object",
      info = at
    )
  }
  expect_identical(out$sentiment, c("positive", "negative"))
  expect_identical(out$stars, c(4L, 1L))
})

test_that("a schema data frame keeps the error of a failed input in its output column", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  schema <- list(
    type = "object",
    properties = list(sentiment = list(type = "string"))
  )
  # The second input fails with status 400, as a prompt longer than the
  # context length did on this route of a live server (see the lms_load()
  # help). The third still gets its reply.
  local_request_sequence(list(
    mock_response(200L, completion_body(quoted('{"sentiment": "positive"}'))),
    mock_response(400L, '{"error": {"message": "too many tokens"}}'),
    mock_response(200L, completion_body(quoted('{"sentiment": "negative"}')))
  ))

  res <- collect_warnings(lms_chat_batch(
    "a-model",
    c("first", "second", "third"),
    format = "data.frame",
    api_type = "openai",
    schema = schema,
    quiet = TRUE
  ))
  out <- res$value

  expect_identical(out$sentiment, c("positive", NA, "negative"))
  expect_true(is.list(out$output))
  expect_s3_class(out$output[[2]], "rlmstudio_api_error")
  expect_identical(out$output[[2]]$status, 400L)
  expect_identical(out$output[[3]], list(sentiment = "negative"))
  expect_length(res$warnings, 1L)
  shown <- conditionMessage(res$warnings[[1]])
  expect_match(shown, "1 input failed, at position 2.", fixed = TRUE)
  expect_match(shown, "rlmstudio_api_error", fixed = TRUE)
})

# Claims of `vignettes/getting-started.Rmd`.

test_that("check_lms_version() is TRUE from version 0.4.0 and FALSE below it", {
  local_mocked_bindings(lms_path = function() "lms")
  # The result of one check, for a CLI that prints `stdout`.
  version_check <- function(stdout) {
    local_mocked_bindings(
      run = function(...) list(status = 0, stdout = stdout, stderr = ""),
      .package = "processx"
    )
    result <- NULL
    claim_messages(result <- check_lms_version())
    result
  }

  expect_true(version_check("lms version 0.4.0\n"))
  expect_true(version_check("lms version 0.10.2\n"))
  expect_false(version_check("lms version 0.3.9\n"))
  # A CLI of the 0.4.0 architecture prints a commit line in place of a version.
  expect_true(version_check("CLI commit: 1a2b3c\n"))
})

test_that("install_lmstudio() with the browser method opens the download page", {
  local_mocked_bindings(has_lms = function() FALSE)
  opened <- character()
  local_mocked_bindings(
    browseURL = function(url, ...) opened <<- c(opened, url),
    .package = "utils"
  )

  claim_messages(install_lmstudio(method = "browser"))

  expect_identical(opened, "https://lmstudio.ai/download")
})

test_that("list_models() asks localhost:1234 by default and gives one row per model", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  model <- function(key) {
    shape_object(c(
      type = '"llm"',
      key = quoted(key),
      display_name = quoted(toupper(key)),
      size_bytes = "1073741824",
      max_context_length = "32768",
      loaded_instances = "[]"
    ))
  }
  body <- shape_object(c(models = shape_array(c(model("a/one"), model("b/two")))))
  recorder <- local_request_recorder(mock_response(200L, body))

  res <- list_models(quiet = TRUE)

  sent <- request_target(recorder$requests[[1]])
  expect_identical(sent[["host"]], "localhost:1234")
  expect_identical(sent[["path"]], "/api/v1/models")
  expect_identical(nrow(res), 2L)
  expect_identical(res$key, c("a/one", "b/two"))
})

test_that("lms_download_status() of already_downloaded reports that status and sends no request", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_no_request_allowed()

  res <- lms_download_status("already_downloaded")

  expect_s3_class(res, "lms_download_status")
  expect_identical(res$status, "already_downloaded")
})

test_that("lms_chat() sends the input and the system prompt and returns the reply text", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, output_body(responses_message(output_text(quoted("Hello")))))
  )

  reply <- lms_chat("a-model", input = "Say hello.", system_prompt = "Be brief.")

  sent <- request_target(recorder$requests[[1]])
  expect_identical(sent[["path"]], "/v1/responses")
  expect_identical(sent[["body"]][["input"]], "Say hello.")
  expect_identical(sent[["body"]][["instructions"]], "Be brief.")
  expect_identical(without_response_id(reply), "Hello")
})

test_that("lms_chat_batch() sends the system prompt with each input and returns the replies in order", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  inputs <- c("Name a fruit.", "Name a color.", "Name a planet.")
  reply <- function(text) {
    mock_response(200L, output_body(responses_message(output_text(quoted(text)))))
  }
  recorder <- local_request_sequence(list(reply("Apple"), reply("Blue"), reply("Mars")))

  out <- lms_chat_batch(
    "a-model",
    inputs,
    system_prompt = "Answer with one word.",
    quiet = TRUE
  )

  expect_length(recorder$requests, 3L)
  bodies <- lapply(recorder$requests, function(r) request_target(r)[["body"]])
  expect_identical(vapply(bodies, function(b) b[["input"]], character(1)), inputs)
  expect_identical(
    vapply(bodies, function(b) b[["instructions"]], character(1)),
    rep("Answer with one word.", 3L)
  )
  expect_identical(out, c("Apple", "Blue", "Mars"))
})

# Claims of `vignettes/headless-config.Rmd`.

# Run a headless install with `interactive()`, the consent answer, and
# RLMSTUDIO_ALLOW_INSTALL set as given. `lms_found` is what `has_lms()`
# returns. The installer is a stub, so no install runs. Returns what the call
# showed, the installer calls, and the number of consent questions.
consent_install <- function(interactive, answer = NA, allow = NA, lms_found = FALSE) {
  if (is.na(allow)) {
    withr::local_envvar(RLMSTUDIO_ALLOW_INSTALL = NA)
  } else {
    withr::local_envvar(RLMSTUDIO_ALLOW_INSTALL = allow)
  }
  local_mocked_bindings(has_lms = function() lms_found)
  asked <- 0L
  local_mocked_bindings(
    askYesNo = function(...) {
      asked <<- asked + 1L
      answer
    },
    .package = "utils"
  )
  # The package binding of `interactive`, which R/setup.R keeps for this mock.
  local_mocked_bindings(interactive = function() interactive)
  local_mocked_bindings(
    Sys.which = function(...) "/usr/bin/curl",
    Sys.info = function(...) c(sysname = "Linux"),
    .package = "base"
  )
  runs <- list()
  local_mocked_bindings(
    run = function(command, args, ...) {
      runs[[length(runs) + 1L]] <<- list(command = command, args = args)
      list(status = 0L, stdout = "", stderr = NULL)
    },
    .package = "processx"
  )
  shown <- capture_shown(install_lmstudio(method = "headless"))
  list(shown = shown, runs = runs, asked = asked)
}

test_that("install_lmstudio() with the headless method runs the LM Studio install script", {
  res <- consent_install(interactive = TRUE, answer = TRUE)
  expect_null(res$shown$error)
  expect_length(res$runs, 1L)
  expect_identical(res$runs[[1]]$command, "bash")
  expect_match(
    res$runs[[1]]$args[2],
    "curl -fsSL https://lmstudio.ai/install.sh | bash",
    fixed = TRUE
  )
})

test_that("install_lmstudio() at the console asks first and installs only on yes", {
  yes <- consent_install(interactive = TRUE, answer = TRUE)
  expect_identical(yes$asked, 1L)
  expect_length(yes$runs, 1L)

  no <- consent_install(interactive = TRUE, answer = FALSE)
  expect_identical(no$asked, 1L)
  expect_length(no$runs, 0L)
  expect_match(conditionMessage(no$shown$error), "Installation cancelled by user.", fixed = TRUE)

  # A closed question, NA, is not a yes either.
  closed <- consent_install(interactive = TRUE, answer = NA)
  expect_length(closed$runs, 0L)
  expect_match(conditionMessage(closed$shown$error), "Installation cancelled by user.", fixed = TRUE)

  # At the console, the variable does not skip the question.
  allowed <- consent_install(interactive = TRUE, answer = FALSE, allow = "true")
  expect_identical(allowed$asked, 1L)
  expect_length(allowed$runs, 0L)
})

test_that("install_lmstudio() in a script stops unless RLMSTUDIO_ALLOW_INSTALL is true", {
  unset <- consent_install(interactive = FALSE)
  expect_identical(unset$asked, 0L)
  expect_length(unset$runs, 0L)
  expect_match(
    conditionMessage(unset$shown$error),
    "Installation requires an interactive session to grant permission.",
    fixed = TRUE
  )

  allowed <- consent_install(interactive = FALSE, allow = "true")
  expect_null(allowed$shown$error)
  expect_identical(allowed$asked, 0L)
  expect_length(allowed$runs, 1L)
})

test_that("install_lmstudio() installs nothing when lms 0.4.0 or later is found", {
  local_mocked_bindings(
    has_lms = function() TRUE,
    check_lms_version = function(...) TRUE
  )
  local_mocked_bindings(
    run = function(...) stop("The installer must not run."),
    .package = "processx"
  )
  local_mocked_bindings(
    browseURL = function(...) stop("The browser must not open."),
    .package = "utils"
  )

  shown <- capture_shown(result <- install_lmstudio(method = "headless"))

  expect_null(shown$error)
  expect_true(result)
})

test_that("install_lmstudio() goes on to install when lms is older than 0.4.0", {
  versions <- character()
  local_mocked_bindings(check_lms_version = function(min_version, ...) {
    versions <<- c(versions, min_version)
    FALSE
  })

  older <- consent_install(interactive = FALSE, allow = "true", lms_found = TRUE)

  expect_identical(versions, "0.4.0")
  expect_null(older$shown$error)
  expect_length(older$runs, 1L)
})

# Replace `lms_path()` and `processx::run()` in the calling test with stubs,
# and return an environment whose `args` records the arguments of each `lms`
# call. Each call succeeds, except that `daemon down` returns `daemon_down`.
local_lms_calls <- function(daemon_down = list(status = 0L, stdout = "", stderr = ""),
                            env = parent.frame()) {
  local_mocked_bindings(lms_path = function() "lms", .env = env)
  calls <- new.env()
  calls$args <- list()
  local_mocked_bindings(
    run = function(command, args, ...) {
      calls$args[[length(calls$args) + 1L]] <- args
      if (identical(args, c("daemon", "down"))) {
        daemon_down
      } else {
        list(status = 0L, stdout = "", stderr = "")
      }
    },
    .package = "processx",
    .env = env
  )
  calls
}

test_that("lms_daemon_status() returns the lines that lms status prints", {
  calls <- local_lms_calls()
  local_mocked_bindings(
    run = function(command, args, ...) {
      calls$args[[length(calls$args) + 1L]] <- args
      list(status = 0L, stdout = "Server:  OFF \n\nModels: none\n", stderr = "")
    },
    .package = "processx"
  )

  res <- lms_daemon_status()

  expect_identical(calls$args, list("status"))
  expect_identical(res, c("Server:  OFF ", "Models: none"))
})

test_that("lms_daemon_stop() returns TRUE when the daemon stopped or was not running", {
  local_lms_calls()
  stopped <- NULL
  capture_shown(stopped <- lms_daemon_stop())
  expect_true(stopped)

  local_lms_calls(
    daemon_down = list(status = 1L, stdout = "", stderr = "The daemon is not running.")
  )
  not_running <- NULL
  shown <- capture_shown(not_running <- lms_daemon_stop())
  expect_true(not_running)
  expect_match(shown$messages, "already stopped", fixed = TRUE)
})

test_that("lms_daemon_stop(force = TRUE) stops the server before the daemon", {
  calls <- local_lms_calls()

  capture_shown(lms_daemon_stop(force = TRUE))

  expect_identical(calls$args, list(c("server", "stop"), c("daemon", "down")))
})

test_that("with_lms_daemon() starts the daemon, runs the code, and stops the server and the daemon", {
  calls <- local_lms_calls()
  ran <- NULL

  shown <- capture_shown(value <- with_lms_daemon({
    ran <- calls$args
    "replies"
  }))

  expect_null(shown$error)
  expect_identical(value, "replies")
  # The code ran after the daemon started.
  expect_identical(ran, list(c("daemon", "up")))
  expect_identical(
    calls$args,
    list(c("daemon", "up"), c("server", "stop"), c("daemon", "down"))
  )
})

test_that("with_lms_daemon() stops the server and the daemon when the code fails", {
  calls <- local_lms_calls()

  shown <- capture_shown(with_lms_daemon(stop("The code failed.")))

  expect_match(conditionMessage(shown$error), "The code failed.", fixed = TRUE)
  expect_identical(
    calls$args,
    list(c("daemon", "up"), c("server", "stop"), c("daemon", "down"))
  )
})

test_that("a host argument sends the prompt to that computer", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(
    mock_response(200L, output_body(responses_message(output_text(quoted("Hello")))))
  )

  lms_chat("a-model", input = "Say hello.", host = "http://192.168.1.20:1234")

  sent <- request_target(recorder$requests[[1]])
  expect_identical(sent[["host"]], "192.168.1.20:1234")
  expect_identical(sent[["body"]][["input"]], "Say hello.")
})

test_that("lms_load(), lms_chat(), and lms_unload() take a host argument", {
  fns <- list(lms_load = lms_load, lms_chat = lms_chat, lms_unload = lms_unload)
  for (name in names(fns)) {
    test_that(name, {
      expect_identical(formals(fns[[name]])[["host"]], "http://localhost:1234")
    })
  }
})

test_that("a host argument sends the readiness request to that computer", {
  asked <- NULL
  local_mocked_bindings(
    req_perform = function(req, ...) {
      asked <<- req$url
      stop("No server here.")
    },
    .package = "httr2"
  )

  expect_false(lms_server_ready(host = "http://192.168.1.20:1234"))
  expect_match(asked, "^http://192\\.168\\.1\\.20:1234/")
})
