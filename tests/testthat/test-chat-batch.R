# How lms_chat_batch() treats an input that fails. A live server does not fail
# on demand, so the server is mocked through the shared recorder (D-004).

batch_inputs <- c("first", "second", "third")
failure_classes <- c("rlmstudio_api_error", "rlmstudio_bad_response")

# A chat completions response that succeeds at position `i`: a score for a
# schema batch, text otherwise. Each position gets its own value, so a slot
# cannot pass by holding a neighbor's reply.
openai_ok <- function(i, schema = FALSE) {
  content <- if (schema) sprintf('{"score": %d}', i) else sprintf("reply %d", i)
  mock_response(200L, completion_body(quoted(content)))
}

# An OpenResponses response that succeeds at position `i`. With `logprobs`,
# the reply carries one token and its log probability.
openresponses_ok <- function(i, logprobs = FALSE) {
  lp <- if (logprobs) sprintf("[%s]", logprob_step("r")) else NULL
  mock_response(
    200L,
    output_body(responses_message(output_text(quoted(sprintf("reply %d", i)), lp)))
  )
}

# A response that makes lms_chat() raise `cls`. A parsed schema reply fails as
# text that is not JSON. A reply that is never parsed fails as a response with
# no `choices` field.
fail_response <- function(cls, parsed) {
  switch(
    cls,
    rlmstudio_api_error = mock_response(400L, '{"error": "bad request"}'),
    rlmstudio_bad_response = if (parsed) {
      mock_response(200L, completion_body(quoted("not json")))
    } else {
      mock_response(200L, '{"id": "chatcmpl-1"}')
    }
  )
}

# Run lms_chat_batch() over three inputs. The inputs at `fail_at` fail with
# the matching class in `cls`, and the others succeed with `ok(i)`. Returns
# the result, the warnings, and the number of requests sent.
run_failing_batch <- function(
  fail_at,
  cls,
  format,
  schema = FALSE,
  simplify = TRUE,
  logprobs = FALSE,
  api_type = "openai",
  quiet = TRUE,
  ok = function(i) openai_ok(i, schema)
) {
  parsed <- schema && simplify && !logprobs
  responses <- lapply(seq_along(batch_inputs), ok)
  responses[fail_at] <- lapply(cls, fail_response, parsed = parsed)

  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(responses)
  args <- list(
    "a-model",
    batch_inputs,
    format = format,
    simplify = simplify,
    quiet = quiet,
    api_type = api_type
  )
  if (schema) {
    args$schema <- score_schema
  }
  if (logprobs) {
    args$logprobs <- TRUE
  }
  warnings <- testthat::capture_warnings(
    out <- do.call(lms_chat_batch, args)
  )
  list(out = out, warnings = warnings, requests = length(recorder$requests))
}

# A stored condition has the class it was raised with and no backtrace, which
# would make each failed slot large.
expect_failed_slot <- function(x, cls, info = NULL) {
  expect_s3_class(x, cls)
  expect_null(x$trace, info = info)
  if (cls == "rlmstudio_api_error") {
    expect_identical(x$status, 400L, info = info)
  }
}

