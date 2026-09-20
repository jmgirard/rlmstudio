test_that("rlm_check_id accepts one usable name", {
  expect_invisible(rlm_check_id("qwen3-4b", "model"))
  expect_identical(rlm_check_id("qwen3-4b", "model"), "qwen3-4b")
  # A name with braces must not reach cli as a format string.
  expect_identical(rlm_check_id("model{x}", "model"), "model{x}")
})

test_that("rlm_check_id names the argument and the rule for every fault", {
  expect_error(rlm_check_id(NULL, "model"), "You gave NULL")
  expect_error(rlm_check_id(1, "model"), "You gave a numeric value")
  expect_error(rlm_check_id(TRUE, "model"), "You gave a logical value")
  expect_error(rlm_check_id(list("a"), "model"), "You gave a list value")
  expect_error(rlm_check_id(factor("a"), "model"), "You gave a factor value")
  expect_error(
    rlm_check_id(c("a", "b"), "model"),
    "You gave 2 values rather than one"
  )
  expect_error(
    rlm_check_id(character(0), "model"),
    "You gave 0 values rather than one"
  )
  expect_error(rlm_check_id(NA_character_, "model"), "You gave NA")
  expect_error(rlm_check_id("", "model"), "You gave an empty string")
  expect_error(rlm_check_id("  ", "model"), "whitespace only")
})

test_that("rlm_check_id reports the argument name it was given", {
  expect_error(rlm_check_id("", "job_id"), "job_id")
  expect_error(rlm_check_id("", "model"), "model")
})

test_that("rlm_check_text takes a non-empty character vector with no NA", {
  expect_identical(rlm_check_text(c("a", "b"), "input"), c("a", "b"))
  expect_error(rlm_check_text(1:3, "input"), "non-empty character vector")
  expect_error(
    rlm_check_text(character(0), "input"),
    "non-empty character vector"
  )
  expect_error(rlm_check_text(list("a"), "input"), "non-empty character vector")
})

test_that("rlm_check_text rejects an NA wherever it sits", {
  expect_error(rlm_check_text(NA_character_, "input"), "1 NA value\\.")
  expect_error(rlm_check_text(c(NA, "b", "c"), "input"), "1 NA value\\.")
  expect_error(rlm_check_text(c("a", "b", NA), "input"), "1 NA value\\.")
  expect_error(rlm_check_text(c("a", NA, "c"), "input"), "1 NA value\\.")
  expect_error(rlm_check_text(c(NA_character_, NA_character_), "input"), "2 NA values\\.")
  expect_error(rlm_check_text(c("a", NA), "inputs"), "inputs")
})

test_that("rlm_check_no_na lets every non-character shape through", {
  msgs <- list(list(role = "user", content = "hi"))
  expect_identical(rlm_check_no_na(msgs, "input"), msgs)
  expect_identical(rlm_check_no_na(1:3, "input"), 1:3)
  expect_identical(rlm_check_no_na(NULL, "input"), NULL)
  # A list holding NA is not a character vector, so it passes.
  expect_identical(rlm_check_no_na(list(NA), "input"), list(NA))
})

test_that("rlm_check_no_na rejects an NA inside a character vector", {
  expect_error(rlm_check_no_na(NA_character_, "input"), "no missing values")
  expect_error(rlm_check_no_na(c("a", NA), "input"), "1 NA value\\.")
  expect_identical(rlm_check_no_na(character(0), "input"), character(0))
})
