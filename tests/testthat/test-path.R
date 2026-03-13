test_that("lms_path respects the RLMSTUDIO_LMS_PATH env var", {
  withr::with_envvar(c(RLMSTUDIO_LMS_PATH = "/custom/path/lms"), {
    local_mocked_bindings(file.exists = function(x) TRUE, .package = "base")
    expect_equal(lms_path(), "/custom/path/lms")
  })
})

test_that("lms_path aborts when CLI is completely missing", {
  withr::with_envvar(c(RLMSTUDIO_LMS_PATH = ""), {
    local_mocked_bindings(Sys.which = function(x) "", .package = "base")
    local_mocked_bindings(file.exists = function(x) FALSE, .package = "base")

    expect_error(lms_path(), "was not found on your system")
  })
})
