# A call that asks for a result and gets none says so with a classed
# warning that the `rlmstudio.quiet` option does not hide (D-043).

# lms_load(echo_load_config = TRUE) on a loaded model -------------------------

# A model-list reply that holds `a-model`, loaded or not.
echo_list_reply <- function(loaded) {
  instances <- if (loaded) '[{"id": "a-model"}]' else "[]"
  mock_response(
    200L,
    sprintf(
      '{"models": [{"type": "llm", "key": "a-model", "loaded_instances": %s}]}',
      instances
    )
  )
}

# Call lms_load() with `force = FALSE` against `replies`, and return its
# visible value, its warnings, and the requests it sent.
run_echo_load <- function(replies, echo) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(replies)
  res <- collect_warnings(
    suppressMessages(withVisible(lms_load("a-model", echo_load_config = echo)))
  )
  list(
    value = res$value,
    warnings = res$warnings,
    requests = recorder$requests
  )
}

test_that("echo_load_config = TRUE on a loaded model warns past quiet", {
  for (quiet in c(TRUE, FALSE)) {
    test_that(paste("rlmstudio.quiet =", quiet), {
      withr::local_options(rlmstudio.quiet = quiet)
      res <- run_echo_load(list(echo_list_reply(loaded = TRUE)), echo = TRUE)
      expect_identical(res$value$value, "a-model")
      expect_false(res$value$visible)
      expect_identical(length(res$requests), 1L)
      expect_identical(
        request_target(res$requests[[1]])$path,
        "/api/v1/models"
      )
      expect_identical(
        length(warnings_of_class(res$warnings, "rlmstudio_no_load_config")),
        1L
      )
    })
  }
})

test_that("echo_load_config = FALSE on a loaded model gives no echo warning", {
  withr::local_options(rlmstudio.quiet = FALSE)
  res <- run_echo_load(list(echo_list_reply(loaded = TRUE)), echo = FALSE)
  expect_identical(res$value$value, "a-model")
  expect_identical(length(res$requests), 1L)
  expect_length(warnings_of_class(res$warnings, "rlmstudio_no_load_config"), 0L)
})

test_that("echo_load_config = TRUE on a model that is not loaded returns the config", {
  withr::local_options(rlmstudio.quiet = FALSE)
  load_reply <- mock_response(
    200L,
    '{"status": "loaded", "load_config": {"context_length": 4096}}'
  )
  res <- run_echo_load(
    list(echo_list_reply(loaded = FALSE), load_reply),
    echo = TRUE
  )
  expect_identical(res$value$value, list(context_length = 4096L))
  expect_identical(length(res$requests), 2L)
  expect_identical(
    request_target(res$requests[[2]])$path,
    "/api/v1/models/load"
  )
  expect_length(warnings_of_class(res$warnings, "rlmstudio_no_load_config"), 0L)
})