test_that("a failed input in any format does not end the batch", {
  for (cls in failure_classes) {
    for (schema in c(FALSE, TRUE)) {
      for (format in c("list", "vector", "data.frame")) {
        for (fail_at in 2:3) {
          info <- paste(cls, format, "schema:", schema, "fail_at:", fail_at)
          res <- run_failing_batch(fail_at, cls, format, schema = schema)
          expect_identical(res$requests, 3L, info = info)

          got <- if (format == "data.frame") res$out$output else res$out
          if (format == "data.frame") {
            expect_identical(res$out$input, batch_inputs, info = info)
          }
          holds_na <- !schema && format != "list"
          if (holds_na) {
            expected <- sprintf("reply %d", 1:3)
            expected[fail_at] <- NA_character_
            expect_identical(got, expected, info = info)
          } else {
            expect_type(got, "list")
            expect_length(got, 3L)
            for (i in setdiff(1:3, fail_at)) {
              expected <- if (schema) list(score = i) else sprintf("reply %d", i)
              expect_identical(got[[i]], expected, info = info)
            }
            expect_failed_slot(got[[fail_at]], cls, info = info)
          }

          # expect_length() takes no `info`, so the loop case would go unnamed.
          expect_identical(length(res$warnings), 1L, info = info)
          expect_match(
            res$warnings,
            sprintf("1 input failed, at position %d\\.", fail_at),
            info = info
          )
          if (holds_na) {
            expect_match(res$warnings, 'format = "list"', fixed = TRUE, info = info)
          } else {
            expect_no_match(res$warnings, 'format = "list"', fixed = TRUE, info = info)
          }
          # A vector batch that returns a list says why in the same warning.
          if (format == "vector" && schema) {
            expect_match(
              res$warnings,
              "cannot store replies parsed from .*schema.*Returning list\\.",
              info = info
            )
          }
        }
      }
    }
  }
})

test_that("a failed input does not end a batch with simplify = FALSE", {
  res <- run_failing_batch(2L, "rlmstudio_api_error", "list", simplify = FALSE)
  expect_identical(res$requests, 3L)
  # The raw response of each input that succeeded.
  expect_identical(res$out[[1]]$choices[[1]]$message$content, "reply 1")
  expect_failed_slot(res$out[[2]], "rlmstudio_api_error")
  expect_identical(res$out[[3]]$choices[[1]]$message$content, "reply 3")
  expect_length(res$warnings, 1L)
  expect_match(res$warnings, "1 input failed, at position 2\\.")
  expect_no_match(res$warnings, 'format = "list"', fixed = TRUE)
})

test_that("a failed input does not end a batch on the default api_type", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(
    openresponses_ok(1L),
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openresponses_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "list", quiet = TRUE),
    "1 input failed, at position 2\\."
  )
  expect_length(recorder$requests, 3L)
  # The route is the one the default api_type takes.
  expect_identical(request_target(recorder$requests[[3]])$path, "/v1/responses")
  expect_identical(out[[1]], "reply 1")
  expect_failed_slot(out[[2]], "rlmstudio_api_error")
  expect_identical(out[[3]], "reply 3")
})

test_that("a failed input leaves NULL logprobs in a data frame", {
  for (cls in failure_classes) {
    res <- run_failing_batch(2L, cls, "data.frame", logprobs = TRUE)
    expect_identical(res$requests, 3L, info = cls)
    expect_named(res$out, c("input", "output", "logprobs"))
    expect_identical(res$out$output, c("reply 1", NA, "reply 3"), info = cls)
    expect_null(res$out$logprobs[[2]])
    expect_length(res$warnings, 1L)
    expect_match(res$warnings, "1 input failed, at position 2\\.", info = cls)
    expect_match(res$warnings, 'format = "list"', fixed = TRUE, info = cls)
  }

  # The openai route leaves every logprobs slot NULL, so this route shows the
  # inputs that succeeded keep theirs.
  res <- run_failing_batch(
    2L,
    "rlmstudio_api_error",
    "data.frame",
    logprobs = TRUE,
    api_type = "openresponses",
    ok = function(i) openresponses_ok(i, logprobs = TRUE)
  )
  expect_identical(res$out$output, c("reply 1", NA, "reply 3"))
  expect_s3_class(res$out$logprobs[[1]], "data.frame")
  expect_null(res$out$logprobs[[2]])
  expect_s3_class(res$out$logprobs[[3]], "data.frame")
})

test_that("a batch in which every input fails keeps its logprobs column", {
  for (cls in failure_classes) {
    res <- run_failing_batch(1:3, rep(cls, 3), "data.frame", logprobs = TRUE)
    expect_identical(res$requests, 3L, info = cls)
    expect_named(res$out, c("input", "output", "logprobs"))
    expect_identical(res$out$output, rep(NA_character_, 3), info = cls)
    expect_identical(res$out$logprobs, list(NULL, NULL, NULL), info = cls)
    expect_length(res$warnings, 1L)
    expect_match(res$warnings, "3 inputs failed, at positions 1, 2, and 3\\.", info = cls)
  }
})

