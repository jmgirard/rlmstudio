# libcurl reads the proxy variables, and with no_proxy unset it sends even a
# request for localhost, 127.0.0.1, or [::1] to the proxy. lms_client() builds
# every request of the package, and for those three hostnames it tells curl to
# skip the proxy. These tests start a test server and a test proxy in this
# process, set the proxy variables to the test proxy, and read which of the two
# got the request. They call lms_server_ready() and not request_dry_run(),
# which sets noproxy itself and so would hide what lms_client() does.

# Start an httpuv server on `bind` that records the path of each request it
# reads. httpuv runs the R handler for a request only while R runs
# httpuv::service(), later::run_now(), or sits idle at the prompt.
# httr2::req_perform() blocks R, so no request gets an answer during the call.
# The request waits in the socket, and serve_pending() reads it after the call
# times out. For a request sent to a proxy, the path is the full URL. The port
# leaves out `exclude`: on macOS free_port() can return a port that an httpuv
# server holds on one address. The server stops when `env` exits. If it cannot
# start, the error comes back as the value.
local_recorder <- function(bind, exclude = integer(), env = parent.frame()) {
  hits <- character()
  port <- free_port(setdiff(20000:40000, exclude))
  app <- list(call = function(req) {
    hits <<- c(hits, req$PATH_INFO)
    list(
      status = 200L,
      headers = list("Content-Type" = "application/json"),
      body = '{"models": []}'
    )
  })
  server <- tryCatch(httpuv::startServer(bind, port, app), error = identity)
  if (inherits(server, "error")) {
    return(server)
  }
  withr::defer(httpuv::stopServer(server), envir = env)
  list(port = port, hits = function() hits)
}

# Set every proxy variable that libcurl reads to `proxy`, and unset no_proxy.
local_proxy_env <- function(proxy, env = parent.frame()) {
  withr::local_envvar(
    http_proxy = proxy, https_proxy = proxy, all_proxy = proxy,
    HTTPS_PROXY = proxy, ALL_PROXY = proxy,
    no_proxy = NA, NO_PROXY = NA,
    .local_envir = env
  )
}

# Run httpuv until one of `recorders` holds a request, for 2 seconds at most.
serve_pending <- function(recorders, seconds = 2) {
  end <- Sys.time() + seconds
  while (Sys.time() < end) {
    httpuv::service(10)
    if (any(vapply(recorders, \(r) length(r$hits()) > 0L, logical(1)))) {
      return(invisible())
    }
  }
}

# Send the readiness request to a test server at `hostname`, with the proxy
# variables set to a test proxy, and return what each one recorded. `bind` is
# the address the test server listens on.
proxy_round <- function(hostname, bind) {
  proxy <- local_recorder("127.0.0.1")
  server <- local_recorder(bind, exclude = proxy$port)
  if (inherits(server, "error")) {
    return(server)
  }
  local_proxy_env(paste0("http://127.0.0.1:", proxy$port))
  lms_server_ready(
    host = paste0("http://", hostname, ":", server$port),
    timeout = 0.2
  )
  serve_pending(list(proxy, server))
  list(server = server$hits(), proxy = proxy$hits())
}

test_that("a request to localhost or 127.0.0.1 skips a set proxy", {
  require_httpuv()
  for (hostname in c("localhost", "LOCALHOST", "127.0.0.1")) {
    test_that(paste("hostname", hostname), {
      hits <- proxy_round(hostname, bind = "127.0.0.1")
      expect_identical(hits$server, "/api/v1/models", info = hostname)
      expect_identical(hits$proxy, character(), info = hostname)
    })
  }
})

# A machine with no IPv6 loopback cannot run this case. Off CI it skips. On
# CI it fails, so a runner that loses ::1 cannot pass the case by not running
# it.
test_that("a request to [::1] skips a set proxy", {
  require_httpuv()
  hits <- proxy_round("[::1]", bind = "::1")
  if (inherits(hits, "error")) {
    if (nzchar(Sys.getenv("CI"))) {
      fail(paste("The test server cannot listen on ::1:", conditionMessage(hits)))
    }
    skip(paste("This machine cannot listen on ::1:", conditionMessage(hits)))
  }
  expect_identical(hits$server, "/api/v1/models")
  expect_identical(hits$proxy, character())
})

test_that("a request to another host still goes to a set proxy", {
  require_httpuv()
  proxy <- local_recorder("127.0.0.1")
  local_proxy_env(paste0("http://127.0.0.1:", proxy$port))

  lms_server_ready(host = "http://lmstudio.test:1234", timeout = 0.2)
  serve_pending(list(proxy))

  expect_identical(proxy$hits(), "http://lmstudio.test:1234/api/v1/models")
})
