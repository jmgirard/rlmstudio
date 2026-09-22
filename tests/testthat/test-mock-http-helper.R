# The request-reading helpers in helper-mock-http.R carry logic of their own.
# Every header assertion in this suite reads a request through them, so a
# helper that silently skips would let those assertions pass by not running.

test_that("httpuv_absence_action() runs when httpuv is installed", {
  expect_identical(httpuv_absence_action(installed = TRUE, ci = ""), "run")
  expect_identical(httpuv_absence_action(installed = TRUE, ci = "true"), "run")
})

test_that("httpuv_absence_action() fails when httpuv is missing under CI", {
  expect_identical(httpuv_absence_action(installed = FALSE, ci = "true"), "fail")
})

test_that("httpuv_absence_action() skips when httpuv is missing off CI", {
  expect_identical(httpuv_absence_action(installed = FALSE, ci = ""), "skip")
})

test_that("require_httpuv() raises on the fail branch", {
  expect_error(require_httpuv("fail"), "CI is set")
})

test_that("require_httpuv() returns on the run branch", {
  expect_true(require_httpuv("run"))
})

test_that("request_target() reports the Authorization header unredacted", {
  req <- lms_client("http://localhost:1234", token = "helper-token")

  target <- request_target(req)

  expect_identical(target$headers$authorization, "Bearer helper-token")
})

test_that("request_target() reports no Authorization header when none is set", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  target <- request_target(lms_client("http://localhost:1234"))

  expect_null(target$headers$authorization)
})

test_that("local_request_sequence() serves its responses in order", {
  recorder <- local_request_sequence(list(
    mock_response(200L, '{"n": 1}'),
    mock_response(200L, '{"n": 2}')
  ))
  req <- httr2::request("http://localhost:1234")

  first <- httr2::req_perform(req)
  second <- httr2::req_perform(req)

  expect_identical(httr2::resp_body_json(first)$n, 1L)
  expect_identical(httr2::resp_body_json(second)$n, 2L)
  expect_length(recorder$requests, 2L)
})

test_that("local_request_sequence() raises on a request past its list", {
  local_request_sequence(list(mock_response(200L, '{"n": 1}')))
  req <- httr2::request("http://localhost:1234")
  httr2::req_perform(req)

  expect_error(httr2::req_perform(req), "request 2 arrived")
})