test_that("one warning names every failed input of either class", {
  withr::local_options(rlmstudio.quiet = TRUE)
  res <- run_failing_batch(
    c(1L, 3L),
    c("rlmstudio_api_error", "rlmstudio_bad_response"),
    "list",
    schema = TRUE,
    quiet = TRUE
  )
  expect_identical(res$requests, 3L)
  expect_failed_slot(res$out[[1]], "rlmstudio_api_error")
  expect_identical(res$out[[2]], list(score = 2L))
  expect_failed_slot(res$out[[3]], "rlmstudio_bad_response")
  expect_length(res$warnings, 1L)
  expect_match(res$warnings, "2 inputs failed, at positions 1 and 3\\.")
})

# Run a three-input batch in which the server goes away before input `k`. The
# batch probes the server once before the first input, and each input probes
# again, so input i makes probe i + 1. `responses` answers the inputs before
# `k`. Returns the caught condition and the counts.
run_lost_server_batch <- function(k, responses, format = "list") {
  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes <= k
  })
  recorder <- local_request_sequence(responses)
  cnd <- expect_error(
    lms_chat_batch("a-model", batch_inputs, format = format, quiet = TRUE, api_type = "openai"),
    class = "rlmstudio_no_server"
  )
  list(cnd = cnd, probes = probes, requests = length(recorder$requests))
}

test_that("a lost server aborts the batch with the replies so far", {
  res <- run_lost_server_batch(2L, list(openai_ok(1L)))
  expect_identical(res$probes, 3L)
  expect_identical(res$requests, 1L)
  expect_match(conditionMessage(res$cnd), "server")
  expect_identical(res$cnd$results, list("reply 1", NULL, NULL))

  # The field holds what format = "list" returns, whatever the format.
  res <- run_lost_server_batch(2L, list(openai_ok(1L)), format = "vector")
  expect_identical(res$cnd$results, list("reply 1", NULL, NULL))
})

test_that("a server lost before the first input leaves every result NULL", {
  res <- run_lost_server_batch(1L, list())
  expect_identical(res$probes, 2L)
  expect_identical(res$requests, 0L)
  expect_identical(res$cnd$results, list(NULL, NULL, NULL))
})

test_that("a server down before the batch starts adds no results field", {
  res <- run_lost_server_batch(0L, list())
  expect_identical(res$probes, 1L)
  expect_identical(res$requests, 0L)
  expect_false("results" %in% names(res$cnd))
})

test_that("a lost server keeps a stored failure in its results", {
  res <- run_lost_server_batch(
    3L,
    list(fail_response("rlmstudio_api_error", parsed = FALSE), openai_ok(2L))
  )
  expect_identical(res$requests, 2L)
  expect_length(res$cnd$results, 3L)
  expect_failed_slot(res$cnd$results[[1]], "rlmstudio_api_error")
  expect_identical(res$cnd$results[[2]], "reply 2")
  expect_null(res$cnd$results[[3]])
})

