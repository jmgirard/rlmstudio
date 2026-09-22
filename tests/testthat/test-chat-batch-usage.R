# The reply id and token count columns of a data-frame batch on the
# OpenResponses and OpenAI routes. The server is mocked through the shared
# recorder (D-004).

usage_columns <- c(
  "response_id",
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens"
)
count_columns <- usage_columns[-1]

# The source of each column on each route, as the builder argument that sets
# it. The reasoning count sits in the details object, so it is set there.
usage_sources <- list(
  openresponses = c(
    input_tokens = "input_tokens",
    total_output_tokens = "output_tokens"
  ),
  openai = c(
    input_tokens = "prompt_tokens",
    total_output_tokens = "completion_tokens"
  )
)

# A reply on `api_type` built from JSON text values. `text` is the answer, or
# a score for a schema batch. `lp` puts one logprobs step on an OpenResponses
# part.
usage_reply <- function(
  api_type,
  text = "reply",
  id = quoted("id_1"),
  usage = NULL,
  lp = FALSE
) {
  if (api_type == "openresponses") {
    if (is.null(usage)) usage <- responses_usage()
    logprobs_json <- if (lp) json_array(logprob_step("r")) else NULL
    responses_reply(text, usage = usage, id = id, logprobs_json = logprobs_json)
  } else {
    if (is.null(usage)) usage <- openai_usage()
    openai_reply(quoted(text), usage = usage, id = id)
  }
}

# A `usage` object on `api_type` with the three counts given as JSON text.
# `details` replaces the whole details object when it is given.
usage_json <- function(api_type, input, output, reasoning, details = NULL) {
  if (is.null(details)) {
    details <- json_object(reasoning_tokens = reasoning)
  }
  if (api_type == "openresponses") {
    responses_usage(input, output, details)
  } else {
    openai_usage(input, output, details)
  }
}

# Run a data-frame batch whose input i is answered by `responses[[i]]`, a
# response or a body string. Returns the result and the warnings.
run_usage_batch <- function(responses, api_type, logprobs = FALSE, schema = FALSE) {
  responses <- lapply(responses, function(r) {
    if (is.character(r)) mock_response(200L, r) else r
  })
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(responses)
  args <- list(
    "a-model",
    paste("input", seq_along(responses)),
    format = "data.frame",
    quiet = TRUE,
    api_type = api_type
  )
  if (logprobs) {
    args$logprobs <- TRUE
  }
  if (schema) {
    args$schema <- score_schema
  }
  warnings <- testthat::capture_warnings(out <- do.call(lms_chat_batch, args))
  list(out = out, warnings = warnings)
}

# The settings of AC1 and AC2: each route with and without logprobs, and the
# OpenAI route with a schema.
usage_settings <- list(
  list(api_type = "openresponses", logprobs = FALSE, schema = FALSE),
  list(api_type = "openresponses", logprobs = TRUE, schema = FALSE),
  list(api_type = "openai", logprobs = FALSE, schema = FALSE),
  list(api_type = "openai", logprobs = TRUE, schema = FALSE),
  list(api_type = "openai", logprobs = FALSE, schema = TRUE)
)

setting_info <- function(s) {
  paste(s$api_type, "logprobs:", s$logprobs, "schema:", s$schema)
}

# The columns before the new ones.
leading_columns <- function(s) {
  if (s$logprobs) c("input", "output", "logprobs") else c("input", "output")
}

# The answer text of reply i, or its score for a schema batch.
answer_text <- function(s, i) {
  if (s$schema) sprintf('{"score": %d}', i) else sprintf("reply %d", i)
}

expect_usage_column_types <- function(df, info = NULL) {
  expect_identical(typeof(df$response_id), "character", info = info)
  for (col in count_columns) {
    expect_identical(typeof(df[[col]]), "double", info = paste(info, col))
  }
}

test_that("a data-frame batch adds the id and token counts of each reply", {
  counts <- list(c("32", "2", "0"), c("64", "9", "5"))
  expected <- list(
    response_id = c("id_a", "id_b"),
    input_tokens = c(32, 64),
    total_output_tokens = c(2, 9),
    reasoning_output_tokens = c(0, 5)
  )
  for (s in usage_settings) {
    info <- setting_info(s)
    replies <- lapply(1:2, function(i) {
      usage_reply(
        s$api_type,
        answer_text(s, i),
        id = quoted(c("id_a", "id_b")[[i]]),
        usage = do.call(usage_json, c(list(s$api_type), as.list(counts[[i]]))),
        lp = s$logprobs
      )
    })
    res <- run_usage_batch(replies, s$api_type, s$logprobs, s$schema)
    expect_identical(names(res$out), c(leading_columns(s), usage_columns), info = info)
    for (col in usage_columns) {
      expect_identical(res$out[[col]], expected[[col]], info = paste(info, col))
    }
    if (s$schema) {
      expect_identical(res$out$output, list(list(score = 1L), list(score = 2L)), info = info)
    } else {
      expect_identical(res$out$output, c("reply 1", "reply 2"), info = info)
    }
    expect_identical(res$warnings, character(), info = info)
  }
})

