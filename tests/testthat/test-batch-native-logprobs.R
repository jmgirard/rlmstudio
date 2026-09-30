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
      native_reply(
        sprintf("reply %d", k),
        response_id = quoted(sprintf("resp_%d", k))
      )
    )
  })
}

# Call `lms_chat_batch()` with `args` against `replies`, and return its value
# with every warning it gave and every request it sent.
drive_native_batch <- function(args, replies) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(replies)
  res <- collect_warnings(do.call(lms_chat_batch, args))
  res$requests <- recorder$requests
  res
}

# Run a native batch of `n` inputs with `dots` against `replies`, and return
# its value with every warning it gave and every request it sent.
run_native_batch <- function(
  dots,
  format,
  n = 2L,
  replies = native_batch_replies(n),
  quiet = TRUE
) {
  args <- c(
    list("a-model", sprintf("input %d", seq_len(n)), format = format),
    list(quiet = quiet),
    dots
  )
  drive_native_batch(args, replies)
}

warning_texts <- function(warnings) {
  vapply(
    warnings,
    function(w) cli::ansi_strip(conditionMessage(w)),
    character(1)
  )
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
        expect_false(
          any(grepl("Returning list", shown, fixed = TRUE)),
          info = info
        )
        if (length(b$fail) == 0L) {
          expect_identical(length(shown), 1L, info = info)
        } else {
          # The notice and the failed-inputs warning, which names position 2.
          expect_identical(length(shown), 2L, info = info)
          failure <- shown[shown != native_logprobs_text]
          expect_match(
            failure,
            "1 input failed, at position 2.",
            fixed = TRUE,
            info = info
          )
        }
      }
    }
  }
})

# Assert that `on` and `off` return the same value and that `on` gave the one
# notice and no other warning.
expect_one_notice_same_value <- function(on, off, info) {
  expect_identical(on$value, off$value, info = info)
  expect_identical(
    warning_texts(on$warnings),
    native_logprobs_text,
    info = info
  )
}

test_that("a shortened log dot beside logprobs stays a body field on native", {
  # R matches the exact `logprobs` first, so `log` goes to the `...` of
  # `lms_chat()` and on to the request body, as it does with the flag off.
  for (value in list(TRUE, FALSE, "x")) {
    for (format in formats) {
      info <- paste(format, "log =", deparse(value))
      on <- run_native_batch(
        list(api_type = "native", logprobs = TRUE, log = value),
        format
      )
      off <- run_native_batch(
        list(api_type = "native", logprobs = FALSE, log = value),
        format
      )
      expect_one_notice_same_value(on, off, info)
      expect_identical(length(on$requests), 2L, info = info)
      for (req in on$requests) {
        body <- jsonlite::fromJSON(req$body$data, simplifyVector = FALSE)
        expect_identical(body[["log"]], value, info = info)
        expect_false("logprobs" %in% names(body), info = info)
      }
    }
  }
})

# The arguments of a batch of two inputs that fill every formal before `...`
# by position, so each element of `dots` is a dot, named or not.
positional_batch <- function(format, dots) {
  c(
    list(
      "a-model",
      c("input 1", "input 2"),
      NULL,
      format,
      "http://localhost:1234",
      TRUE,
      TRUE
    ),
    dots
  )
}

test_that("an unnamed dot after logprobs on native goes where it goes with the flag off", {
  for (format in formats) {
    on <- drive_native_batch(
      positional_batch(
        format,
        list(api_type = "native", logprobs = TRUE, "extra")
      ),
      native_batch_replies(2L)
    )
    off <- drive_native_batch(
      positional_batch(
        format,
        list(api_type = "native", logprobs = FALSE, "extra")
      ),
      native_batch_replies(2L)
    )
    expect_one_notice_same_value(on, off, format)
  }
})

test_that("a logprobs given by position on native is treated as off", {
  # The first two dots, unnamed, are what `lms_chat()` reads as `api_type`
  # and `logprobs`.
  for (format in formats) {
    on <- drive_native_batch(
      positional_batch(format, list("native", TRUE)),
      native_batch_replies(2L)
    )
    off <- drive_native_batch(
      positional_batch(format, list("native", FALSE)),
      native_batch_replies(2L)
    )
    expect_one_notice_same_value(on, off, format)
  }
})

test_that("a native batch with logprobs that stops at a 401 keeps its results", {
  replies <- list(
    native_batch_replies(1L)[[1]],
    mock_response(401L, '{"error": {"message": "refused"}}')
  )
  stop_batch <- function(flag, format) {
    drive_native_batch(
      list(
        "a-model",
        c("input 1", "input 2", "input 3"),
        format = format,
        quiet = TRUE,
        api_type = "native",
        logprobs = flag
      ),
      replies
    )
  }
  caught <- function(flag, format) {
    tryCatch(stop_batch(flag, format), rlmstudio_api_error = identity)
  }
  for (format in formats) {
    on <- caught(TRUE, format)
    off <- caught(FALSE, format)
    expect_true(inherits(on, "rlmstudio_api_error"), info = format)
    expect_identical(on$status, 401L, info = format)
    # The whole value, attributes included.
    expect_identical(
      on$results,
      list(structure("reply 1", response_id = "resp_1"), NULL, NULL),
      info = format
    )
    expect_identical(on$results, off$results, info = format)
  }
})

test_that("a native batch with logprobs and no server gives no notice", {
  probe <- local_counting_probe()
  res <- collect_warnings(tryCatch(
    lms_chat_batch(
      "a-model",
      c("a", "b"),
      api_type = "native",
      logprobs = TRUE
    ),
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
    # `expect_type()` and `expect_s3_class()` take no `info`, so these name
    # the route through `expect_true()`.
    expect_true(is.list(lst$value), info = route)
    for (x in lst$value) {
      expect_true(inherits(x, "lms_chat_result"), info = route)
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
    expect_true(is.list(df$logprobs), info = route)
    expect_identical(df$output, c("reply 1", "reply 2"), info = route)
  }
})