test_that("a reply with null content fails its input as NA in text results", {
  # The server answers input 1 with `"content": null`, which has no answer
  # text and so fails, and fails input 2 with an API error.
  null_reply <- mock_response(200L, completion_body("null"))
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  local_request_sequence(list(
    null_reply,
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openai_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "vector", quiet = TRUE, api_type = "openai"),
    "2 inputs failed, at positions 1 and 2\\."
  )
  expect_identical(out, c(NA, NA, "reply 3"))

  local_request_sequence(list(
    null_reply,
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openai_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "data.frame", quiet = TRUE, api_type = "openai"),
    "2 inputs failed, at positions 1 and 2\\."
  )
  expect_identical(out$output, c(NA, NA, "reply 3"))

  local_request_sequence(list(
    null_reply,
    fail_response("rlmstudio_api_error", parsed = FALSE),
    openai_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch("a-model", batch_inputs, format = "list", quiet = TRUE, api_type = "openai"),
    "2 inputs failed, at positions 1 and 2\\."
  )
  expect_s3_class(out[[1]], "rlmstudio_bad_response")
  expect_null(out[[1]]$content)
})

test_that("a logprobs data frame keeps its column when no reply carried logprobs", {
  # Replies with no logprobs, on the route that returns them as plain text,
  # and one with null text, which fails that input.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    openresponses_ok(1L),
    mock_response(200L, output_body(responses_message(output_text("null")))),
    openresponses_ok(3L)
  ))
  expect_warning(
    out <- lms_chat_batch(
      "a-model",
      batch_inputs,
      format = "data.frame",
      logprobs = TRUE,
      quiet = TRUE,
      api_type = "openresponses"
    ),
    "1 input failed, at position 2\\."
  )
  expect_named(out, c("input", "output", "logprobs"))
  expect_identical(out$output, c("reply 1", NA, "reply 3"))
  expect_identical(out$logprobs, list(NULL, NULL, NULL))
})

test_that("named inputs keep their names in the result and in results", {
  named_inputs <- c(a = "first", b = "second", c = "third")
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)

  for (format in c("list", "vector")) {
    local_request_sequence(list(
      openai_ok(1L),
      fail_response("rlmstudio_api_error", parsed = FALSE),
      openai_ok(3L)
    ))
    expect_warning(
      out <- lms_chat_batch(
        "a-model",
        named_inputs,
        format = format,
        quiet = TRUE,
        api_type = "openai"
      ),
      "1 input failed"
    )
    expect_named(out, c("a", "b", "c"))
  }
  expect_identical(out, c(a = "reply 1", b = NA, c = "reply 3"))

  probes <- 0L
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes <= 2L
  })
  local_request_sequence(list(openai_ok(1L)))
  cnd <- expect_error(
    lms_chat_batch("a-model", named_inputs, quiet = TRUE, api_type = "openai"),
    class = "rlmstudio_no_server"
  )
  expect_identical(cnd$results, list(a = "reply 1", b = NULL, c = NULL))
})

test_that("a connection that fails after the check passes adds no results field", {
  # The check passes, but nothing listens on port 1, so the request itself
  # fails to connect, as it would for a server that stops mid-request.
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  cnd <- expect_error(
    lms_chat_batch(
      "a-model",
      batch_inputs,
      host = "http://127.0.0.1:1",
      quiet = TRUE,
      api_type = "openai"
    ),
    class = "httr2_failure"
  )
  expect_false("results" %in% names(cnd))
})

# Stub lms_chat() so that its second call raises `cnd`. The stub counts its
# calls, because a stub that failed the test by raising would itself be
# caught by the tryCatch() below (LESSONS, M015).
test_that("an error of any other class still aborts the batch unchanged", {
  raised <- list(
    plain = simpleError("a plain R error"),
    other_class = structure(
      class = c("some_other_error", "rlang_error", "error", "condition"),
      list(message = "an error from elsewhere", trace = NULL, parent = NULL)
    )
  )
  for (name in names(raised)) {
    calls <- 0L
    testthat::local_mocked_bindings(
      is_server_running = function(...) TRUE,
      lms_chat = function(...) {
        calls <<- calls + 1L
        if (calls == 2L) {
          stop(raised[[name]])
        }
        "a reply"
      }
    )
    # tryCatch() rather than expect_error(), which adds a backtrace to the
    # condition it catches and so would never return the one raised.
    caught <- tryCatch(
      lms_chat_batch("a-model", batch_inputs, format = "list", quiet = TRUE),
      error = identity
    )
    expect_identical(caught, raised[[name]], info = name)
    expect_identical(calls, 2L, info = name)
  }
})

