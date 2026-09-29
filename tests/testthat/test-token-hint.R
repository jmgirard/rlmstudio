# The 401 and 403 hint says whether the request carried a token. Each REST
# wrapper reads that flag off the request it built. These tests change the
# rlmstudio.token option between the request build and the reply, inside the
# mocked req_perform(). A wrapper that read the token sources again after the
# reply would then give the other hint.
#
# The table has one entry for each call of rlm_abort_api() in R/. `label`
# opens the message of that call, so a test can tell which call raised.

hint_sites <- list(
  list(
    label = "OpenResponses Failed",
    call = function() lms_chat_openresponses("m", "hello")
  ),
  list(
    label = "OpenAI API Failed",
    call = function() {
      lms_chat_openai("m", list(list(role = "user", content = "hello")))
    }
  ),
  list(
    label = "Native API Failed",
    call = function() lms_chat_native("m", "hello")
  ),
  list(
    label = "API List Failed",
    call = function() list_models(quiet = TRUE)
  ),
  list(
    label = "API Download Failed",
    call = function() lms_download("test-model")
  ),
  list(
    label = "API Status Request Failed",
    call = function() lms_download_status("job-1")
  ),
  list(
    label = "Embeddings Failed",
    call = function() lms_embed("m", "hello")
  ),
  # force = TRUE skips the model-list check, so the one request is the load.
  list(
    label = "API Load Failed",
    call = function() lms_load("test-model", force = TRUE)
  ),
  list(
    label = "API Unload Failed",
    call = function() lms_unload("test-model")
  )
)

# Run one site against a 401 reply. `at_reply` is the value the
# rlmstudio.token option takes after the request is built and before the
# reply returns. Returns the message as the user reads it and the requests
# sent.
hint_run <- function(site, at_reply) {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_mock_perform(
    function(n) {
      options(rlmstudio.token = at_reply)
      mock_response(401L, '{"error": "Denied"}')
    },
    .env = environment()
  )

  condition <- tryCatch(
    suppressMessages(site$call()),
    rlmstudio_api_error = function(cnd) cnd
  )

  list(
    condition = condition,
    message = cli::ansi_strip(conditionMessage(condition)),
    requests = recorder$requests
  )
}

test_that("the site table covers every rlm_abort_api() call in R/", {
  # test_path() finds R/ under devtools::test() only, so this check skips
  # under R CMD check (LESSONS, M005).
  r_dir <- testthat::test_path("..", "..", "R")
  skip_if_not(dir.exists(r_dir), "package sources are not here")

  hits <- 0L
  for (file in list.files(r_dir, pattern = "[.]R$", full.names = TRUE)) {
    lines <- readLines(file)
    hits <- hits + sum(
      grepl("rlm_abort_api(", lines, fixed = TRUE) & !grepl("^\\s*#'", lines)
    )
  }

  expect_gt(hits, 0L)
  expect_identical(length(hint_sites), hits)
})

test_that("a token sent and then cleared gives the rejected-token hint", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")

  for (site in hint_sites) {
    withr::local_options(rlmstudio.token = "hint-token")
    out <- hint_run(site, at_reply = NULL)

    expect_true(
      inherits(out$condition, "rlmstudio_api_error"),
      info = site$label
    )
    expect_identical(out$condition$status, 401L, info = site$label)
    expect_identical(length(out$requests), 1L, info = site$label)
    expect_identical(
      request_target(out$requests[[1]], redact_headers = FALSE)$headers$authorization,
      "Bearer hint-token",
      info = site$label
    )
    expect_match(out$message, site$label, fixed = TRUE, info = site$label)
    expect_match(
      out$message,
      "The server rejected the API token that was sent.",
      fixed = TRUE,
      info = site$label
    )
    expect_no_match(
      out$message,
      "RLMSTUDIO_API_TOKEN",
      fixed = TRUE,
      info = site$label
    )
  }
})

test_that("no token sent and then one set gives the hint that names the variable", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")

  for (site in hint_sites) {
    withr::local_options(rlmstudio.token = NULL)
    out <- hint_run(site, at_reply = "late-token")

    expect_true(
      inherits(out$condition, "rlmstudio_api_error"),
      info = site$label
    )
    expect_identical(out$condition$status, 401L, info = site$label)
    expect_identical(length(out$requests), 1L, info = site$label)
    expect_null(
      request_target(out$requests[[1]], redact_headers = FALSE)$headers$authorization,
      info = site$label
    )
    expect_match(out$message, site$label, fixed = TRUE, info = site$label)
    expect_match(
      out$message,
      "RLMSTUDIO_API_TOKEN",
      fixed = TRUE,
      info = site$label
    )
    expect_no_match(
      out$message,
      "The server rejected",
      fixed = TRUE,
      info = site$label
    )
  }
})

test_that("request_sends_token() reads the header name in any case", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  expect_true(request_sends_token(lms_client(token = "t")))
  expect_false(request_sends_token(lms_client()))
  lower <- httr2::req_headers(httr2::request("http://x"), authorization = "t")
  expect_true(request_sends_token(lower))
})
