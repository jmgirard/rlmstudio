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
