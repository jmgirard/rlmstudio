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