# Run a two-input batch whose first reply reads as "reply 1" and whose second
# is `body`. Returns the result and the warnings.
run_unreadable_batch <- function(ok, body, format, api_type, logprobs = FALSE) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(ok, mock_response(200L, body)))
  args <- list(
    "a-model",
    c("first", "second"),
    format = format,
    quiet = TRUE,
    api_type = api_type
  )
  if (logprobs) {
    args$logprobs <- TRUE
  }
  warnings <- testthat::capture_warnings(out <- do.call(lms_chat_batch, args))
  list(out = out, warnings = warnings)
}

test_that("a reply with no readable text fails only its own input on every route", {
  routes <- list(
    native = list(
      ok = mock_response(200L, output_body(native_message(quoted("reply 1")))),
      bodies = native_unreadable()
    ),
    openresponses = list(
      ok = openresponses_ok(1L),
      bodies = responses_unreadable()
    ),
    openai = list(
      ok = openai_ok(1L),
      bodies = lapply(openai_unreadable(), `[[`, "body")
    )
  )
  for (api_type in names(routes)) {
    route <- routes[[api_type]]
    for (label in names(route$bodies)) {
      for (format in c("list", "vector", "data.frame")) {
        info <- paste(api_type, format, label)
        res <- run_unreadable_batch(route$ok, route$bodies[[label]], format, api_type)
        expect_identical(length(res$warnings), 1L, info = info)
        expect_match(res$warnings[[1]], "1 input failed, at position 2\\.", info = info)
        if (format == "list") {
          expect_identical(length(res$out), 2L, info = info)
          expect_identical(res$out[[1]], "reply 1", info = info)
          expect_failed_slot(res$out[[2]], "rlmstudio_bad_response", info = info)
        } else if (format == "vector") {
          expect_identical(res$out, c("reply 1", NA), info = info)
        } else {
          expect_identical(res$out$output, c("reply 1", NA), info = info)
        }
      }
    }
  }
})

test_that("an OpenAI reply with null content fails its input in a logprobs data frame", {
  res <- run_unreadable_batch(
    openai_ok(1L),
    completion_body("null"),
    "data.frame",
    "openai",
    logprobs = TRUE
  )
  expect_length(res$warnings, 1L)
  expect_match(res$warnings[[1]], "1 input failed, at position 2\\.")
  expect_identical(res$out$output, c("reply 1", NA))
  expect_identical(res$out$logprobs, list(NULL, NULL))
})

test_that("a reply that breaks a logprobs rule fails only its own input", {
  bad <- mock_response(
    200L,
    output_body(responses_message(output_text(quoted("reply 2"), "[5]")))
  )
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    openresponses_ok(1L, logprobs = TRUE),
    bad,
    openresponses_ok(3L, logprobs = TRUE)
  ))
  warnings <- testthat::capture_warnings(
    out <- lms_chat_batch(
      "a-model",
      batch_inputs,
      format = "list",
      quiet = TRUE,
      api_type = "openresponses",
      logprobs = TRUE
    )
  )
  expect_length(warnings, 1L)
  expect_match(warnings[[1]], "1 input failed, at position 2\\.")
  expect_length(out, 3L)
  for (i in c(1L, 3L)) {
    expect_s3_class(out[[i]], "lms_chat_result")
    expect_identical(out[[i]]$text, sprintf("reply %d", i), info = i)
    expect_identical(out[[i]]$logprobs$step_token, "r", info = i)
  }
  expect_failed_slot(out[[2]], "rlmstudio_bad_response")
  expect_match(
    conditionMessage(out[[2]]),
    "A step in the `logprobs` of an `output_text` part is not a JSON object.",
    fixed = TRUE
  )
})

# The reply id and the stats columns of a native data-frame batch.

stats_columns <- c(
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens",
  "tokens_per_second",
  "time_to_first_token_seconds",
  "model_load_time_seconds"
)
reply_columns <- c("response_id", stats_columns)

