# A server that requires authentication answers a rejected call with HTTP
# status 401 or 403. The abort gains a hint, and which hint it gains depends on
# whether the request carried a token. Status 400 is the silent control: it is a
# failure that authentication has nothing to do with, so no hint appears.
#
# Every case runs through the recorder, and ambient state is pinned so a token
# in the caller's own environment cannot decide the branch.

rejected_token <- "rejected-token"

# Drive list_models() against one status and return the condition it raised.
rejected_condition <- function(status, extra = list()) {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(status, '{"error": "Denied"}'))

  tryCatch(
    suppressMessages(do.call(list_models, c(list(quiet = TRUE), extra))),
    rlmstudio_api_error = function(cnd) cnd
  )
}

# The message as the user reads it, hint lines included.
#
# This reads conditionMessage() rather than the printed condition. Printing an
# rlang error also prints a backtrace, and the backtrace echoes the caller's
# own source line. A caller who writes the token as a literal therefore sees it
# in their own backtrace, which the package neither composes nor can suppress.
# What the package does compose is the message, so that is what is asserted.
rendered_message <- function(condition) {
  cli::ansi_strip(conditionMessage(condition))
}

test_that("a rejected call with no token names the environment variable", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  for (status in c(401L, 403L)) {
    condition <- rejected_condition(status)

    expect_s3_class(condition, "rlmstudio_api_error")
    expect_identical(condition$status, status)

    rendered <- rendered_message(condition)
    expect_match(rendered, "RLMSTUDIO_API_TOKEN", fixed = TRUE, info = status)
  }
})

test_that("a rejected call that sent a token says the server rejected it", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  for (status in c(401L, 403L)) {
    condition <- rejected_condition(status, list(token = rejected_token))

    expect_s3_class(condition, "rlmstudio_api_error")
    expect_identical(condition$status, status)

    rendered <- rendered_message(condition)
    expect_match(
      rendered,
      "The server rejected the API token that was sent.",
      fixed = TRUE,
      info = status
    )
    # The variable belongs to the other branch, and the value never belongs
    # in the message at all.
    expect_false(grepl("RLMSTUDIO_API_TOKEN", rendered, fixed = TRUE))
    expect_false(grepl(rejected_token, rendered, fixed = TRUE))
  }
})

test_that("a failure that is not an authentication failure gains no hint", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  condition <- rejected_condition(400L)

  expect_s3_class(condition, "rlmstudio_api_error")
  expect_identical(condition$status, 400L)

  rendered <- rendered_message(condition)
  # The control has to show the abort actually rendered, or the two negatives
  # below would pass against an empty string.
  expect_match(rendered, "API List Failed", fixed = TRUE)
  expect_false(grepl("RLMSTUDIO_API_TOKEN", rendered, fixed = TRUE))
  expect_false(grepl("rejected the API token", rendered, fixed = TRUE))
})

test_that("a resolved token from the environment picks the rejected branch", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "from-the-variable")
  withr::local_options(rlmstudio.token = NULL)

  condition <- rejected_condition(401L)

  expect_s3_class(condition, "rlmstudio_api_error")
  rendered <- rendered_message(condition)
  expect_match(rendered, "The server rejected the API token", fixed = TRUE)
})
