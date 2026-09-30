# On `api_type = "native"`, `lms_chat_batch()` treats `logprobs = TRUE` as
# off. It returns what `logprobs = FALSE` returns, and it warns once for the
# batch, after the server probe, whatever `quiet` says.

native_logprobs_text <-
  "The 'native' API type does not support logprobs. Ignoring argument."

# Replies to `n` inputs, each with its own text and reply id. `fail` names
# the positions that answer with status 500 instead.
native_batch_replies <- function(n, fail = integer()) {
  lapply(seq_len(n), function(k) {
    if (k %in% fail) {
      return(mock_response(500L, '{"error": {"message": "boom"}}'))
    }
    mock_response(
      200L,
      native_reply(sprintf("reply %d", k), response_id = quoted(sprintf("resp_%d", k)))
    )
  })
}

# Run a native batch of `n` inputs with `dots` against `replies`, and return
# its value with every warning it gave.
run_native_batch <- function(
  dots,
  format,
  n = 2L,
  replies = native_batch_replies(n),
  quiet = TRUE
) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(replies)
  args <- c(
    list("a-model", sprintf("input %d", seq_len(n)), format = format),
    list(quiet = quiet),
    dots
  )
  collect_warnings(do.call(lms_chat_batch, args))
}

warning_texts <- function(warnings) {
  vapply(warnings, function(w) cli::ansi_strip(conditionMessage(w)), character(1))
}

formats <- c("vector", "list", "data.frame")

# The same batch with the flag on and off, under exact and shortened names.
flag_settings <- list(
  exact = list(
    on = list(api_type = "native", logprobs = TRUE),
    off = list(api_type = "native", logprobs = FALSE)
  ),
  shortened = list(
    on = list(api = "native", log = TRUE),
    off = list(api = "native", log = FALSE)
  )
)

test_that("a native batch with logprobs returns what it returns without", {
  for (setting in names(flag_settings)) {
    for (format in formats) {
      info <- paste(setting, format)
      on <- run_native_batch(flag_settings[[setting]]$on, format)
      off <- run_native_batch(flag_settings[[setting]]$off, format)
      # The whole value, attributes included.
      expect_identical(on$value, off$value, info = info)
    }
  }
})

test_that("a native batch with logprobs has the logprobs = FALSE shape", {
  dots <- flag_settings$exact$on
  vec <- run_native_batch(dots, "vector")$value
  expect_identical(vec, c("reply 1", "reply 2"))

  lst <- run_native_batch(dots, "list")$value
  expect_identical(
    lst,
    list(
      structure("reply 1", response_id = "resp_1"),
      structure("reply 2", response_id = "resp_2")
    )
  )

  df <- run_native_batch(dots, "data.frame")$value
  expect_s3_class(df, "data.frame")
  expect_false("logprobs" %in% names(df))
  expect_identical(df$output, c("reply 1", "reply 2"))
  expect_identical(df$response_id, c("resp_1", "resp_2"))
})

# `quiet` from the argument and from the option.
quiet_settings <- list(
  "quiet = TRUE" = list(quiet = TRUE, option = FALSE),
  "quiet = FALSE" = list(quiet = FALSE, option = FALSE),
  "quiet = NULL, option TRUE" = list(quiet = NULL, option = TRUE)
)

# Batches of one input, three inputs, and three inputs where the second fails.
batch_shapes <- list(
  "one input" = list(n = 1L, fail = integer()),
  "three inputs" = list(n = 3L, fail = integer()),
  "three inputs, one fails" = list(n = 3L, fail = 2L)
)

test_that("a native batch with logprobs warns once, past quiet", {
  expect_gt(length(quiet_settings) * length(batch_shapes), 0)
  for (q in names(quiet_settings)) {
    for (shape in names(batch_shapes)) {
      for (format in formats) {
        info <- paste(q, shape, format, sep = ", ")
        withr::local_options(rlmstudio.quiet = quiet_settings[[q]]$option)
        b <- batch_shapes[[shape]]
        res <- run_native_batch(
          flag_settings$exact$on,
          format,
          n = b$n,
          replies = native_batch_replies(b$n, b$fail),
          quiet = quiet_settings[[q]]$quiet
        )
        shown <- warning_texts(res$warnings)
        expect_identical(
          sum(shown == native_logprobs_text),
          1L,
          info = info
        )
        expect_false(any(grepl("Returning list", shown, fixed = TRUE)), info = info)
        if (length(b$fail) == 0L) {
          expect_identical(length(shown), 1L, info = info)
        } else {
          # The notice and the failed-inputs warning, which names position 2.
          expect_identical(length(shown), 2L, info = info)
          failure <- shown[shown != native_logprobs_text]
          expect_match(failure, "1 input failed, at position 2.", fixed = TRUE, info = info)
        }
      }
    }
  }
})

test_that("a native batch with logprobs and no server gives no notice", {
  probe <- local_counting_probe()
  res <- collect_warnings(tryCatch(
    lms_chat_batch("a-model", c("a", "b"), api_type = "native", logprobs = TRUE),
    rlmstudio_no_server = identity
  ))
  expect_s3_class(res$value, "rlmstudio_no_server")
  expect_identical(probe$calls, 1L)
  expect_identical(res$warnings, list())
})

# The routes that have logprobs keep the logprobs results.
logprobs_route_replies <- list(
  openresponses = function(k) {
    output_body(responses_message(output_text(
      quoted(sprintf("reply %d", k)),
      json_array(logprob_step("r"))
    )))
  },
  openai = function(k) completion_body(quoted(sprintf("reply %d", k)))
)

run_route_batch <- function(route, format) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(lapply(1:2, function(k) {
    mock_response(200L, logprobs_route_replies[[route]](k))
  }))
  collect_warnings(lms_chat_batch(
    "a-model",
    c("input 1", "input 2"),
    format = format,
    quiet = TRUE,
    api_type = route,
    logprobs = TRUE
  ))
}

test_that("the openresponses and openai routes keep the logprobs results", {
  for (route in names(logprobs_route_replies)) {
    lst <- run_route_batch(route, "list")
    expect_identical(lst$warnings, list(), info = route)
    expect_type(lst$value, "list")
    for (x in lst$value) {
      expect_s3_class(x, "lms_chat_result")
    }

    vec <- run_route_batch(route, "vector")
    expect_identical(vec$value, lst$value, info = route)
    shown <- warning_texts(vec$warnings)
    expect_identical(length(shown), 1L, info = route)
    expect_match(
      shown,
      "cannot store logprobs dataframes. Returning list.",
      fixed = TRUE,
      info = route
    )

    df <- run_route_batch(route, "data.frame")$value
    expect_true("logprobs" %in% names(df), info = route)
    expect_type(df$logprobs, "list")
    expect_identical(df$output, c("reply 1", "reply 2"), info = route)
  }
})