# Run a data-frame batch whose input i is answered by `responses[[i]]`, a
# response or a body string. Returns the result and the warnings. With
# `capture = FALSE`, warnings reach the caller and the result holds `out` only.
run_stats_batch <- function(
  responses,
  inputs = paste("input", seq_along(responses)),
  api_type = "native",
  logprobs = FALSE,
  capture = TRUE,
  ...
) {
  responses <- lapply(responses, function(r) {
    if (is.character(r)) mock_response(200L, r) else r
  })
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  args <- list(
    "a-model",
    inputs,
    format = "data.frame",
    quiet = TRUE,
    api_type = api_type,
    ...
  )
  if (logprobs) {
    args$logprobs <- TRUE
  }
  if (!capture) {
    return(list(out = do.call(lms_chat_batch, args)))
  }
  warnings <- testthat::capture_warnings(out <- do.call(lms_chat_batch, args))
  list(out = out, warnings = warnings)
}

# The seven reply columns of a native data frame are character and double
# whatever the rows hold.
expect_reply_column_types <- function(df, info = NULL) {
  expect_type(df$response_id, "character")
  for (col in stats_columns) {
    expect_identical(typeof(df[[col]]), "double", info = paste(info, col))
  }
}

test_that("a native data-frame batch adds the reply id and stats of each reply", {
  replies <- list(
    native_reply(
      "reply 1",
      native_stats("21", "3", "0", "284.5", "0.237", "1.5"),
      quoted("resp_a")
    ),
    native_reply(
      "reply 2",
      native_stats("42", "7", "2", "150", "0.5", "2.75"),
      quoted("resp_b")
    )
  )
  expected <- list(
    response_id = c("resp_a", "resp_b"),
    input_tokens = c(21, 42),
    total_output_tokens = c(3, 7),
    reasoning_output_tokens = c(0, 2),
    tokens_per_second = c(284.5, 150),
    time_to_first_token_seconds = c(0.237, 0.5),
    model_load_time_seconds = c(1.5, 2.75)
  )

  for (logprobs in c(FALSE, TRUE)) {
    info <- paste("logprobs:", logprobs)
    res <- run_stats_batch(replies, logprobs = logprobs)
    leading <- if (logprobs) c("input", "output", "logprobs") else c("input", "output")
    expect_identical(names(res$out), c(leading, reply_columns), info = info)
    expect_identical(res$out$output, c("reply 1", "reply 2"), info = info)
    for (col in reply_columns) {
      expect_identical(res$out[[col]], expected[[col]], info = paste(info, col))
    }
    if (logprobs) {
      # The native route ignores logprobs and says so once per input.
      expect_identical(length(res$warnings), 2L, info = info)
      for (w in res$warnings) {
        expect_match(w, "does not support logprobs", info = info)
      }
    } else {
      expect_identical(res$warnings, character(), info = info)
    }
  }
})

test_that("a native data frame keeps the row names that named inputs give", {
  inputs <- c(a = "first", b = "second")
  native <- run_stats_batch(list(native_reply("x"), native_reply("y")), inputs)
  openai <- run_stats_batch(
    list(completion_body(quoted("x")), completion_body(quoted("y"))),
    inputs,
    api_type = "openai"
  )
  expect_identical(row.names(openai$out), c("a", "b"))
  expect_identical(row.names(native$out), row.names(openai$out))
})

# Values that are not one value of the field's type: a JSON string for
# `response_id`, a JSON number for a stats field. `other_scalar` is the
# scalar of the wrong type for the field. `inner` is one value of the right
# type, so the array and the object would read as the field if unwrapped.
bad_values <- function(other_scalar, inner) {
  list(
    absent = NULL,
    null = "null",
    `the other scalar type` = other_scalar,
    boolean = "true",
    array = json_array(inner),
    object = json_object(a = inner)
  )
}

