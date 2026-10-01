# Tests for claims that `vignettes/text-analysis.Rmd` and
# `vignettes/getting-started.Rmd` make about package functions, where no other
# test checked the claim.

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
