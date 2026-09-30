# Extracted from test-chat-batch-usage.R:430

# prequel ----------------------------------------------------------------------
usage_columns <- c(
  "response_id",
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens"
)
count_columns <- usage_columns[-1]
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
leading_columns <- function(s) {
  if (s$logprobs) c("input", "output", "logprobs") else c("input", "output")
}
trailing_columns <- function(s) {
  if (s$schema) "score" else character()
}
answer_text <- function(s, i) {
  if (s$schema) sprintf('{"score": %d}', i) else sprintf("reply %d", i)
}
expect_usage_column_types <- function(df, info = NULL) {
  expect_identical(typeof(df$response_id), "character", info = info)
  for (col in count_columns) {
    expect_identical(typeof(df[[col]]), "double", info = paste(info, col))
  }
}
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
one_reply_frame <- function(api_type, body) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(mock_response(200L, body)))
  lms_chat_batch("a-model", "input", format = "data.frame", quiet = TRUE, api_type = api_type)
}
not_an_object <- list(
  absent = NULL,
  null = "null",
  array = "[1]",
  string = quoted("s"),
  number = "5",
  `empty object` = "{}"
)
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
single_value <- function(s, body) {
  testthat::local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(mock_response(200L, body)))
  args <- list("a-model", "input", api_type = s$api_type, logprobs = s$logprobs)
  if (s$schema) {
    args$schema <- score_schema
  }
  tryCatch(do.call(lms_chat, args), error = identity)
}

# test -------------------------------------------------------------------------
for (s in usage_settings) {
    info <- setting_info(s)
    bodies <- lapply(1:2, \(i) usage_reply(s$api_type, answer_text(s, i), lp = s$logprobs))
    res <- run_usage_batch(bodies, s$api_type, s$logprobs, s$schema)
    for (i in 1:2) {
      single <- single_value(s, bodies[[i]])
      expect_false(inherits(single, "error"), info = info)
      if (s$schema) {
        expect_identical(res$out$output[[i]], single, info = info)
      } else if (s$logprobs) {
        expect_s3_class(single, "lms_chat_result")
        expect_identical(res$out$output[[i]], single$text, info = info)
        expect_identical(res$out$logprobs[[i]], single$logprobs, info = info)
      } else {
        expect_identical(res$out$output[[i]], single, info = info)
      }
    }
    if (s$api_type == "openresponses" && s$logprobs) {
      # The route that carries logprobs, so the column holds data frames.
      expect_s3_class(res$out$logprobs[[1]], "data.frame")
    }
  }
