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

  # wait = 0 keeps this case about the exit code. The wait has its own cases
  # below, and a default wait here would reach the network.
  suppressMessages({
    expect_equal(lms_server_start(port = 8080, wait = 0), 0)
  })

  mock_run_fail <- function(command, args, error_on_status) list(status = 1)
  local_mocked_bindings(run = mock_run_fail, .package = "processx")

  expect_error(lms_server_start(), "Failed to start the LM Studio server")
})

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

test_that("server_status_port raises no warning when the output does not parse", {
  # lms_server_status() warns before it falls back to the character shape.
  # The caller raises its own warning for a missing port, so this one would
  # be a second warning about the same fault.
  local_mocked_bindings(
    lms_server_status = function(...) {
      cli::cli_warn("Failed to parse JSON output.")
      c("not json")
    }
  )
  expect_no_warning(expect_null(server_status_port()))
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
    test_that(name, {
      value <- unusable[[name]]
      local_mocked_bindings(
        lms_server_status = function(...) list(running = TRUE, port = value)
      )
      expect_null(server_status_port(), info = name)
    })
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

# wait_for_server() reads the clock and sleeps. Both come from base, so both
# are replaced here by one fake clock that only a sleep moves forward. No
# test sleeps, and the budget arithmetic is exact rather than timing
# dependent.
fake_clock <- function(env = parent.frame()) {
  seconds <- 0
  slept <- numeric(0)

  local_mocked_bindings(
    Sys.time = function() {
      as.POSIXct(seconds, origin = "1970-01-01", tz = "UTC")
    },
    Sys.sleep = function(time) {
      slept <<- c(slept, time)
      seconds <<- seconds + time
      invisible(NULL)
    },
    .package = "base",
    .env = env
  )

  list(
    slept = function() slept,
    elapsed = function() seconds
  )
}

# A readiness stub that answers FALSE until the nth call and records every
# host and timeout it saw.
ready_stub <- function(true_on = Inf) {
  calls <- list()
  fn <- function(host = "http://localhost:1234", timeout = 2, token = NULL) {
    calls[[length(calls) + 1L]] <<- list(
      host = host,
      timeout = timeout,
      token = token
    )
    length(calls) >= true_on
  }
  list(fn = fn, calls = function() calls)
}

test_that("wait_for_server stops at the first TRUE", {
  clock <- fake_clock()
  stub <- ready_stub(true_on = 3)
  local_mocked_bindings(lms_server_ready = stub$fn)

  expect_true(wait_for_server("http://localhost:1234", wait = 10))
  # Three requests, and no fourth after the TRUE.
  expect_length(stub$calls(), 3)
  # Two sleeps, one between each pair of requests, at the chosen pause.
  expect_identical(clock$slept(), c(0.25, 0.25))
})

test_that("wait_for_server sends one request when the first answers", {
  clock <- fake_clock()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(lms_server_ready = stub$fn)

  expect_true(wait_for_server("http://localhost:1234", wait = 10))
  expect_length(stub$calls(), 1)
  expect_identical(clock$slept(), numeric(0))
})

test_that("wait_for_server passes the host, the timeout, and the token", {
  fake_clock()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(lms_server_ready = stub$fn)

  wait_for_server("http://elsewhere:8080", wait = 10, timeout = 0.5)
  wait_for_server("http://elsewhere:8080", wait = 10, token = "t")
  expect_identical(
    stub$calls()[[1]],
    list(host = "http://elsewhere:8080", timeout = 0.5, token = NULL)
  )
  expect_identical(
    stub$calls()[[2]],
    list(host = "http://elsewhere:8080", timeout = 1, token = "t")
  )
})

test_that("wait_for_server starts no request after the budget passes", {
  clock <- fake_clock()
  stub <- ready_stub(true_on = Inf)
  local_mocked_bindings(lms_server_ready = stub$fn)

  expect_false(wait_for_server("http://localhost:1234", wait = 1))
  # A budget of 1 second at a pause of 0.25 allows four requests. The fifth
  # would start at exactly the deadline, so it never starts.
  expect_length(stub$calls(), 4)
  expect_identical(clock$elapsed(), 1)
})

test_that("wait_for_server never sleeps past the deadline", {
  clock <- fake_clock()
  stub <- ready_stub(true_on = Inf)
  local_mocked_bindings(lms_server_ready = stub$fn)

  expect_false(wait_for_server("http://localhost:1234", wait = 0.6))
  # The last sleep is trimmed to what the budget has left. The subtraction
  # that trims it is floating point, so this compares with a tolerance.
  expect_equal(clock$slept(), c(0.25, 0.25, 0.1))
  expect_equal(clock$elapsed(), 0.6)
})

test_that("wait_for_server sends no request for a wait of zero", {
  clock <- fake_clock()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(lms_server_ready = stub$fn)

  expect_false(wait_for_server("http://localhost:1234", wait = 0))
  expect_length(stub$calls(), 0)
  expect_identical(clock$slept(), numeric(0))
})

test_that("wait_host follows the documented order", {
  # A host given wins over everything.
  expect_identical(
    wait_host(host = "http://elsewhere:9999", port = 8080),
    "http://elsewhere:9999"
  )
  # No host and a port builds the host from the port.
  expect_identical(wait_host(port = 8080), "http://localhost:8080")
  # Neither reads the port the CLI reports.
  local_mocked_bindings(
    lms_server_status = function(...) list(running = TRUE, port = 4321L)
  )
  expect_identical(wait_host(), "http://localhost:4321")
})

test_that("wait_host returns NULL when the port read yields nothing", {
  local_mocked_bindings(
    lms_server_status = function(...) list(running = TRUE)
  )
  expect_null(wait_host())
  # A host given still wins, so the failed read never reaches this case.
  local_mocked_bindings(
    lms_server_status = function(...) cli::cli_abort("no CLI here")
  )
  expect_identical(wait_host(host = "http://a:1"), "http://a:1")
})

# The four cases the start call itself owns. processx::run is stubbed, so no
# server is started, and the clock is faked, so no test sleeps.
start_success <- function() {
  local_mocked_bindings(
    run = function(command, args, error_on_status) list(status = 0),
    .package = "processx",
    .env = parent.frame()
  )
}

test_that("lms_server_start sends no readiness request for a wait of zero", {
  start_success()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(lms_server_ready = stub$fn)

  suppressMessages({
    expect_equal(lms_server_start(port = 8080, wait = 0), 0)
  })
  expect_length(stub$calls(), 0)
})

test_that("lms_server_start returns quietly once the server answers", {
  start_success()
  fake_clock()
  stub <- ready_stub(true_on = 3)
  local_mocked_bindings(lms_server_ready = stub$fn)

  suppressMessages({
    expect_no_warning(expect_equal(lms_server_start(port = 8080), 0))
  })
  expect_length(stub$calls(), 3)
  # The host came from the port.
  expect_identical(stub$calls()[[1]]$host, "http://localhost:8080")
})

test_that("lms_server_start warns rather than aborts when the wait runs out", {
  start_success()
  fake_clock()
  stub <- ready_stub(true_on = Inf)
  local_mocked_bindings(lms_server_ready = stub$fn)

  suppressMessages({
    warning <- expect_warning(
      expect_equal(lms_server_start(port = 8080, wait = 1), 0),
      "did not answer in time"
    )
  })
  # The warning names the host it asked and the argument to raise.
  expect_match(conditionMessage(warning), "localhost:8080")
  expect_match(conditionMessage(warning), "wait")
  expect_match(conditionMessage(warning), "1 second\\b")
})

test_that("lms_server_start warns when it cannot tell which host to ask", {
  start_success()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(
    lms_server_ready = stub$fn,
    lms_server_status = function(...) list(running = TRUE)
  )

  suppressMessages({
    warning <- expect_warning(
      expect_equal(lms_server_start(), 0),
      "Could not tell which host to ask"
    )
  })
  # No readiness request goes out in this case.
  expect_length(stub$calls(), 0)
  # The warning names the failed port read and both arguments.
  expect_match(conditionMessage(warning), "no port this package can use")
  expect_match(conditionMessage(warning), "host")
  expect_match(conditionMessage(warning), "port")
})

test_that("the success message and the readiness host print the port as digits", {
  start_success()
  fake_clock()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(lms_server_ready = stub$fn)
  # Under this option a double 8080 prints as "8.08e+03".
  withr::local_options(scipen = -5, rlmstudio.quiet = FALSE)

  msgs <- testthat::capture_messages(lms_server_start(port = 8080))
  expect_match(paste(msgs, collapse = ""), "on port 8080", fixed = TRUE)
  expect_identical(stub$calls()[[1]]$host, "http://localhost:8080")
})

test_that("lms_server_start asks the host the caller gave", {
  start_success()
  fake_clock()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(
    lms_server_ready = stub$fn,
    lms_server_status = function(...) list(running = TRUE, port = 5555L)
  )

  suppressMessages(
    lms_server_start(port = 8080, host = "http://127.0.0.1:9999")
  )
  expect_identical(stub$calls()[[1]]$host, "http://127.0.0.1:9999")
})

test_that("lms_server_start asks the port the status read reports", {
  start_success()
  fake_clock()
  stub <- ready_stub(true_on = 1)
  local_mocked_bindings(
    lms_server_ready = stub$fn,
    lms_server_status = function(...) list(running = TRUE, port = 5555L)
  )

  suppressMessages(lms_server_start())
  expect_identical(stub$calls()[[1]]$host, "http://localhost:5555")
})

test_that("a bad wait aborts before the CLI runs", {
  ran <- FALSE
  local_mocked_bindings(
    run = function(command, args, error_on_status) {
      ran <<- TRUE
      list(status = 0)
    },
    .package = "processx"
  )

  expect_error(lms_server_start(wait = -1), "negative number of seconds")
  expect_error(lms_server_start(wait = "10"), "character value")
  expect_error(lms_server_start(wait = NA), "missing value")
  expect_error(lms_server_start(wait = Inf), "not finite")
  expect_false(ran)

  # D-008: the abort that reaches the caller carries no rlmstudio class.
  err <- tryCatch(lms_server_start(wait = -1), condition = function(e) e)
  expect_s3_class(err, "rlang_error")
  expect_false(any(grepl("^rlmstudio", class(err))))
})

# The port and cors checks. The stub counts its calls and keeps the args of
# the last one, so a test can say both whether the CLI ran and what it got.
local_counting_run <- function(env = parent.frame()) {
  state <- new.env()
  state$calls <- 0L
  state$args <- NULL
  local_mocked_bindings(
    run = function(command, args, error_on_status) {
      state$calls <- state$calls + 1L
      state$args <- args
      list(status = 0)
    },
    .package = "processx",
    .env = env
  )
  # A value that slips past the checks would otherwise start a real wait.
  local_mocked_bindings(lms_server_ready = function(...) TRUE, .env = env)
  state
}

# Each rejected value runs once with wait = 0 and once with a host, so the
# check cannot hide behind a branch on either.
expect_start_rejects <- function(arg, value, rule, detail) {
  runs <- local_counting_run()
  extras <- list(list(wait = 0), list(host = "http://localhost:1234"))
  for (extra in extras) {
    call_args <- c(stats::setNames(list(value), arg), extra)
    label <- paste0(arg, " = ", deparse(value), ", ", names(extra))
    err <- tryCatch(
      suppressMessages(do.call(lms_server_start, call_args)),
      error = function(e) e
    )
    if (!inherits(err, "error")) {
      fail(paste0(label, " did not abort."))
      next
    }
    expect_false(any(grepl("^rlmstudio_", class(err))), label = label)
    msg <- conditionMessage(err)
    expect_match(msg, paste0("`", arg, "`"), fixed = TRUE, label = label)
    expect_match(msg, rule, fixed = TRUE, label = label)
    # The detail line names which fault this value has, so a swapped or
    # dropped detail turns the test red.
    expect_match(msg, detail, fixed = TRUE, label = label)
  }
  expect_identical(runs$calls, 0L)
}

test_that("a port that is not one whole number from 1 to 65535 aborts first", {
  missing <- "You gave a missing value."
  range <- "You gave a number outside that range."
  # Each value comes with the detail its fault must give.
  rejected <- list(
    # Not one plain number.
    list("8080", "You gave a character value."),
    list("abc", "You gave a character value."),
    list(TRUE, "You gave a logical value."),
    list(NA, missing),
    list(list(8080), "You gave a list value."),
    list(factor("8080"), "You gave a factor value."),
    list(c(8080, 8081), "You gave 2 values rather than one."),
    list(numeric(0), "You gave 0 values rather than one."),
    list(matrix(8080), "You gave an array rather than a single number."),
    # Missing or not finite.
    list(NA_real_, missing),
    list(NA_integer_, missing),
    list(NaN, missing),
    list(Inf, "You gave a value that is not finite."),
    list(-Inf, "You gave a value that is not finite."),
    # Out of range or not whole.
    list(-1, range),
    list(0, range),
    list(0L, range),
    list(8080.5, "You gave a number that is not whole."),
    list(65536, range),
    list(99999, range),
    list(1e10, range)
  )
  expect_length(rejected, 21L)
  for (case in rejected) {
    expect_start_rejects(
      "port", case[[1]],
      "must be `NULL` or one whole number from 1 to 65535", case[[2]]
    )
  }
})

test_that("an accepted port reaches the CLI as a whole-number string", {
  # A negative scipen prints the double 8080 as "8.08e+03", so this option
  # makes the integer step load-bearing.
  withr::local_options(scipen = -5)
  accepted <- list(1, 65535, 8080L, 8080, c(p = 8080))
  sent <- c("1", "65535", "8080", "8080", "8080")
  for (i in seq_along(accepted)) {
    runs <- local_counting_run()
    suppressMessages(lms_server_start(port = accepted[[i]], wait = 0))
    expect_identical(runs$calls, 1L)
    at <- match("--port", runs$args)
    expect_false(is.na(at))
    expect_identical(runs$args[[at + 1L]], sent[[i]])
    expect_null(names(runs$args))
  }

  runs <- local_counting_run()
  suppressMessages(lms_server_start(port = NULL, wait = 0))
  expect_identical(runs$calls, 1L)
  expect_false("--port" %in% runs$args)
})

test_that("a cors that is not TRUE or FALSE aborts first", {
  rejected <- list(
    list("yes", "You gave a character value."),
    list(1, "You gave a numeric value."),
    list(NA, "You gave NA."),
    list(NULL, "You gave NULL."),
    list(logical(0), "You gave 0 values rather than one."),
    list(c(TRUE, FALSE), "You gave 2 values rather than one.")
  )
  for (case in rejected) {
    expect_start_rejects(
      "cors", case[[1]], "must be `TRUE` or `FALSE`", case[[2]]
    )
  }
})

test_that("cors = TRUE sends --cors and cors = FALSE does not", {
  for (value in list(TRUE, c(x = TRUE), matrix(TRUE))) {
    runs <- local_counting_run()
    suppressMessages(lms_server_start(cors = value, wait = 0))
    expect_identical(runs$calls, 1L)
    expect_true("--cors" %in% runs$args)
  }

  runs <- local_counting_run()
  suppressMessages(lms_server_start(cors = FALSE, wait = 0))
  expect_identical(runs$calls, 1L)
  expect_false("--cors" %in% runs$args)
})

# The failed-start abort. cli wraps long bullets, so texts are compared after
# each whitespace run is collapsed to one space.
squish <- function(x) gsub("\\s+", " ", trimws(x))

start_failure_message <- function(res) {
  local_mocked_bindings(
    run = function(command, args, error_on_status) res,
    .package = "processx"
  )
  err <- tryCatch(lms_server_start(wait = 0), error = function(e) e)
  expect_s3_class(err, "error")
  squish(conditionMessage(err))
}

expect_quotes <- function(msg, text) {
  expect_true(grepl(squish(text), msg, fixed = TRUE), label = msg)
}

test_that("a failed start quotes the stderr text the CLI gave", {
  # Recorded from `lms server start --port abc` on 2026-09-28.
  stderr <- paste0(
    "error: option '-p, --port <port>' argument 'abc' is invalid. ",
    "Not a number\n"
  )
  msg <- start_failure_message(list(status = 1, stdout = "", stderr = stderr))
  expect_quotes(msg, "Exit code: 1")
  expect_quotes(msg, stderr)
})

test_that("a failed start quotes stdout when stderr holds nothing", {
  msg <- start_failure_message(
    list(status = 2, stdout = "Port is in use.\n", stderr = "")
  )
  expect_quotes(msg, "Exit code: 2")
  expect_quotes(msg, "Port is in use.")
})

test_that("braces in the CLI text reach the message as text", {
  msg <- start_failure_message(
    list(status = 1, stdout = "", stderr = "bad value {port} here")
  )
  expect_quotes(msg, "bad value {port} here")
})

test_that("a long stderr of two lines reaches the message whole", {
  stderr <- paste0(
    "error: the server could not start on the port that was asked for.\n",
    "  Another program may hold it; pick a different port and try again.\n"
  )
  expect_gt(nchar(stderr), 80)
  msg <- start_failure_message(list(status = 1, stdout = "", stderr = stderr))
  expect_quotes(msg, stderr)
})

test_that("a failed start with no CLI output gives the exit code alone", {
  empties <- list(
    list(status = 1),
    list(status = 1, stdout = NULL, stderr = NULL),
    list(status = 1, stdout = NA_character_, stderr = NA_character_),
    list(status = 1, stdout = " \n", stderr = "\t"),
    # trimws() alone keeps these two.
    list(status = 1, stdout = "\f", stderr = "\v\n"),
    # \s does not match a non-breaking space (LESSONS, M013).
    list(status = 1, stdout = "\u00a0", stderr = "\u00a0\u00a0")
  )
  for (res in empties) {
    msg <- start_failure_message(res)
    expect_quotes(msg, "Failed to start the LM Studio server. Exit code: 1.")
    expect_false(grepl("The CLI said", msg, fixed = TRUE), label = msg)
  }
})

test_that("stderr wins over stdout when both hold text", {
  msg <- start_failure_message(
    list(status = 1, stdout = "from stdout", stderr = "from stderr")
  )
  expect_quotes(msg, "from stderr")
  expect_false(grepl("from stdout", msg, fixed = TRUE), label = msg)
})

test_that("a stderr of only whitespace falls through to stdout", {
  for (stderr in c("  \n ", "\f", "\u00a0")) {
    msg <- start_failure_message(
      list(status = 1, stdout = "from stdout\n", stderr = stderr)
    )
    expect_quotes(msg, "from stdout")
  }
})

test_that("CLI text that is not valid UTF-8 keeps the exit code in the abort", {
  # The byte 0xff is never valid UTF-8. Before the fix, gsub() failed on it
  # with "input string 1 is invalid", and the exit code was lost.
  stderr <- rawToChar(as.raw(c(0x62, 0x61, 0x64, 0x20, 0xff, 0x0a)))
  warnings <- 0L
  msg <- withCallingHandlers(
    start_failure_message(list(status = 3, stdout = "", stderr = stderr)),
    warning = function(w) {
      warnings <<- warnings + 1L
      invokeRestart("muffleWarning")
    }
  )
  expect_quotes(msg, "Failed to start the LM Studio server. Exit code: 3.")
  expect_quotes(msg, "The CLI said: bad")
  expect_identical(warnings, 0L)
})

test_that("none of the three warnings is silenced by the quiet option", {
  # GP6 is traded here. All three warnings go through cli_warn(), not through
  # the helpers in R/utils-msg.R that read the option.
  withr::local_options(rlmstudio.quiet = TRUE)
  start_success()
  fake_clock()
  local_mocked_bindings(
    lms_server_ready = ready_stub(true_on = Inf)$fn,
    lms_server_status = function(...) list(running = TRUE)
  )

  expect_warning(lms_server_start(port = 8080, wait = 1), "did not answer")
  expect_warning(lms_server_start(), "Could not tell which host")

  local_mocked_bindings(
    lms_server_ready = function(...) cli::cli_abort("probe broke")
  )
  expect_warning(lms_server_start(port = 8080), "Could not ask")
})

# A processx::run stub that counts its calls and then stops. The checks below
# must all fire before the server starts, so each test asserts a count of zero
# after its loop. A fail() inside the stub would not do this, because
# expect_error() accepts that failure as the expected error.
forbid_cli <- function(env = parent.frame()) {
  calls <- 0L
  local_mocked_bindings(
    run = function(command, args, error_on_status) {
      calls <<- calls + 1L
      stop("processx::run() was called")
    },
    .package = "processx",
    .env = env
  )
  function() calls
}

test_that("a host the readiness request cannot be built from aborts first", {
  cli_calls <- forbid_cli()
  bad_hosts <- list(
    c("http://a:1", "http://b:2"),
    NA_character_,
    "",
    1,
    list("a"),
    character(0),
    "http://local host:1234",
    "localhost:1234"
  )

  for (wait in c(10, 0)) {
    for (host in bad_hosts) {
      err <- expect_error(lms_server_start(host = host, wait = wait))
      # The first line names the argument. The quoted reason below it can
      # still name httr2's own `url`.
      expect_match(
        conditionMessage(err),
        "`host`",
        fixed = TRUE,
        info = paste(deparse(host), "wait", wait)
      )
      expect_false(any(grepl("^rlmstudio", class(err))))
    }
  }
  expect_identical(cli_calls(), 0L)
})

test_that("the host abort quotes the reason the request build gave", {
  cli_calls <- forbid_cli()
  local_mocked_bindings(
    server_ready_request = function(...) stop("reason from the build")
  )

  err <- expect_error(lms_server_start(host = "http://localhost:1234"))
  expect_match(conditionMessage(err), "`host`", fixed = TRUE)
  expect_match(conditionMessage(err), "reason from the build", fixed = TRUE)
  expect_identical(cli_calls(), 0L)
})

test_that("a NULL host and a usable host pass the pre-start check", {
  start_success()
  fake_clock()
  local_mocked_bindings(lms_server_ready = ready_stub(true_on = 1)$fn)

  for (wait in c(10, 0)) {
    suppressMessages({
      expect_equal(lms_server_start(port = 8080, wait = wait), 0)
      expect_equal(
        lms_server_start(host = "http://localhost:1234", wait = wait),
        0
      )
    })
  }
})

test_that("a bad token aborts before the CLI runs, with host left NULL", {
  cli_calls <- forbid_cli()
  bad_tokens <- list(c("a", "b"), NA_character_, 1)

  for (wait in c(10, 0)) {
    for (token in bad_tokens) {
      expect_error(
        lms_server_start(token = token, wait = wait),
        "`token` must be one character string",
        fixed = TRUE
      )
    }
  }
  expect_identical(cli_calls(), 0L)
})

# Run expr and return its value with every warning it raised, muffled.
collect_warnings <- function(expr) {
  warnings <- list()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = warnings)
}

test_that("an abort from the probe during the wait becomes one warning", {
  start_success()
  fake_clock()
  local_mocked_bindings(
    lms_server_ready = function(...) cli::cli_abort("probe broke")
  )

  out <- suppressMessages(
    collect_warnings(lms_server_start(host = "http://127.0.0.1:9999"))
  )
  expect_identical(out$value, 0)
  expect_length(out$warnings, 1L)
  message <- conditionMessage(out$warnings[[1]])
  expect_match(message, "could not ask", ignore.case = TRUE)
  expect_match(message, "127.0.0.1:9999", fixed = TRUE)
  # The abort's own message is quoted.
  expect_match(message, "probe broke", fixed = TRUE)
})

test_that("a warning raised by the probe before it aborts is not doubled", {
  start_success()
  fake_clock()
  local_mocked_bindings(
    lms_server_ready = function(...) {
      cli::cli_warn("probe warned")
      cli::cli_abort("probe broke")
    }
  )

  out <- suppressMessages(
    collect_warnings(lms_server_start(host = "http://127.0.0.1:9999"))
  )
  expect_identical(out$value, 0)
  expect_length(out$warnings, 1L)
  expect_match(conditionMessage(out$warnings[[1]]), "could not ask",
    ignore.case = TRUE
  )
})

test_that("none of the three wait warnings carries the token", {
  secret <- "secret-token-xyz"
  start_success()
  fake_clock()

  # The wait runs out.
  local_mocked_bindings(lms_server_ready = ready_stub(true_on = Inf)$fn)
  out <- suppressMessages(collect_warnings(
    lms_server_start(port = 8080, wait = 1, token = secret)
  ))
  expect_length(out$warnings, 1L)
  expect_match(conditionMessage(out$warnings[[1]]), "did not answer in time")
  expect_no_match(conditionMessage(out$warnings[[1]]), secret, fixed = TRUE)

  # No host was found.
  local_mocked_bindings(lms_server_status = function(...) list(running = TRUE))
  out <- suppressMessages(collect_warnings(lms_server_start(token = secret)))
  expect_length(out$warnings, 1L)
  expect_match(
    conditionMessage(out$warnings[[1]]),
    "Could not tell which host to ask"
  )
  expect_no_match(conditionMessage(out$warnings[[1]]), secret, fixed = TRUE)

  # The probe aborted.
  local_mocked_bindings(
    lms_server_ready = function(...) cli::cli_abort("probe broke")
  )
  out <- suppressMessages(collect_warnings(
    lms_server_start(port = 8080, token = secret)
  ))
  expect_length(out$warnings, 1L)
  expect_match(conditionMessage(out$warnings[[1]]), "could not ask",
    ignore.case = TRUE
  )
  expect_no_match(conditionMessage(out$warnings[[1]]), secret, fixed = TRUE)
})