# Values that are not one value of the column type. `other` is the scalar of
# the wrong type, and `inner` is one value of the right type, so the array and
# the object would read as the field if unwrapped.
wrong_values <- function(other, inner) {
  list(
    absent = NULL,
    null = "null",
    `the other scalar type` = other,
    boolean = "true",
    array = json_array(inner),
    object = json_object(a = inner)
  )
}

# Run one reply through a batch with no warning expected, and return the frame.
one_reply_frame <- function(api_type, body) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(mock_response(200L, body)))
  lms_chat_batch("a-model", "input", format = "data.frame", quiet = TRUE, api_type = api_type)
}

test_that("an id that is not one string gives NA and keeps the answer", {
  for (api_type in names(usage_sources)) {
    values <- wrong_values("5", quoted("id_x"))
    for (label in names(values)) {
      info <- paste(api_type, label)
      body <- usage_reply(api_type, "kept", id = values[label][[1]])
      expect_no_warning(df <- one_reply_frame(api_type, body))
      expect_identical(df$output, "kept", info = info)
      expect_identical(df$response_id, NA_character_, info = info)
      expect_identical(df$input_tokens, if (api_type == "openai") 29 else 32, info = info)
    }
    body <- usage_reply(api_type, "kept", id = quoted(""))
    expect_no_warning(df <- one_reply_frame(api_type, body))
    expect_identical(df$response_id, "", info = api_type)
  }
})

test_that("a count that is not one number gives NA in that cell alone", {
  for (api_type in names(usage_sources)) {
    defaults <- list(input = "10", output = "20", reasoning = "3")
    for (col in count_columns) {
      values <- wrong_values(quoted("5"), "5")
      for (label in names(values)) {
        info <- paste(api_type, col, label)
        args <- defaults
        key <- switch(
          col,
          input_tokens = "input",
          total_output_tokens = "output",
          reasoning_output_tokens = "reasoning"
        )
        if (is.null(values[[label]])) {
          # Absent: leave the field out of its object.
          args[key] <- list(NULL)
          if (key == "reasoning") {
            args$details <- "{}"
          }
        } else {
          args[[key]] <- values[[label]]
        }
        usage <- do.call(usage_json, c(list(api_type), args))
        body <- usage_reply(api_type, "kept", usage = usage)
        expect_no_warning(df <- one_reply_frame(api_type, body))
        expect_identical(df$output, "kept", info = info)
        expect_identical(df$response_id, "id_1", info = info)
        expected <- c(
          input_tokens = 10,
          total_output_tokens = 20,
          reasoning_output_tokens = 3
        )
        expected[[col]] <- NA_real_
        for (other in count_columns) {
          expect_identical(df[[other]], expected[[other]], info = paste(info, other))
        }
      }
    }
  }
})

# Values of `usage` or of its details object that are not a JSON object, and
# the empty object.
not_an_object <- list(
  absent = NULL,
  null = "null",
  array = "[1]",
  string = quoted("s"),
  number = "5",
  `empty object` = "{}"
)

test_that("a usage value that is not an object gives NA in all three counts", {
  for (api_type in names(usage_sources)) {
    for (label in names(not_an_object)) {
      info <- paste(api_type, label)
      value <- not_an_object[[label]]
      # usage_reply() fills in a default for a NULL usage, so an absent one is
      # built here without the field.
      body <- if (is.null(value)) {
        sub(', "usage": .*\\}$', "}", usage_reply(api_type, "kept"))
      } else {
        usage_reply(api_type, "kept", usage = value)
      }
      expect_false(is.null(value) && grepl('"usage"', body), info = info)
      expect_no_warning(df <- one_reply_frame(api_type, body))
      expect_identical(df$output, "kept", info = info)
      expect_identical(df$response_id, "id_1", info = info)
      for (col in count_columns) {
        expect_identical(df[[col]], NA_real_, info = paste(info, col))
      }
    }
  }
})

