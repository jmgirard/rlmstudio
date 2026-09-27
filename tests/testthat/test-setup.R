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
    paste0("Could not parse the LM Studio CLI version. Output was: ", brace_probe_val),
    fixed = TRUE
  )
  expect_no_match(shown$stdout, "EVALUATED", fixed = TRUE)
})

test_that("install_lmstudio shows installer output with braces and does not run it", {
  # The stub stands in for the installer, so no install runs for real.
  calls <- 0L
  withr::local_envvar(RLMSTUDIO_ALLOW_INSTALL = "TRUE")
  local_mocked_bindings(has_lms = function() FALSE)
  # In an interactive session, the install asks for consent first.
  local_mocked_bindings(askYesNo = function(...) TRUE, .package = "utils")
  local_mocked_bindings(Sys.which = function(...) "/usr/bin/curl", .package = "base")
  local_mocked_bindings(
    run = function(...) {
      calls <<- calls + 1L
      list(status = 1, stdout = brace_probe, stderr = "")
    },
    .package = "processx"
  )
  # The outer handler's abort keeps only the first line of the inner abort, so
  # the installer output shows in the inner abort alone. This wrapper records
  # the message of each abort that cli raises.
  real_abort <- cli::cli_abort
  aborts <- character(0)
  local_mocked_bindings(
    cli_abort = function(message, ..., .envir = parent.frame()) {
      tryCatch(
        real_abort(message, ..., .envir = .envir),
        error = function(e) {
          aborts <<- c(aborts, conditionMessage(e))
          stop(e)
        }
      )
    },
    .package = "cli"
  )
  shown <- capture_shown(install_lmstudio(method = "headless"))
  expect_identical(calls, 1L)
  expect_length(aborts, 2L)
  expect_match(aborts[[1]], "Exit code: 1", fixed = TRUE)
  expect_match(aborts[[1]], paste("CLI output:", brace_probe_val), fixed = TRUE)
  expect_identical(conditionMessage(shown$error), aborts[[2]])
  expect_match(aborts[[2]], "Error message:", fixed = TRUE)
  expect_no_match(shown$stdout, "EVALUATED", fixed = TRUE)
})
