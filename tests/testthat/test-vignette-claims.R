# Tests for claims that `vignettes/text-analysis.Rmd` makes about package
# functions, where no other test checked the claim.

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

test_that("lms_score_expected() reads the rows of the first step, keeps the scale, and rescales", {
  # Step 1 holds "3", "4", a number outside the scale, and a newline. Step 2
  # holds a "5" and step 3 a "2". Step 3 has the same token as step 1, and
  # neither later step counts.
  lp_df <- data.frame(
    step_token = c("3", "3", "3", "3", "\n", "\n", "3"),
    step_logprob = c(-0.5, -0.5, -0.5, -0.5, -0.1, -0.1, -0.2),
    candidate_token = c("3", "4", "6", "\n", "\n", "5", "2"),
    candidate_logprob = log(c(0.4, 0.2, 0.1, 0.1, 0.9, 0.1, 0.2)),
    step = c(1L, 1L, 1L, 1L, 2L, 2L, 3L),
    stringsAsFactors = FALSE
  )

  res <- lms_score_expected(lp_df, scale = 1:5)

  # Kept: 3 (0.4) and 4 (0.2) from the rows of step 1.
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