test_that("a details value that is not an object gives NA in the reasoning count alone", {
  for (api_type in names(usage_sources)) {
    for (label in names(not_an_object)) {
      info <- paste(api_type, label)
      value <- not_an_object[[label]]
      details_json <- if (is.null(value)) NULL else value
      usage <- if (api_type == "openresponses") {
        json_object(
          input_tokens = "10",
          output_tokens = "20",
          output_tokens_details = details_json
        )
      } else {
        json_object(
          prompt_tokens = "10",
          completion_tokens = "20",
          completion_tokens_details = details_json
        )
      }
      body <- usage_reply(api_type, "kept", usage = usage)
      expect_no_warning(df <- one_reply_frame(api_type, body))
      expect_identical(df$output, "kept", info = info)
      expect_identical(df$input_tokens, 10, info = info)
      expect_identical(df$total_output_tokens, 20, info = info)
      expect_identical(df$reasoning_output_tokens, NA_real_, info = info)
    }
  }
})

# A failed input for `cls` on the setting `s`. An unreadable reply still
# carries a readable id and usage, so its NA cells come from the failure.
failing_usage <- function(s, cls) {
  if (cls == "rlmstudio_api_error") {
    return(mock_response(400L, '{"error": "bad request"}'))
  }
  body <- if (s$api_type == "openresponses") {
    json_object(id = quoted("id_bad"), output = json_array(), usage = responses_usage())
  } else if (s$schema) {
    openai_reply(quoted("not json"), id = quoted("id_bad"))
  } else {
    json_object(id = quoted("id_bad"), usage = openai_usage())
  }
  mock_response(200L, body)
}

test_that("a failed input holds NA in all four columns", {
  for (s in usage_settings) {
    for (cls in c("rlmstudio_api_error", "rlmstudio_bad_response")) {
      info <- paste(setting_info(s), cls)
      ok <- usage_reply(s$api_type, answer_text(s, 1L), lp = s$logprobs)
      res <- run_usage_batch(list(ok, failing_usage(s, cls)), s$api_type, s$logprobs, s$schema)
      expect_identical(names(res$out), c(leading_columns(s), usage_columns), info = info)
      expect_usage_column_types(res$out, info)
      expect_identical(res$out$response_id, c("id_1", NA), info = info)
      first <- if (s$api_type == "openai") c(29, 4, 0) else c(32, 2, 0)
      for (j in seq_along(count_columns)) {
        col <- count_columns[[j]]
        expect_identical(res$out[[col]], c(first[[j]], NA), info = paste(info, col))
      }
      expect_identical(length(res$warnings), 1L, info = info)
      expect_match(res$warnings, "1 input failed, at position 2\\.", info = info)
    }
  }
})

test_that("the four columns are there when every input failed", {
  for (s in usage_settings) {
    for (cls in c("rlmstudio_api_error", "rlmstudio_bad_response")) {
      info <- paste(setting_info(s), cls)
      res <- run_usage_batch(
        list(failing_usage(s, cls), failing_usage(s, cls)),
        s$api_type,
        s$logprobs,
        s$schema
      )
      expect_identical(names(res$out), c(leading_columns(s), usage_columns), info = info)
      expect_usage_column_types(res$out, info)
      for (col in usage_columns) {
        expect_true(all(is.na(res$out[[col]])), info = paste(info, col))
      }
    }
  }
})

test_that("a lost server keeps what the results field held before", {
  cases <- list(
    list(s = usage_settings[[1]], check = function(x) expect_identical(x, "reply 1")),
    list(s = usage_settings[[2]], check = function(x) {
      expect_s3_class(x, "lms_chat_result")
      expect_identical(x$text, "reply 1")
      expect_identical(x$logprobs$step_token, "r")
    }),
    list(s = usage_settings[[5]], check = function(x) expect_identical(x, list(score = 1L)))
  )
  for (case in cases) {
    s <- case$s
    probes <- 0L
    # The batch probes once, then each input probes again, so the server is
    # gone at the second input.
    testthat::local_mocked_bindings(is_server_running = function(...) {
      probes <<- probes + 1L
      probes <= 2L
    })
    local_request_sequence(list(
      mock_response(200L, usage_reply(s$api_type, answer_text(s, 1L), lp = s$logprobs))
    ))
    args <- list(
      "a-model",
      c("a", "b", "c"),
      format = "data.frame",
      quiet = TRUE,
      api_type = s$api_type
    )
    if (s$logprobs) args$logprobs <- TRUE
    if (s$schema) args$schema <- score_schema
    cnd <- expect_error(do.call(lms_chat_batch, args), class = "rlmstudio_no_server")
    expect_length(cnd$results, 3L)
    case$check(cnd$results[[1]])
    expect_null(cnd$results[[2]])
    expect_null(cnd$results[[3]])
  }
})
