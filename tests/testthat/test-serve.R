test_that("build_args_server_start constructs correct arguments", {
  expect_equal(build_args_server_start(), c("server", "start"))
  expect_equal(
    build_args_server_start(port = 3000, cors = TRUE),
    c("server", "start", "--port", "3000", "--cors")
  )
})

test_that("build_args_server_status handles logging flags", {
  expect_equal(
    build_args_server_status(json = TRUE, quiet = TRUE),
    c("server", "status", "--json", "--quiet")
  )
})

test_that("lms_server_start handles success and failure", {
  mock_run_success <- function(command, args, error_on_status) list(status = 0)
  local_mocked_bindings(run = mock_run_success, .package = "processx")

  suppressMessages({
    expect_equal(lms_server_start(port = 8080), 0)
  })

  mock_run_fail <- function(command, args, error_on_status) list(status = 1)
  local_mocked_bindings(run = mock_run_fail, .package = "processx")

  expect_error(lms_server_start(), "Failed to start the LM Studio server")
})

# Open a listening socket on a free port and return it with the port number.
# The caller closes the socket.
local_listener <- function(env = parent.frame()) {
  for (i in seq_len(50)) {
    port <- sample(20000:40000, 1)
    srv <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(srv)) {
      withr::defer(close(srv), envir = env)
      return(port)
    }
  }
  stop("No free port found.")
}

# Return a port number that nothing listens on.
free_port <- function() {
  for (i in seq_len(50)) {
    port <- sample(20000:40000, 1)
    srv <- tryCatch(serverSocket(port), error = function(e) NULL)
    if (!is.null(srv)) {
      close(srv)
      return(port)
    }
  }
  stop("No free port found.")
}

test_that("is_server_running probes the hostname and port named in host", {
  port <- local_listener()
  expect_true(is_server_running(paste0("http://localhost:", port)))
  expect_true(is_server_running(paste0("http://127.0.0.1:", port)))
})

test_that("is_server_running is FALSE when nothing listens on the port", {
  port <- free_port()
  expect_false(is_server_running(paste0("http://localhost:", port)))
})

test_that("is_server_running is FALSE for a hostname that is not listening", {
  port <- local_listener()
  expect_false(is_server_running(paste0("http://nowhere.invalid:", port)))
})

test_that("is_server_running falls back to port 1234 when host names none", {
  seen <- NULL
  local_mocked_bindings(
    socketConnection = function(host, port, ...) {
      seen <<- list(host = host, port = port)
      stop("no listener")
    },
    .package = "base"
  )
  expect_false(is_server_running("http://example.org"))
  expect_equal(seen, list(host = "example.org", port = 1234))
})

test_that("is_server_running strips the brackets of an IPv6 literal", {
  seen <- NULL
  local_mocked_bindings(
    socketConnection = function(host, port, ...) {
      seen <<- list(host = host, port = port)
      stop("no listener")
    },
    .package = "base"
  )
  expect_false(is_server_running("http://[::1]:4321"))
  expect_equal(seen, list(host = "::1", port = 4321L))
})

test_that("is_server_running reads a schemeless host as http", {
  port <- local_listener()
  expect_true(is_server_running(paste0("localhost:", port)))
})

test_that("is_server_running is FALSE for a host that does not parse", {
  expect_false(is_server_running("http://exa mple:1234"))
  expect_false(is_server_running(""))
})

test_that("lms_server_status warns on multiple logging flags", {
  mock_run <- function(command, args, error_on_status) {
    list(status = 0, stdout = "ok", stderr = "")
  }
  local_mocked_bindings(run = mock_run, .package = "processx")

  expect_warning(
    lms_server_status(verbose = TRUE, quiet = TRUE),
    "Only one logging control flag can be used at a time"
  )
})

# server_status_port() reads the port out of what the CLI reports. The two
# live shapes below were recorded from `lms server status --json` on
# 2026-09-20 against LM Studio CLI commit 69d945a. The output is one flat
# JSON object, so the port sits at the top level of the parsed list.

test_that("server_status_port reads the port out of the live status shape", {
  local_mocked_bindings(
    lms_server_status = function(...) list(running = TRUE, port = 1234L)
  )
  expect_identical(server_status_port(), 1234L)
})

test_that("server_status_port ignores the running flag", {
  # The CLI reports the last used port while the server is stopped, and it can
  # still report FALSE in the moment right after a start.
  local_mocked_bindings(
    lms_server_status = function(...) list(running = FALSE, port = 1234L)
  )
  expect_identical(server_status_port(), 1234L)
})

test_that("server_status_port returns NULL for a shape with no port", {
  local_mocked_bindings(
    lms_server_status = function(...) list(running = TRUE)
  )
  expect_null(server_status_port())
})

test_that("server_status_port returns NULL for the unparsed character shape", {
  # lms_server_status() falls back to a character vector of lines when
  # jsonlite is missing or the output does not parse.
  local_mocked_bindings(
    lms_server_status = function(...) c("{\"running\":true,", "\"port\":1234}")
  )
  expect_null(server_status_port())
})

test_that("server_status_port returns NULL for a port it cannot use", {
  unusable <- list(
    null_port = NULL,
    two_ports = c(1234L, 5678L),
    missing = NA_integer_,
    logical_port = TRUE,
    list_port = list(1234L),
    zero = 0L,
    too_high = 70000L,
    fractional = 1234.5
  )

  for (name in names(unusable)) {
    value <- unusable[[name]]
    local_mocked_bindings(
      lms_server_status = function(...) list(running = TRUE, port = value)
    )
    expect_null(server_status_port(), info = name)
  }
})

test_that("server_status_port accepts a port sent as a string", {
  local_mocked_bindings(
    lms_server_status = function(...) list(running = TRUE, port = "8080")
  )
  expect_identical(server_status_port(), 8080L)
})

test_that("server_status_port returns NULL when the status call aborts", {
  local_mocked_bindings(
    lms_server_status = function(...) cli::cli_abort("no CLI here")
  )
  expect_null(server_status_port())
})
