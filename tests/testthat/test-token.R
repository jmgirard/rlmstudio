# The token strings here are dummies. A test reads the Authorization header
# with redact_headers = FALSE, so a failure prints the literal value.

# Read the Authorization header off a request as it would go over the wire.
# Returns NULL when the request carries no such header.
auth_header <- function(req) {
  require_httpuv()
  out <- httr2::req_dry_run(req, quiet = TRUE, redact_headers = FALSE)
  out$headers$authorization
}

test_that("rlm_token() reads the argument over the option and the variable", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "from-the-variable")
  withr::local_options(rlmstudio.token = "from-the-option")

  expect_identical(rlm_token("from-the-argument"), "from-the-argument")
})

test_that("rlm_token() reads the option over the variable", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "from-the-variable")
  withr::local_options(rlmstudio.token = "from-the-option")

  expect_identical(rlm_token(), "from-the-option")
})

test_that("rlm_token() reads the variable when it is the only source set", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "from-the-variable")
  withr::local_options(rlmstudio.token = NULL)

  expect_identical(rlm_token(), "from-the-variable")
})

test_that("rlm_token() returns NULL when no source is set", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  expect_null(rlm_token())
})

test_that("lms_client() sends a bearer token when one resolves", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  req <- lms_client("http://localhost:1234", token = "header-token")

  expect_identical(auth_header(req), "Bearer header-token")
})

test_that("lms_client() sends no Authorization header when none resolves", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  req <- lms_client("http://localhost:1234")

  expect_null(auth_header(req))
})

test_that("printing a token-carrying request does not show the token", {
  secret <- "print-should-not-show-this"

  req <- lms_client("http://localhost:1234", token = secret)
  rendered <- paste(utils::capture.output(print(req)), collapse = "\n")

  # The negative on its own would pass against a request that carries no
  # header at all, so assert that the header is there and redacted.
  expect_false(grepl(secret, rendered, fixed = TRUE))
  expect_match(rendered, "Authorization")
  expect_match(rendered, "REDACTED")
})

test_that("an API failure raised from a token-carrying request hides the token", {
  secret <- "abort-should-not-show-this"

  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(401L, '{"error": "Unauthorized"}'))

  condition <- tryCatch(
    suppressMessages(list_models(quiet = TRUE, token = secret)),
    rlmstudio_api_error = function(cnd) cnd
  )

  # Assert the identity of the failure before reading its message, so the
  # negative below cannot pass against some other error.
  expect_s3_class(condition, "rlmstudio_api_error")
  expect_identical(condition$status, 401L)

  # conditionMessage() is what the package composes. Printing the condition
  # also prints a backtrace, and the backtrace echoes the caller's own source
  # line, so a token written there as a literal shows up for reasons the
  # package neither causes nor can suppress.
  rendered <- cli::ansi_strip(conditionMessage(condition))
  expect_match(rendered, "API List Failed", fixed = TRUE)
  expect_false(grepl(secret, rendered, fixed = TRUE))
})

test_that("lms_client() reads the option and the variable, not just the argument", {
  withr::local_options(rlmstudio.token = NULL)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "variable-token")
  expect_identical(
    auth_header(lms_client("http://localhost:1234")),
    "Bearer variable-token"
  )

  withr::local_options(rlmstudio.token = "option-token")
  expect_identical(
    auth_header(lms_client("http://localhost:1234")),
    "Bearer option-token"
  )
})