test_that("a field that is not one value of its column type gives NA", {
  # A number where a string belongs, and a string where a number belongs.
  fields <- list(
    response_id = list(other = "5", inner = quoted("resp_x")),
    input_tokens = list(other = quoted("5"), inner = "5"),
    tokens_per_second = list(other = quoted("5"), inner = "5.5")
  )
  for (field in names(fields)) {
    values <- bad_values(fields[[field]]$other, fields[[field]]$inner)
    for (label in names(values)) {
      info <- paste(field, label)
      value <- values[label]
      body <- if (field == "response_id") {
        native_reply("kept", response_id = value[[1]])
      } else {
        stats_args <- stats::setNames(value, field)
        native_reply("kept", stats = do.call(native_stats, stats_args))
      }
      expect_no_warning(res <- run_stats_batch(list(body), capture = FALSE))
      expect_identical(res$out$output, "kept", info = info)
      na <- if (field == "response_id") NA_character_ else NA_real_
      expect_identical(res$out[[field]], na, info = info)
      # The other fields of the reply still read.
      if (field != "response_id") {
        expect_identical(res$out$response_id, "resp_1", info = info)
      }
      if (field != "total_output_tokens") {
        expect_identical(res$out$total_output_tokens, 3, info = info)
      }
    }
  }
})

test_that("an empty reply id is kept as an empty string", {
  res <- run_stats_batch(list(native_reply("kept", response_id = quoted(""))))
  expect_identical(res$out$response_id, "")
})

test_that("a stats value that is not an object, or is an empty object, gives NA in all six columns", {
  shapes <- list(
    absent = NULL,
    null = "null",
    array = "[1]",
    string = quoted("s"),
    number = "5",
    `empty object` = "{}"
  )
  for (label in names(shapes)) {
    body <- native_reply("kept", stats = shapes[[label]])
    expect_no_warning(res <- run_stats_batch(list(body), capture = FALSE))
    expect_identical(res$out$output, "kept", info = label)
    expect_identical(res$out$response_id, "resp_1", info = label)
    for (col in stats_columns) {
      expect_identical(res$out[[col]], NA_real_, info = paste(label, col))
    }
  }
})

# A failed second input: a 400, or a reply with no message item that still
# carries a readable id and stats.
failing_native <- list(
  rlmstudio_api_error = mock_response(400L, '{"error": "bad request"}'),
  rlmstudio_bad_response = mock_response(
    200L,
    json_object(
      output = json_array(),
      stats = native_stats(),
      response_id = quoted("resp_bad")
    )
  )
)

test_that("a failed input holds NA in every reply column", {
  for (cls in names(failing_native)) {
    for (logprobs in c(FALSE, TRUE)) {
      info <- paste(cls, "logprobs:", logprobs)
      res <- run_stats_batch(
        list(native_reply("reply 1"), failing_native[[cls]]),
        logprobs = logprobs
      )
      expect_identical(res$out$output, c("reply 1", NA), info = info)
      expect_reply_column_types(res$out, info)
      expect_identical(res$out$response_id, c("resp_1", NA), info = info)
      for (col in stats_columns) {
        expect_true(is.na(res$out[[col]][2]), info = paste(info, col))
        expect_false(is.na(res$out[[col]][1]), info = paste(info, col))
      }
      failure <- grep("input failed", res$warnings, value = TRUE)
      expect_identical(length(failure), 1L, info = info)
      expect_match(failure, "at position 2\\.", info = info)
    }
  }
})

test_that("the reply columns are there when every input failed", {
  for (cls in names(failing_native)) {
    for (logprobs in c(FALSE, TRUE)) {
      info <- paste(cls, "logprobs:", logprobs)
      res <- run_stats_batch(
        list(failing_native[[cls]], failing_native[[cls]]),
        logprobs = logprobs
      )
      leading <- if (logprobs) c("input", "output", "logprobs") else c("input", "output")
      expect_identical(names(res$out), c(leading, reply_columns), info = info)
      expect_reply_column_types(res$out, info)
      for (col in reply_columns) {
        expect_true(all(is.na(res$out[[col]])), info = paste(info, col))
      }
    }
  }
})

