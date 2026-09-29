fake_lms_name <- function() {
  if (.Platform$OS.type == "windows") "lms.bat" else "lms"
}

test_that("has_lms is TRUE when RLMSTUDIO_LMS_PATH names an existing file", {
  fake <- withr::local_tempfile(fileext = "")
  writeLines("#!/bin/sh", fake)
  withr::local_envvar(RLMSTUDIO_LMS_PATH = fake)
  expect_true(has_lms())
})

test_that("has_lms is TRUE when lms sits on the PATH", {
  dir <- withr::local_tempdir()
  fake <- file.path(dir, fake_lms_name())
  writeLines("#!/bin/sh", fake)
  Sys.chmod(fake, "755")
  withr::local_envvar(RLMSTUDIO_LMS_PATH = "")
  withr::local_path(dir, action = "prefix")
  expect_true(has_lms())
})

test_that("has_lms is FALSE when no lookup finds the CLI", {
  empty <- withr::local_tempdir()
  withr::local_envvar(RLMSTUDIO_LMS_PATH = "")
  withr::local_path(empty, action = "replace")
  local_mocked_bindings(file.exists = function(...) FALSE, .package = "base")
  expect_false(has_lms())
})

test_that("check_lms_version is FALSE when the CLI is missing", {
  empty <- withr::local_tempdir()
  withr::local_envvar(RLMSTUDIO_LMS_PATH = "")
  withr::local_path(empty, action = "replace")
  local_mocked_bindings(file.exists = function(...) FALSE, .package = "base")
  expect_false(suppressMessages(check_lms_version()))
})

test_that("check_lms_version shows unparsed output with braces and does not run it", {
  local_mocked_bindings(lms_path = function() "lms")
  local_mocked_bindings(
    run = function(...) list(status = 0, stdout = brace_probe, stderr = ""),
    .package = "processx"
  )
  shown <- capture_shown(result <- check_lms_version())
  expect_null(shown$error)
  expect_false(result)
  expect_match(
    shown$messages,
    paste0(
      "Could not parse the LM Studio CLI version. Output was: ",
      brace_probe_val
    ),
    fixed = TRUE
  )
  expect_no_match(shown$stdout, "EVALUATED", fixed = TRUE)
})

# Run a headless install in which `run` stands in for the installer, so no
# install runs for real. Returns what the call showed, with the error message
# squished, since cli wraps long bullets.
headless_install <- function(run, sysname = "Darwin", curl = "/usr/bin/curl") {
  withr::local_envvar(RLMSTUDIO_ALLOW_INSTALL = "TRUE")
  local_mocked_bindings(has_lms = function() FALSE)
  # In an interactive session, the install asks for consent first.
  local_mocked_bindings(askYesNo = function(...) TRUE, .package = "utils")
  local_mocked_bindings(
    Sys.which = function(...) curl,
    Sys.info = function(...) c(sysname = sysname),
    .package = "base"
  )
  local_mocked_bindings(run = run, .package = "processx")
  shown <- capture_shown(install_lmstudio(method = "headless"))
  expect_s3_class(shown$error, "error")
  shown$message <- gsub("\\s+", " ", trimws(conditionMessage(shown$error)))
  shown
}

count_fixed <- function(pattern, x) {
  lengths(regmatches(x, gregexpr(pattern, x, fixed = TRUE)))
}

test_that("a failed installer run quotes its output", {
  calls <- 0L
  shown <- headless_install(function(...) {
    calls <<- calls + 1L
    list(status = 1L, stdout = brace_probe, stderr = NULL)
  })
  expect_identical(calls, 1L)
  expect_match(
    shown$message,
    "Headless installation failed. Exit code: 1.",
    fixed = TRUE
  )
  expect_match(
    shown$message,
    paste("The installer said:", brace_probe),
    fixed = TRUE
  )
  expect_identical(
    count_fixed("Headless installation failed", shown$message),
    1L
  )
  expect_no_match(shown$message, "Error message:", fixed = TRUE)
  expect_no_match(shown$stdout, "EVALUATED", fixed = TRUE)
})

test_that("a long installer log is cleaned and keeps its end", {
  # The escape codes near the end sit in the part that the cut keeps: a
  # color code, the cursor save code ESC 7, and a window title.
  stdout <- paste0(
    "\033[32mDownloading\033[0m\n",
    strrep("8", 1500),
    "\ncurl: (22) The requested URL returned error: \033[31m404\033[0m\0337",
    "\033]0;lmstudio.ai\a ",
    rawToChar(as.raw(0xff))
  )
  # The cleaning written out by hand: no escape codes, one space per line
  # break, and the byte 0xff as "<ff>".
  cleaned <- paste0(
    "Downloading ",
    strrep("8", 1500),
    " curl: (22) The requested URL returned error: 404 <ff>"
  )
  expected <- paste0("…", substring(cleaned, nchar(cleaned) - 999L))
  shown <- headless_install(function(...) {
    list(status = 22L, stdout = stdout, stderr = NULL)
  })
  expect_match(shown$message, "Exit code: 22.", fixed = TRUE)
  expect_match(
    shown$message,
    paste("The installer said:", expected),
    fixed = TRUE
  )
  expect_no_match(shown$message, "Downloading", fixed = TRUE)
  expect_no_match(shown$message, "\033", fixed = TRUE)
  expect_no_match(shown$message, "lmstudio.ai", fixed = TRUE)
})

# Every other error inside the install step keeps the wrapped message.
expect_wrapped_install_error <- function(shown, text) {
  expect_match(shown$message, "Headless installation failed.", fixed = TRUE)
  expect_match(shown$message, "Error message:", fixed = TRUE)
  expect_match(shown$message, text, fixed = TRUE)
  expect_no_match(shown$message, "Exit code", fixed = TRUE)
}

test_that("a missing curl keeps the wrapped install message", {
  calls <- 0L
  shown <- headless_install(
    function(...) {
      calls <<- calls + 1L
      list(status = 0L, stdout = "", stderr = NULL)
    },
    curl = ""
  )
  expect_identical(calls, 0L)
  expect_wrapped_install_error(shown, "is required but was not found")
})

test_that("an unsupported system keeps the wrapped install message", {
  shown <- headless_install(
    function(...) list(status = 0L, stdout = "", stderr = NULL),
    sysname = "Plan9"
  )
  expect_wrapped_install_error(shown, "not supported for this operating system")
  expect_match(shown$message, "Plan9", fixed = TRUE)
})

test_that("a shell that fails to start keeps the wrapped install message", {
  shown <- headless_install(function(...) {
    stop("cannot start processx process 'bash'")
  })
  expect_wrapped_install_error(shown, "cannot start processx process")
})
