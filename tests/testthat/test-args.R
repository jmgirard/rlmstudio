# tests/testthat/test-args.R

test_that("build_args_model_chat handles arguments correctly", {
  # Default
  expect_equal(build_args_model_chat(), c("chat"))

  # With model and prompt
  expect_equal(
    build_args_model_chat(model = "llama3", prompt = "Hello"),
    c("chat", "llama3", "--prompt", "Hello")
  )

  # With all arguments
  expect_equal(
    build_args_model_chat(
      model = "llama3",
      prompt = "Hello",
      system_prompt = "You are a helpful assistant",
      stats = TRUE,
      ttl = 3600
    ),
    c("chat", "llama3", "--prompt", "Hello", "--system-prompt", "You are a helpful assistant", "--stats", "--ttl", "3600")
  )
})

test_that("build_args_server_start handles arguments correctly", {
  # Default
  expect_equal(build_args_server_start(), c("server", "start"))

  # With port and CORS
  expect_equal(
    build_args_server_start(port = 8080, cors = TRUE),
    c("server", "start", "--port", "8080", "--cors")
  )
})

test_that("build_args_server_status handles arguments correctly", {
  # Default
  expect_equal(build_args_server_status(), c("server", "status"))

  # With JSON and verbose
  expect_equal(
    build_args_server_status(json = TRUE, verbose = TRUE),
    c("server", "status", "--json", "--verbose")
  )

  # With log_level
  expect_equal(
    build_args_server_status(log_level = "debug"),
    c("server", "status", "--log-level", "debug")
  )
})