test_that("the other routes add no reply column to a data frame", {
  routes <- list(
    openresponses = function(i, logprobs) {
      lp <- if (logprobs) json_array(logprob_step("r")) else NULL
      output_body(responses_message(output_text(quoted(sprintf("reply %d", i)), lp)))
    },
    openai = function(i, logprobs) completion_body(quoted(sprintf("reply %d", i)))
  )
  for (api_type in names(routes)) {
    for (logprobs in c(FALSE, TRUE)) {
      info <- paste(api_type, "logprobs:", logprobs)
      res <- run_stats_batch(
        lapply(1:2, routes[[api_type]], logprobs = logprobs),
        api_type = api_type,
        logprobs = logprobs
      )
      expected <- if (logprobs) c("input", "output", "logprobs") else c("input", "output")
      expect_identical(names(res$out), expected, info = info)
      expect_identical(res$out$output, c("reply 1", "reply 2"), info = info)
      # A failed input would warn, so no warning means both inputs read.
      expect_identical(res$warnings, character(), info = info)
    }
  }

  res <- run_stats_batch(
    lapply(1:2, \(i) completion_body(quoted(sprintf('{"score": %d}', i)))),
    api_type = "openai",
    schema = score_schema
  )
  expect_identical(names(res$out), c("input", "output"))
  expect_identical(res$out$output, list(list(score = 1L), list(score = 2L)))
  expect_identical(res$warnings, character())
})

test_that("a single native call still returns one plain string", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(rep(list(mock_response(200L, native_reply("x"))), 3))

  out <- lms_chat_native("a-model", "hi")
  expect_identical(out, "x")
  expect_null(attributes(out))

  out <- lms_chat("a-model", "hi", api_type = "native")
  expect_identical(out, "x")
  expect_null(attributes(out))

  body <- lms_chat_native("a-model", "hi", simplify = FALSE)
  expect_identical(body$response_id, "resp_1")
  expect_identical(body$stats$input_tokens, 21L)
  expect_identical(body$stats$tokens_per_second, 284.5)
})

test_that("a native vector or list batch holds plain strings", {
  inputs <- c(a = "first", b = "second")
  replies <- list(
    mock_response(200L, native_reply("x")),
    mock_response(200L, native_reply("y"))
  )

  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(c(replies, replies))
  out <- lms_chat_batch("a-model", inputs, format = "vector", quiet = TRUE, api_type = "native")
  expect_identical(out, c(a = "x", b = "y"))
  expect_identical(names(attributes(out)), "names")

  out <- lms_chat_batch("a-model", inputs, format = "list", quiet = TRUE, api_type = "native")
  expect_identical(unname(out), list("x", "y"))
  for (x in out) {
    expect_null(attributes(x))
  }
})

test_that("a native list batch stores each failure with its class", {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    mock_response(200L, native_reply("x")),
    failing_native$rlmstudio_api_error,
    failing_native$rlmstudio_bad_response
  ))
  expect_warning(
    out <- lms_chat_batch(
      "a-model",
      c("a", "b", "c"),
      format = "list",
      quiet = TRUE,
      api_type = "native"
    ),
    "2 inputs failed"
  )
  expect_identical(out[[1]], "x")
  expect_s3_class(out[[2]], "rlmstudio_api_error")
  expect_identical(out[[2]]$status, 400L)
  expect_s3_class(out[[3]], "rlmstudio_bad_response")
})

test_that("a lost server in a native data frame carries the answer strings so far", {
  probes <- 0L
  # The batch probes once, then each input probes again, so the server is
  # gone at the second input.
  testthat::local_mocked_bindings(is_server_running = function(...) {
    probes <<- probes + 1L
    probes <= 2L
  })
  local_request_sequence(list(mock_response(200L, native_reply("x"))))
  cnd <- expect_error(
    lms_chat_batch(
      "a-model",
      c("a", "b", "c"),
      format = "data.frame",
      quiet = TRUE,
      api_type = "native"
    ),
    class = "rlmstudio_no_server"
  )
  expect_identical(cnd$results, list("x", NULL, NULL))
})
