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

test_that("request_target() reports the Authorization header unredacted on opt-in", {
  req <- lms_client("http://localhost:1234", token = "helper-token")

  target <- request_target(req, redact_headers = FALSE)

  expect_identical(target$headers$authorization, "Bearer helper-token")
})

test_that("request_target() redacts the Authorization header by default", {
  req <- lms_client("http://localhost:1234", token = "helper-token")

  value <- request_target(req)$headers$authorization

  expect_s3_class(value, "httr2_redacted_sentinel")
  expect_false(any(grepl("helper-token", format(value), fixed = TRUE)))
})

test_that("request_target() reports no Authorization header when none is set", {
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")
  withr::local_options(rlmstudio.token = NULL)

  target <- request_target(
    lms_client("http://localhost:1234"),
    redact_headers = FALSE
  )

  expect_null(target$headers$authorization)
})

test_that("request_target() parses a JSON body", {
  req <- httr2::request("http://localhost:1234") |>
    httr2::req_body_raw('{"model": "m", "n": 2}', type = "application/json")

  expect_identical(request_target(req)$body, list(model = "m", n = 2L))
})

test_that("request_target() returns a body that is not JSON as its text", {
  # A text that names a URL is the case jsonlite::fromJSON() would fetch.
  for (text in c("not json {", "http://localhost:1/never")) {
    req <- httr2::request("http://localhost:1234") |>
      httr2::req_body_raw(text, type = "text/plain")

    expect_identical(request_target(req)$body, text, info = text)
  }
})

# Hold `port` on 127.0.0.1 alone, as another program can, until `env` exits.
# The listener answers every request with an empty 200.
local_loopback_listener <- function(port, env = parent.frame()) {
  id <- httpuv::startServer(
    "127.0.0.1",
    port,
    list(call = function(req) list(status = 200L, headers = list(), body = ""))
  )
  withr::defer(httpuv::stopServer(id), envir = env)
  invisible(port)
}

# Mock the port picker that curl_echo() calls for each dry run. `pick` takes
# the try number, counted from 1, and returns the port for that try. Read the
# number of tries from `tries$n`.
local_dry_run_ports <- function(pick, env = parent.frame()) {
  tries <- new.env(parent = emptyenv())
  tries$n <- 0L
  testthat::local_mocked_bindings(
    find_port = function(...) {
      tries$n <- tries$n + 1L
      pick(tries$n)
    },
    .package = "curl",
    .env = env
  )
  tries
}

test_that("request_target() reads a request when another program holds the first dry-run port", {
  require_httpuv()
  held <- free_port()
  local_loopback_listener(held)
  # free_port() binds all addresses, which a macOS host allows over a port
  # that 127.0.0.1 alone holds, so the held port is left out of the scan.
  spare <- free_port(setdiff(20000:40000, held))
  tries <- local_dry_run_ports(function(n) if (n == 1L) held else spare)
  req <- httr2::request("http://localhost:1234/v1/models/load") |>
    httr2::req_body_raw('{"model": "m"}', type = "application/json")

  target <- request_target(req)

  expect_identical(target$method, "POST")
  expect_identical(target$path, "/v1/models/load")
  expect_identical(target$body, list(model = "m"))
  expect_identical(tries$n, 2L)
})

# A port held on all addresses makes the echo server's own bind fail, which is
# the other outcome the dry-run helper tries again on.
test_that("request_target() reads a request when the echo server cannot bind the first port", {
  require_httpuv()
  held <- local_listener()
  spare <- free_port(setdiff(20000:40000, held))
  tries <- local_dry_run_ports(function(n) if (n == 1L) held else spare)
  req <- httr2::request("http://localhost:1234/v1/models/load") |>
    httr2::req_body_raw('{"model": "m"}', type = "application/json")

  target <- request_target(req)

  expect_identical(target$method, "POST")
  expect_identical(target$body, list(model = "m"))
  expect_identical(tries$n, 2L)
})

# An httpuv handler that returns NULL sends no reply, as a program that does
# not speak HTTP can do. The dry run then ends with a curl error, which is the
# third outcome the dry-run helper tries again on.
test_that("request_target() reads a request when the program on the first dry-run port never replies", {
  require_httpuv()
  held <- free_port()
  id <- httpuv::startServer("127.0.0.1", held, list(call = function(req) NULL))
  withr::defer(httpuv::stopServer(id))
  spare <- free_port(setdiff(20000:40000, held))
  tries <- local_dry_run_ports(function(n) if (n == 1L) held else spare)
  req <- httr2::request("http://localhost:1234/v1/models/load") |>
    httr2::req_body_raw('{"model": "m"}', type = "application/json")

  target <- request_target(req)

  expect_identical(target$method, "POST")
  expect_identical(target$body, list(model = "m"))
  expect_identical(tries$n, 2L)
})

test_that("the dry-run helper names the cause when every try lands on a held port", {
  require_httpuv()
  held <- free_port()
  local_loopback_listener(held)
  tries <- local_dry_run_ports(function(n) held)
  req <- httr2::request("http://localhost:1234/v1/chat") |>
    httr2::req_body_raw('{"model": "m"}', type = "application/json")

  cnd <- expect_error(request_body_text(req))

  message <- conditionMessage(cnd)
  expect_match(message, "received no request", fixed = TRUE)
  expect_match(tolower(message), "another program", fixed = TRUE)
  expect_no_match(message, "must be a raw vector", fixed = TRUE)
  expect_identical(tries$n, 5L)
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
