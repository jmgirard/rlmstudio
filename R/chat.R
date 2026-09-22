#' Chat Completion with LM Studio
#'
#' Send a prompt to a locally running LM Studio model. This wrapper
#' automatically routes your request to the appropriate subfunction based on the
#' selected API type.
#'
#' @param model Character. The name of the loaded model. Must be one name,
#'   given as a single string.
#' @param input Character. The user prompt to send to the model. A character
#'   vector must hold no missing values.
#' @param system_prompt Character. An optional system prompt to guide model
#'   behavior.
#' @param host Character. The base URL of the LM Studio server. Default is
#'   "http://localhost:1234".
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param api_type Character. The LM Studio API endpoint to use. Options are
#'   "openresponses" (default), "openai", or "native".
#' @param logprobs Logical. Whether to return the log probabilities of the
#'   generated tokens. Default is FALSE.
#' @param simplify Logical. If TRUE, extracts the core text response. Default is
#'   TRUE.
#' @param ... Additional arguments passed to the selected API body.
#' @param schema A JSON Schema that the reply must match, or `NULL`. It needs
#'   `api_type = "openai"`, and any other `api_type` aborts before the request.
#'   See [lms_chat_openai()] for its form and for what is returned.
#' @return Depending on the arguments provided:
#' \itemize{
#'   \item If \code{simplify = FALSE}, returns a parsed list of the raw JSON response.
#'   \item If \code{simplify = TRUE} and \code{logprobs = FALSE}, returns a single character string containing the model's text response. With a \code{schema}, it returns the reply parsed into an R value instead.
#'   \item If \code{simplify = TRUE} and \code{logprobs = TRUE} (and the chosen API type supports it), returns an object of class \code{lms_chat_result} containing both the text and a data.frame of token probabilities.
#' }
#' @details
#' This function calls [lms_chat_openresponses()], [lms_chat_openai()], or
#' [lms_chat_native()], according to `api_type`. It runs no request of its own.
#' It can raise `rlmstudio_no_server` and `rlmstudio_api_error` through
#' [lms_chat_openresponses()], [lms_chat_openai()], or [lms_chat_native()].
#' With `simplify = TRUE`, it can raise `rlmstudio_bad_response` through any
#' of the three, for a reply that holds no readable answer text.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @export
lms_chat <- function(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  api_type = c("openresponses", "openai", "native"),
  logprobs = FALSE,
  simplify = TRUE,
  ...,
  schema = NULL,
  token = NULL
) {
  api_type <- match.arg(api_type)
  rlm_check_id(model, "model")
  rlm_check_no_na(input, "input")
  rlm_check_schema(schema, ...names())
  rlm_check_schema_route(schema, api_type)

  if (api_type == "openresponses") {
    return(lms_chat_openresponses(
      model = model,
      input = input,
      instructions = system_prompt,
      host = host,
      logprobs = logprobs,
      simplify = simplify,
      ...,
      token = token
    ))
  }

  if (api_type == "openai") {
    msgs <- list()
    if (!is.null(system_prompt)) {
      msgs[[length(msgs) + 1]] <- list(role = "system", content = system_prompt)
    }
    msgs[[length(msgs) + 1]] <- list(role = "user", content = input)

    return(lms_chat_openai(
      model = model,
      messages = msgs,
      host = host,
      logprobs = logprobs,
      simplify = simplify,
      ...,
      schema = schema,
      token = token
    ))
  }

  if (api_type == "native") {
    if (isTRUE(logprobs)) {
      cli::cli_warn(
        "The 'native' API type does not support logprobs. Ignoring argument."
      )
    }
    return(lms_chat_native(
      model = model,
      input = input,
      system_prompt = system_prompt,
      host = host,
      simplify = simplify,
      ...,
      token = token
    ))
  }
}

#' Chat Completion via OpenResponses API
#'
#' Direct interface to LM Studio's OpenResponses endpoint. Supports logprobs and
#' custom instructions.
#'
#' @param model Character. The loaded model name. Must be one name, given as a
#'   single string.
#' @param input Character. The user prompt. A character vector must hold no
#'   missing values.
#' @param instructions Character. Optional system instructions.
#' @param host Character. Server URL.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param logprobs Logical. Whether to return token probabilities.
#' @param simplify Logical. If TRUE, parses output to text and dataframe. If
#'   FALSE, returns raw list.
#' @param ... Additional API arguments (e.g., top_logprobs, temperature).
#' @return If \code{simplify = FALSE}, returns a list representing the raw JSON
#'   response. Otherwise, returns one character string: the `text` of every
#'   part of type `"output_text"` in the items of type `"message"`, pasted
#'   together in order with no separator. Reasoning items, tool calls, and
#'   parts of other types, such as a refusal, are skipped. If
#'   \code{logprobs = TRUE} and at least one of those parts carries log
#'   probabilities, returns an object of class \code{lms_chat_result} with that
#'   text and a data frame of the probabilities of every such part, in order.
#'   If no part carries them, it returns the string. A reply with no readable
#'   answer text raises `rlmstudio_bad_response`, as described below.
#'
#'   The data frame has one row for each candidate in the `top_logprobs` of
#'   each step, or one row with `NA` candidates for a step with none. Each
#'   field is read by its exact name. A field that is `null` or absent gives
#'   `NA`, and so does a field whose name only starts with the one asked for,
#'   such as `tokenX`. With `logprobs = TRUE`, the `logprobs` value of each
#'   `"output_text"` part must follow six rules, which the section below
#'   lists. A value that breaks one raises `rlmstudio_bad_response`, and the
#'   message names the first broken rule in the order the section below
#'   gives. Parts of other types are not checked. With `logprobs = FALSE`, the value is not read, and the call
#'   returns the text.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @export
lms_chat_openresponses <- function(
  model,
  input,
  instructions = NULL,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_no_na(input, "input")

  stop_if_no_server(host)

  body <- list(model = model, input = input, instructions = instructions)
  if (isTRUE(logprobs)) {
    body$include <- list("message.output_text.logprobs")
  }

  body <- Filter(Negate(is.null), body)
  body <- utils::modifyList(body, list(...))

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path("v1/responses") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)
    if (!isTRUE(simplify)) {
      return(resp_data)
    }
    return(responses_reply_value(resp, resp_data, logprobs))
  }

  rlm_abort_api(resp, "OpenResponses Failed", !is.null(rlm_token(token)))
}

#' Read the answer of an OpenResponses reply
#'
#' What `lms_chat_openresponses()` returns with `simplify = TRUE`. Shared with
#' the OpenResponses data-frame route of `lms_chat_batch()`, so a reply fails
#' there with the same class and message.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param resp_data The parsed response body.
#' @param logprobs Logical. Whether log probabilities were asked for.
#' @return One string, or an `lms_chat_result` when a part carries logprobs.
#'
#' @noRd
responses_reply_value <- function(resp, resp_data, logprobs) {
  label <- "OpenResponses Failed"
  parts <- responses_text_parts(resp, resp_data, label)
  text <- join_reply_texts(
    resp,
    lapply(parts, \(part) part[["text"]]),
    label,
    "The `text` of an `output_text` part is not one string."
  )
  if (!isTRUE(logprobs)) {
    return(text)
  }

  check_part_logprobs(resp, parts, label)
  # The steps of every part in order. A part without logprobs adds none.
  steps <- unlist(
    lapply(parts, \(part) part[["logprobs"]]),
    recursive = FALSE
  )
  if (length(steps) == 0L) {
    return(text)
  }

  validate_lms_chat_result(
    new_lms_chat_result(text = text, logprobs = logprobs_frame(steps))
  )
}

#' Chat Completion via OpenAI Compatibility API
#'
#' Direct interface to LM Studio's OpenAI-compatible endpoint. Uses the messages
#' array format.
#'
#' @param model Character. The loaded model name. Must be one name, given as a
#'   single string.
#' @param messages List. A structured list of role and content pairs.
#' @param host Character. Server URL.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param logprobs Logical. Whether to request logprobs (currently stubbed by LM
#'   Studio).
#' @param simplify Logical. If TRUE, parses output to text.
#' @param ... Additional API arguments. A `response_format` here cannot be
#'   combined with `schema`.
#' @param schema A JSON Schema, written as a named list, that the reply must
#'   match, or `NULL` for a free text reply. It is sent as the `schema` field
#'   of a `response_format` of type `"json_schema"`, with the name
#'   `"response"` and `strict` set to `true`. A JSON array of one item must be
#'   written as a list, such as `required = list("score")`, or wrapped in
#'   [I()]. A plain vector of length one is sent as a single value, not as an
#'   array. An empty object nested in the schema, such as `properties`, is
#'   written `setNames(list(), character())`, because `list()` is sent as the
#'   empty array `[]`. The package checks only that `schema` is a named list,
#'   an empty list, or `NULL`. The server checks the schema itself.
#' @return If \code{simplify = FALSE}, returns a list representing the raw JSON
#'   response. Otherwise, returns a character string containing the generated
#'   text. If \code{logprobs = TRUE}, it returns an \code{lms_chat_result}
#'   object with the log probabilities populated as \code{NULL} since they are
#'   currently stubbed in the LM Studio OpenAI endpoint. With
#'   \code{simplify = TRUE}, reply content that is not one string, such as the
#'   `null` content of a reply that holds only a tool call, raises
#'   `rlmstudio_bad_response`.
#'
#'   With a `schema`, `simplify = TRUE`, and `logprobs = FALSE`, the reply is
#'   parsed with `jsonlite::parse_json(simplifyVector = TRUE)` and the parsed
#'   value is returned. A JSON object becomes a named list, and an array of
#'   numbers becomes a vector. With `simplify = FALSE` or `logprobs = TRUE`,
#'   the reply stays a string.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @export
#' @examples
#' \dontrun{
#' lms_chat_openai(
#'   model = "google/gemma-3-1b",
#'   messages = list(
#'     list(role = "user", content = "Rate 'Great value.' from 1 to 5.")
#'   ),
#'   schema = list(
#'     type = "object",
#'     properties = list(score = list(type = "integer")),
#'     required = list("score")
#'   )
#' )
#' }
lms_chat_openai <- function(
  model,
  messages,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...,
  schema = NULL,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_schema(schema, ...names())

  stop_if_no_server(host)

  body <- list(model = model, messages = messages)
  if (isTRUE(logprobs)) {
    body$logprobs <- TRUE
  }

  body <- Filter(Negate(is.null), body)
  if (!is.null(schema)) {
    body$response_format <- schema_response_format(schema)
  }
  body <- utils::modifyList(body, list(...))

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path("v1/chat/completions") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)
    if (!isTRUE(simplify)) {
      return(resp_data)
    }
    return(openai_reply_value(resp, resp_data, logprobs, schema))
  }

  rlm_abort_api(resp, "OpenAI API Failed", !is.null(rlm_token(token)))
}

#' Read the answer of a chat completions reply
#'
#' What `lms_chat_openai()` returns with `simplify = TRUE`. Shared with the
#' OpenAI data-frame route of `lms_chat_batch()`, so a reply fails there with
#' the same class and message.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param resp_data The parsed response body.
#' @param logprobs Logical. Whether log probabilities were asked for.
#' @param schema The schema the request sent, or `NULL`.
#' @return The reply text, an `lms_chat_result`, or the parsed schema reply.
#'
#' @noRd
openai_reply_value <- function(resp, resp_data, logprobs, schema) {
  check_body_object(resp, resp_data, "OpenAI API Failed")
  # A 200 with no reply in it would otherwise reach the `[[1]]` below. An
  # empty list fails there with a subscript error that names neither the
  # response nor the field. A missing field gives back NULL as the reply,
  # which a plain call returns and a `logprobs` call fails on. A JSON object
  # in place of the array would be read by its first value. A first element
  # that is a plain value fails on `$` with a base R error, and one that is
  # an array gives back NULL as the reply. The same holds for its `message`.
  # Fields are read with `[[`, because `$` would read a field whose name only
  # starts with the one asked for.
  choices <- resp_data[["choices"]]
  is_object <- function(x) is.list(x) && !is.null(names(x))
  if (
    !is.list(choices) ||
      length(choices) == 0L ||
      !is.null(names(choices)) ||
      !is_object(choices[[1]]) ||
      !is_object(choices[[1]][["message"]])
  ) {
    rlm_abort_bad_response(
      resp,
      "OpenAI API Failed",
      "The response holds no readable reply in its `choices` field.",
      content = NULL,
      finish_reason = NULL
    )
  }
  res_text <- choices[[1]][["message"]][["content"]]
  finish_reason <- choices[[1]][["finish_reason"]]

  # A reply that is returned as text must be one string. Content that is
  # `null` or absent, as with a reply that holds only a tool call, has no
  # answer text (D-012). A schema reply without logprobs is checked by
  # parse_schema_reply() below instead.
  if ((is.null(schema) || isTRUE(logprobs)) && !is_one_string(res_text)) {
    abort_unread_reply(
      resp,
      res_text,
      "OpenAI API Failed",
      "The reply content is not one string.",
      finish_reason
    )
  }

  if (isTRUE(logprobs)) {
    # Return S3 object with NULL logprobs (since OpenAI endpoint is a stub in LM Studio)
    return(validate_lms_chat_result(
      new_lms_chat_result(text = res_text, logprobs = NULL)
    ))
  }
  if (!is.null(schema)) {
    return(parse_schema_reply(
      resp,
      res_text,
      "OpenAI API Failed",
      finish_reason = finish_reason
    ))
  }
  res_text
}

#' Abort on a response body that is a bare JSON value
#'
#' A body such as `5`, `"s"`, or `true` parses to an atomic value, and reading
#' a field out of it with `[[` fails with a base R "subscript out of bounds"
#' error. A body of `null` parses to `NULL`, and each route's own checks name
#' that case, so it passes here. A top-level array parses to a list and passes
#' too.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param resp_data The parsed response body.
#' @param label Character. The calling wrapper's label.
#'
#' @noRd
check_body_object <- function(resp, resp_data, label) {
  if (!is.null(resp_data) && !is.list(resp_data)) {
    rlm_abort_bad_response(
      resp,
      label,
      "The response body is not a JSON object."
    )
  }
}

#' Build the structured-output field of a chat completions request
#'
#' The shape LM Studio documents for `/v1/chat/completions`. An empty `schema`
#' is given empty names, because jsonlite writes an unnamed empty list as the
#' array `[]` and a named one as the object `{}`.
#'
#' @param schema A named list or an empty list, already checked by
#'   `rlm_check_schema()`.
#' @return A list for the `response_format` field of the request body.
#'
#' @noRd
schema_response_format <- function(schema) {
  if (length(schema) == 0L) {
    schema <- structure(list(), names = character())
  }
  list(
    type = "json_schema",
    json_schema = list(name = "response", strict = TRUE, schema = schema)
  )
}

#' Parse the JSON reply to a structured-output request
#'
#' `jsonlite::parse_json()` rather than `jsonlite::fromJSON()`, because
#' `fromJSON()` fetches a string that looks like a URL and reads a string that
#' names a file on disk. A model reply is text the package did not write.
#'
#' Both aborts carry the reply content and the finish reason as fields, so a
#' caller can read what the model wrote without sending the request again. A
#' finish reason of `"length"` means the server stopped the reply at the token
#' limit, which is the likely reason the JSON is incomplete, so the message
#' says so in place of the generic detail.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param content The reply content read out of the response.
#' @param label Character. The calling wrapper's label, which opens the message.
#' @param finish_reason The `finish_reason` of the first choice, or `NULL`.
#' @return The parsed reply.
#'
#' @noRd
parse_schema_reply <- function(resp, content, label, finish_reason = NULL) {
  abort_unread <- function(detail) {
    abort_unread_reply(resp, content, label, detail, finish_reason)
  }

  if (!is_one_string(content)) {
    abort_unread("The reply content is not one string.")
  }
  tryCatch(
    jsonlite::parse_json(content, simplifyVector = TRUE),
    error = function(cnd) abort_unread("The reply content is not valid JSON.")
  )
}

#' Abort on a chat completions reply that cannot be read
#'
#' The abort carries the reply content and the finish reason as fields, so a
#' caller can read what the model wrote without sending the request again. A
#' finish reason of `"length"` means the server stopped the reply at the token
#' limit, which is the likely reason the reply is incomplete, so the message
#' says so in place of `detail`.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param content The reply content read out of the response.
#' @param label Character. The calling wrapper's label, which opens the message.
#' @param detail Character. What is wrong with the reply.
#' @param finish_reason The `finish_reason` of the first choice, or `NULL`.
#'
#' @noRd
abort_unread_reply <- function(resp, content, label, detail, finish_reason) {
  if (identical(finish_reason, "length")) {
    detail <- paste(
      "The token limit cut the reply off before it was complete.",
      "Raise `max_tokens` to allow a longer reply."
    )
  }
  # The detail is inserted into the message as text, so cli markup in it
  # would print as written. The hint below is a template of its own.
  # A NULL content has no text to point at, so its hint says so. A NULL
  # finish reason is not pointed at either.
  hint <- if (is.null(content)) {
    "The reply has no text, so the {.field content} field of the condition is {.code NULL}."
  } else {
    "The reply content is in the {.field content} field of the condition."
  }
  if (!is.null(finish_reason)) {
    hint <- paste(
      hint,
      "The finish reason is in its {.field finish_reason} field."
    )
  }
  rlm_abort_bad_response(
    resp,
    label,
    detail,
    hint = hint,
    content = content,
    finish_reason = finish_reason
  )
}

#' Read the message items of a native or OpenResponses reply
#'
#' Both endpoints return an `output` array of typed items. A reasoning model
#' puts a `reasoning` item before the message, and a call with tools puts
#' `tool_call` items between messages, so the answer is read from the items of
#' type `"message"` and never from the first item. An item of any other type,
#' or with no `type`, is skipped. Fields are read with `[[`, because `$` would
#' read a field whose name only starts with the one asked for.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param resp_data The parsed response body.
#' @param label Character. The calling wrapper's label, which opens the message.
#' @return A list of the message items, never empty.
#'
#' @noRd
chat_message_items <- function(resp, resp_data, label) {
  check_body_object(resp, resp_data, label)
  output <- resp_data[["output"]]
  if (!is_json_array(output) || length(output) == 0L) {
    rlm_abort_bad_response(
      resp,
      label,
      "The response holds no `output` array of reply items."
    )
  }
  if (!all(vapply(output, is_json_object, logical(1)))) {
    rlm_abort_bad_response(
      resp,
      label,
      "An item of the `output` array is not a JSON object."
    )
  }
  messages <- Filter(\(item) identical(item[["type"]], "message"), output)
  if (length(messages) == 0L) {
    rlm_abort_bad_response(
      resp,
      label,
      "The reply holds no message item, so it has no answer text."
    )
  }
  messages
}

#' Read the output_text parts of an OpenResponses reply
#'
#' An OpenResponses message item holds an array of parts. The answer is in the
#' parts of type `"output_text"`. A part of any other type, such as a
#' `refusal`, is skipped.
#'
#' @inheritParams chat_message_items
#' @return A list of the `output_text` parts of every message item, in order,
#'   never empty.
#'
#' @noRd
responses_text_parts <- function(resp, resp_data, label) {
  messages <- chat_message_items(resp, resp_data, label)
  contents <- lapply(messages, \(item) item[["content"]])
  if (!all(vapply(contents, is_json_array, logical(1)))) {
    rlm_abort_bad_response(
      resp,
      label,
      "The `content` of a message item is not an array of parts."
    )
  }
  parts <- unlist(contents, recursive = FALSE)
  if (!all(vapply(parts, is_json_object, logical(1)))) {
    rlm_abort_bad_response(
      resp,
      label,
      "A part of a message item is not a JSON object."
    )
  }
  parts <- Filter(\(part) identical(part[["type"]], "output_text"), parts)
  if (length(parts) == 0L) {
    rlm_abort_bad_response(
      resp,
      label,
      "The reply holds no `output_text` part, so it has no answer text."
    )
  }
  parts
}

#' Join the answer texts of a reply, or abort if one is not a string
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param texts A list of the text values read out of the reply.
#' @param label Character. The calling wrapper's label.
#' @param detail Character. What the abort says is not one string.
#' @return One string, the texts pasted together with no separator.
#'
#' @noRd
join_reply_texts <- function(resp, texts, label, detail) {
  if (!all(vapply(texts, is_one_string, logical(1)))) {
    rlm_abort_bad_response(resp, label, detail)
  }
  paste(unlist(texts), collapse = "")
}

#' Check the logprobs of the output_text parts of an OpenResponses reply
#'
#' The value of each part must follow six rules:
#' 1. It is absent, `null`, or an array.
#' 2. Each step in the array is a JSON object.
#' 3. The `token` of a step is absent, `null`, or a string.
#' 4. The `logprob` of a step is absent, `null`, or a number.
#' 5. The `top_logprobs` of a step is absent, `null`, or an array of JSON
#'    objects.
#' 6. The `token` and `logprob` of each of those objects follow rules 3 and 4.
#'
#' The parts are checked in order, then the steps of a part, then the
#' candidates of a step, one at a time. Within a step, rules 2 to 4 are
#' checked in number order, then that `top_logprobs` is an array, then each
#' candidate against rule 5 and then rule 6. The first broken rule reached in
#' that order aborts, with one message per rule. Fields are read with `[[`, because `$` would read a
#' field whose name only starts with the one asked for.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param parts The `output_text` parts, from `responses_text_parts()`.
#' @param label Character. The calling wrapper's label.
#'
#' @noRd
check_part_logprobs <- function(resp, parts, label) {
  abort_rule <- function(detail) {
    rlm_abort_bad_response(
      resp,
      label,
      detail,
      hint = paste(
        "Call again with {.code logprobs = FALSE} to get the text alone,",
        "or with {.code simplify = FALSE} to get the body unchanged."
      )
    )
  }
  abort_top_logprobs <- function() {
    abort_rule(paste(
      "The `top_logprobs` of a `logprobs` step is not an array of JSON",
      "objects."
    ))
  }
  # A field that is absent or `null` reads as NULL.
  is_null_or <- function(x, test) is.null(x) || test(x)
  is_string <- function(x) is.character(x) && length(x) == 1L
  is_number <- function(x) is.numeric(x) && length(x) == 1L

  for (part in parts) {
    steps <- part[["logprobs"]]
    if (!is_null_or(steps, is_json_array)) {
      abort_rule("The `logprobs` of an `output_text` part is not an array.")
    }
    for (step in steps) {
      if (!is_json_object(step)) {
        abort_rule(
          "A step in the `logprobs` of an `output_text` part is not a JSON object."
        )
      }
      if (!is_null_or(step[["token"]], is_string)) {
        abort_rule("The `token` of a `logprobs` step is not a string.")
      }
      if (!is_null_or(step[["logprob"]], is_number)) {
        abort_rule("The `logprob` of a `logprobs` step is not a number.")
      }
      candidates <- step[["top_logprobs"]]
      if (!is_null_or(candidates, is_json_array)) {
        abort_top_logprobs()
      }
      # One candidate at a time, as for the steps, so a bad field in one
      # candidate is named before a later candidate that is not an object.
      for (candidate in candidates) {
        if (!is_json_object(candidate)) {
          abort_top_logprobs()
        }
        if (
          !is_null_or(candidate[["token"]], is_string) ||
            !is_null_or(candidate[["logprob"]], is_number)
        ) {
          abort_rule(paste(
            "A candidate in `top_logprobs` has a `token` that is not a string",
            "or a `logprob` that is not a number."
          ))
        }
      }
    }
  }
}

#' Build the logprobs data frame of an OpenResponses reply
#'
#' One row per candidate of each step, or one row with `NA` candidates for a
#' step with no candidates. A field that is absent or `null` gives `NA`.
#' Fields are read by exact name with `[[`.
#'
#' @param steps The steps of every `output_text` part in order, already
#'   checked by `check_part_logprobs()`.
#' @return A data frame with the columns `step_token`, `step_logprob`,
#'   `candidate_token`, and `candidate_logprob`.
#'
#' @noRd
logprobs_frame <- function(steps) {
  or_na <- function(x, na) if (is.null(x)) na else x
  rows <- lapply(steps, function(step) {
    candidates <- step[["top_logprobs"]]
    if (length(candidates) == 0L) {
      candidates <- list(NULL)
    }
    data.frame(
      step_token = or_na(step[["token"]], NA_character_),
      step_logprob = or_na(step[["logprob"]], NA_real_),
      # unlist() rather than vapply(), so a JSON integer stays an integer
      # and rbind() promotes the column as it did for one frame per row.
      candidate_token = unlist(lapply(
        candidates,
        \(cand) or_na(cand[["token"]], NA_character_)
      )),
      candidate_logprob = unlist(lapply(
        candidates,
        \(cand) or_na(cand[["logprob"]], NA_real_)
      )),
      stringsAsFactors = FALSE
    )
  })
  frame <- do.call(rbind, rows)
  rownames(frame) <- NULL
  frame
}

# A parsed JSON body keeps an array as an unnamed list, the counterpart of
# `is_json_object()` in R/embed.R.
is_json_array <- function(x) is.list(x) && is.null(names(x))
is_one_string <- function(x) is.character(x) && length(x) == 1L && !is.na(x)

#' Chat Completion via Native API
#'
#' Direct interface to LM Studio's v1 Native endpoint. Optimized for stateful chats and hardware control.
#'
#' @param model Character. The loaded model name. Must be one name, given as a
#'   single string.
#' @param input Character. The user prompt. A character vector must hold no
#'   missing values.
#' @param system_prompt Character. Optional system prompt.
#' @param host Character. Server URL.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param simplify Logical. If TRUE, parses output to text.
#' @param ... Additional API arguments.
#' @return If \code{simplify = FALSE}, returns a list representing the raw JSON
#'   response. The body can hold a `response_id` for the reply and a `stats`
#'   object of token counts and timings. With `api_type = "native"` and
#'   `format = "data.frame"`, [lms_chat_batch()] returns the id and six of
#'   the `stats` fields as columns. If \code{simplify = TRUE},
#'   returns one character string: the
#'   `content` of every item of type `"message"` in the `output` array, pasted
#'   together in order with no separator. Items of other types, such as
#'   reasoning and tool calls, are skipped. A reply with no readable answer
#'   text raises `rlmstudio_bad_response`, as described below.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @export
lms_chat_native <- function(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  simplify = TRUE,
  ...,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_no_na(input, "input")

  stop_if_no_server(host)

  body <- list(model = model, input = input, system_prompt = system_prompt)
  body <- Filter(Negate(is.null), body)

  # Check if user tried to pass logprobs in dots and warn them
  dots <- list(...)
  if (isTRUE(dots$logprobs)) {
    cli::cli_warn(
      "The native API does not support logprobs. Ignoring argument."
    )
    dots$logprobs <- NULL
  }
  body <- utils::modifyList(body, dots)

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/chat") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)
    if (!isTRUE(simplify)) {
      return(resp_data)
    }
    return(native_reply_text(resp, resp_data))
  }

  rlm_abort_api(resp, "Native API Failed", !is.null(rlm_token(token)))
}

#' Read the answer text of a native reply
#'
#' The text of every message item, pasted together in order. Shared by
#' `lms_chat_native()` and the native data-frame route of `lms_chat_batch()`,
#' so a reply fails there with the same class and message.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param resp_data The parsed response body.
#' @return One string.
#'
#' @noRd
native_reply_text <- function(resp, resp_data) {
  label <- "Native API Failed"
  messages <- chat_message_items(resp, resp_data, label)
  join_reply_texts(
    resp,
    lapply(messages, \(item) item[["content"]]),
    label,
    "The `content` of a message item is not one string."
  )
}

# The fields of the `stats` object of a native reply that a native data-frame
# batch returns as columns, in column order.
native_stats_fields <- c(
  "input_tokens",
  "total_output_tokens",
  "reasoning_output_tokens",
  "tokens_per_second",
  "time_to_first_token_seconds",
  "model_load_time_seconds"
)

#' Read the reply id and the stats of a native reply
#'
#' These values are extra to the answer, so a value of the wrong type gives
#' `NA` and never fails the input. A live reply can leave a field out, such
#' as `model_load_time_seconds`. Fields are read with `[[`, because `$` would
#' read a field whose name only starts with the one asked for.
#'
#' @param resp_data The parsed response body.
#' @return A list with `response_id`, one string or `NA_character_`, and the
#'   fields in `native_stats_fields`, each one double or `NA_real_`.
#'
#' @noRd
native_reply_fields <- function(resp_data) {
  stats_obj <- object_or_empty(resp_data[["stats"]])
  numbers <- lapply(
    native_stats_fields,
    \(field) number_or_na(stats_obj[[field]])
  )
  names(numbers) <- native_stats_fields
  c(list(response_id = string_or_na(resp_data[["response_id"]])), numbers)
}

# A reply field read into a batch column: one string or one number, else NA.
string_or_na <- function(x) if (is_one_string(x)) x else NA_character_
number_or_na <- function(x) {
  if (is.numeric(x) && length(x) == 1L) as.double(x) else NA_real_
}
# A JSON object, or an empty list in place of any other value, so that a
# field read out of it gives NULL.
object_or_empty <- function(x) if (is_json_object(x)) x else list()

# The `usage` fields of an OpenResponses or chat completions reply that the
# data-frame batch on that route returns, by column name. The reasoning count
# sits in the details object named here.
usage_field_names <- list(
  openresponses = c(
    input_tokens = "input_tokens",
    total_output_tokens = "output_tokens",
    details = "output_tokens_details"
  ),
  openai = c(
    input_tokens = "prompt_tokens",
    total_output_tokens = "completion_tokens",
    details = "completion_tokens_details"
  )
)

#' Read the reply id and the token counts of an OpenResponses or chat
#' completions reply
#'
#' As with `native_reply_fields()`, these values are extra to the answer, so
#' a value of the wrong type gives `NA` and never fails the input. Fields are
#' read with `[[`, because `$` would read a field whose name only starts with
#' the one asked for.
#'
#' @param resp_data The parsed response body.
#' @param api_type `"openresponses"` or `"openai"`.
#' @return A list with `response_id`, one string or `NA_character_`, and
#'   `input_tokens`, `total_output_tokens`, and `reasoning_output_tokens`,
#'   each one double or `NA_real_`.
#'
#' @noRd
usage_reply_fields <- function(resp_data, api_type) {
  names_in <- usage_field_names[[api_type]]
  usage <- object_or_empty(resp_data[["usage"]])
  details <- object_or_empty(usage[[names_in[["details"]]]])
  list(
    response_id = string_or_na(resp_data[["id"]]),
    input_tokens = number_or_na(usage[[names_in[["input_tokens"]]]]),
    total_output_tokens = number_or_na(usage[[names_in[["total_output_tokens"]]]]),
    reasoning_output_tokens = number_or_na(details[["reasoning_tokens"]])
  )
}

# The reply columns of a data-frame batch on each route, in column order.
# `response_id` is character, and the others are double.
reply_columns <- list(
  native = c("response_id", native_stats_fields),
  openresponses = c(
    "response_id",
    "input_tokens",
    "total_output_tokens",
    "reasoning_output_tokens"
  )
)
reply_columns$openai <- reply_columns$openresponses

#' Batch Chat Completion with LM Studio
#'
#' Process a vector of inputs sequentially through LM Studio.
#'
#' @param model Character. The loaded model name. Must be one name, given as a
#'   single string.
#' @param inputs Character vector. The prompts to process. Must hold at least
#'   one value and no missing values.
#' @param system_prompt Character. Optional system prompt.
#' @param format Character. Output format: "vector", "list", or "data.frame".
#' @param host Character. Server URL.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param simplify Logical. If TRUE, parses outputs.
#' @param quiet Logical. Whether to suppress the progress bar.
#' @param ... Additional arguments passed to `lms_chat`, such as `api_type`,
#'   `logprobs`, or `schema`. A `schema` and the `api_type` it needs are
#'   checked before the first call.
#' @return The return type depends on the \code{format} argument:
#' \itemize{
#'   \item \code{"vector"}: A character vector of responses, with \code{NA} for an input that failed. This format is only supported if \code{simplify = TRUE} and \code{logprobs = FALSE}. With a \code{schema}, it warns and returns the list instead.
#'   \item \code{"list"}: A list where each element is the response corresponding to the provided input, or the condition for an input that failed. With a \code{schema}, \code{simplify = TRUE}, and \code{logprobs = FALSE}, each element that did not fail is the parsed reply.
#'   \item \code{"data.frame"}: A data.frame containing \code{input} and \code{output} columns, with \code{NA} in \code{output} for an input that failed. If \code{logprobs = TRUE}, an additional list-column named \code{logprobs} is included, with \code{NULL} for an input that failed. With a \code{schema} and \code{logprobs = FALSE}, \code{output} is a list-column of parsed replies, with the condition in place of an input that failed. With \code{api_type = "native"}, seven more columns follow, described below.
#' }
#'
#' With `api_type = "native"` and `format = "data.frame"`, the data frame ends
#' with seven columns read from each reply: `response_id`, `input_tokens`,
#' `total_output_tokens`, `reasoning_output_tokens`, `tokens_per_second`,
#' `time_to_first_token_seconds`, and `model_load_time_seconds`.
#' `response_id` is character, and it identifies the reply on the server. The
#' other six are double, and they come from the `stats` object of the reply.
#' A cell is `NA` when its field is absent or is not one value of the column
#' type, a string for `response_id` and a number for the others. An empty
#' string is a string, so an empty `response_id` is kept. If `stats` is absent
#' or is not a JSON object, all six stats cells are `NA`. The server can leave
#' a field out, such as `model_load_time_seconds`. Such a cell does not fail
#' the input and gives no warning.
#'
#' A reply with no readable answer text fails its input, whatever its `stats`
#' and `response_id` hold. The row of an input that failed holds `NA` in all
#' seven columns. If every input failed, the seven columns are still there,
#' `response_id` as character and the other six as double. The other routes
#' and formats add no such column.
#' @details
#' This function calls [lms_chat()] once for each element of `inputs`. It
#' raises `rlmstudio_no_server` itself, before the first call.
#'
#' An `rlmstudio_api_error` or an `rlmstudio_bad_response` that [lms_chat()]
#' raises for one input does not abort the batch. The batch goes on to the
#' next input. Where the result is a list, or the `output` list-column that a
#' `schema` gives, the element for that input holds the condition without its
#' backtrace. An `rlmstudio_bad_response` for a reply that does not parse
#' keeps the reply content in its `content` field. Where the result is text,
#' the element holds `NA`. The result is text with `format = "vector"` when it
#' returns a vector (`simplify = TRUE`, no `schema`, `logprobs = FALSE`), and
#' with a data frame whose replies are not parsed (no `schema`, or
#' `logprobs = TRUE`). The `logprobs` column holds `NULL` for a failed input.
#' A reply with no readable answer text, such as one whose content is `null`,
#' fails as an `rlmstudio_bad_response` in the same way. Use `format = "list"`
#' to keep the conditions. The call gives one warning that names the count
#' and the positions of the failed inputs. That warning shows even with
#' `quiet = TRUE`.
#'
#' An `rlmstudio_no_server` from [lms_chat()] still aborts the batch. Its
#' `results` field holds the results so far, as described in the "Server not
#' running" section below. An error of any other class aborts the batch
#' unchanged.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @export
lms_chat_batch <- function(
  model,
  inputs,
  system_prompt = NULL,
  format = c("vector", "list", "data.frame"),
  host = "http://localhost:1234",
  simplify = TRUE,
  quiet = FALSE,
  ...,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_text(inputs, "inputs")

  # `lms_chat()` checks `schema` too, but only after the server probe below
  # has run. Checking here keeps an argument fault ahead of it (D-008). `[[`
  # rather than `$`, because `$` would match a longer name that starts with
  # `schema`, such as `schemas`. The names are first matched as `lms_chat()`
  # will match them, so a shortened `api = "openai"` counts here too.
  args <- rlm_chat_dots(list(...))
  schema <- args[["schema"]]
  rlm_check_schema(schema, names(args))
  api_type <- args[["api_type"]]
  if (is.null(api_type)) {
    api_type <- "openresponses"
  }
  api_type <- match.arg(api_type, c("openresponses", "openai", "native"))
  rlm_check_schema_route(schema, api_type)

  # An argument fault, so it aborts before the server probe (D-008) and before
  # any request is sent.
  format <- match.arg(format)
  if (format == "data.frame" && !isTRUE(simplify)) {
    cli::cli_abort(
      "The {.val data.frame} format requires {.code simplify = TRUE}.",
      call = NULL
    )
  }

  stop_if_no_server(host)

  has_logprobs <- isTRUE(args[["logprobs"]])
  # Each result is a parsed reply of any shape, not one string.
  has_parsed <- !is.null(schema) && isTRUE(simplify) && !has_logprobs
  should_be_quiet <- is_quiet(quiet)

  if (!should_be_quiet) {
    pb <- cli::cli_progress_bar(
      name = "Batch processing",
      total = length(inputs),
      format = "{cli::pb_name} {cli::pb_bar} {cli::pb_percent} | ETA: {cli::pb_eta}"
    )
    on.exit(cli::cli_progress_done(id = pb), add = TRUE)
  }

  # A failed input loses its own answer, not the whole batch. Its slot keeps
  # the condition, and an `rlmstudio_bad_response` carries the reply content.
  # Every other error still aborts, because it says nothing about one input
  # alone. The backtrace is dropped, because it makes each failed slot large
  # and says nothing about the input.
  keep_failure <- function(cnd) {
    cnd$trace <- NULL
    cnd
  }
  # A lost server fails every later input, so it still aborts (GP3). The
  # condition carries the results so far, so a long batch does not lose them.
  # Slots from the lost input on stay NULL.
  results <- vector("list", length(inputs))
  names(results) <- names(inputs)
  # A data frame also returns the reply id and the token counts of each reply
  # (D-013, D-014), so it asks for the body and reads the answer out of it
  # here. The answer is read by the helper the single call uses, so a reply
  # fails the same way. `results` still holds what `simplify = TRUE` returns,
  # so the `results` field of a lost-server abort does not change.
  body_frame <- format == "data.frame"
  reply_fields <- vector("list", length(inputs))
  # The single calls return the body only for status 200, so the abort a bad
  # body raises carries that status.
  ok_resp <- httr2::response(status_code = 200L)
  read_reply <- function(body) {
    value <- switch(
      api_type,
      native = native_reply_text(ok_resp, body),
      openresponses = responses_reply_value(ok_resp, body, has_logprobs),
      openai = openai_reply_value(ok_resp, body, has_logprobs, schema)
    )
    # Read after the answer, so a reply that fails leaves no values.
    fields <- if (api_type == "native") {
      native_reply_fields(body)
    } else {
      usage_reply_fields(body, api_type)
    }
    list(value = value, fields = fields)
  }
  for (i in seq_along(inputs)) {
    res <- tryCatch(
      if (body_frame) {
        body <- lms_chat(
          model = model,
          input = inputs[[i]],
          system_prompt = system_prompt,
          host = host,
          simplify = FALSE,
          ...,
          token = token
        )
        read <- read_reply(body)
        reply_fields[[i]] <- read$fields
        read$value
      } else {
        lms_chat(
          model = model,
          input = inputs[[i]],
          system_prompt = system_prompt,
          host = host,
          simplify = simplify,
          ...,
          token = token
        )
      },
      rlmstudio_api_error = keep_failure,
      rlmstudio_bad_response = keep_failure,
      rlmstudio_no_server = function(cnd) {
        cnd$results <- results
        stop(cnd)
      }
    )
    # `[i]` rather than `[[i]]`, so a NULL reply keeps its slot in the list.
    results[i] <- list(res)
    if (!should_be_quiet) {
      cli::cli_progress_update(id = pb)
    }
  }

  is_failed <- function(x) {
    inherits(x, c("rlmstudio_api_error", "rlmstudio_bad_response"))
  }
  failed <- which(vapply(results, is_failed, logical(1)))

  # Why the vector format returns a list, where it cannot hold the results.
  # A scalar parsed reply would fit a vector, but a batch can mix reply
  # shapes, and a vector that depends on what the model returned is not one a
  # script can rely on (GP2).
  vector_fallback <- NULL
  if (format == "vector") {
    if (!isTRUE(simplify)) {
      vector_fallback <- "The {.val vector} format is not compatible with simplify = FALSE. Returning list."
    } else if (has_parsed) {
      vector_fallback <- "The {.val vector} format cannot store replies parsed from {.arg schema}. Returning list."
    } else if (has_logprobs) {
      vector_fallback <- "The {.val vector} format cannot store logprobs dataframes. Returning list."
    }
  }
  # Where the result is text, a failed slot holds NA rather than the
  # condition, so the result type does not depend on what failed (GP2).
  holds_na <- isTRUE(simplify) &&
    !has_parsed &&
    (format == "data.frame" || (format == "vector" && is.null(vector_fallback)))
  # A reply with `"content": null` now fails (D-012), so no text reply is NULL
  # with `simplify = TRUE`. A NULL would still become NA here, so the text
  # result stays as long as `inputs`.
  na_if_failed <- function(x) {
    if (is.null(x) || is_failed(x)) NA_character_ else x
  }

  if (length(failed) > 0L) {
    # Shown whatever `quiet` says, because it is the only signal that some
    # answers are missing (D-010, D-011). The positions are joined here,
    # because cli shortens a vector of more than 20 values and would drop
    # some of them.
    positions <- cli::ansi_collapse(failed, trunc = Inf)
    msg <- "{length(failed)} input{?s} failed, at {cli::qty(length(failed))}position{?s} {positions}."
    if (holds_na) {
      msg <- c(
        msg,
        "i" = "Each of those elements holds {.code NA}. Use {.code format = \"list\"} to keep the conditions."
      )
    } else {
      msg <- c(
        msg,
        "i" = "Each of those elements holds the {.cls rlmstudio_api_error} or {.cls rlmstudio_bad_response} condition. A {.cls rlmstudio_bad_response} keeps any reply content in its {.field content} field."
      )
    }
    # One warning is enough, so a vector batch that returns a list says why
    # here rather than in a second warning.
    if (!is.null(vector_fallback)) {
      msg <- c(msg, "i" = vector_fallback)
    }
    cli::cli_warn(msg)
  } else if (!is.null(vector_fallback)) {
    cli::cli_warn(vector_fallback)
  }

  # Keyed on the route, not on the replies, so the columns and their types
  # are there even when every input failed. A failed input has no values.
  add_reply_columns <- function(df) {
    columns <- reply_columns[[api_type]]
    df$response_id <- vapply(
      reply_fields,
      \(x) if (is.null(x)) NA_character_ else x[["response_id"]],
      character(1)
    )
    for (field in columns[-1]) {
      df[[field]] <- vapply(
        reply_fields,
        \(x) if (is.null(x)) NA_real_ else x[[field]],
        double(1)
      )
    }
    df
  }

  if (format == "data.frame") {
    if (has_parsed) {
      df <- data.frame(input = inputs, stringsAsFactors = FALSE)
      df$output <- results
      return(add_reply_columns(df))
    }

    # Keyed on the argument, not on the results, so the column is there even
    # when every input failed (GP2).
    if (has_logprobs) {
      df <- data.frame(
        input = inputs,
        output = vapply(
          results,
          function(x) {
            if (inherits(x, "lms_chat_result")) x$text else na_if_failed(x)
          },
          character(1)
        ),
        stringsAsFactors = FALSE
      )
      # Add the logprobs as a list-column. A failed input has none.
      df$logprobs <- lapply(results, function(x) {
        if (inherits(x, "lms_chat_result")) x$logprobs else NULL
      })
    } else {
      df <- data.frame(
        input = inputs,
        output = unlist(lapply(results, na_if_failed)),
        stringsAsFactors = FALSE
      )
    }
    return(add_reply_columns(df))
  }

  if (format == "vector" && is.null(vector_fallback)) {
    return(unlist(lapply(results, na_if_failed)))
  }

  results
}

#' Name the dots of lms_chat_batch() as lms_chat() will match them
#'
#' `lms_chat_batch()` passes its `...` on to `lms_chat()`, whose `api_type` and
#' `logprobs` come before its own `...` and so match a shortened name. This
#' runs R's own argument matching over the same call, so `api` comes back as
#' `api_type`. The arguments that `lms_chat_batch()` passes by name are
#' matched first and then dropped, as in the real call.
#'
#' @param dots The list of `...` values.
#' @return `dots`, with each name replaced by the `lms_chat()` argument it
#'   matches.
#' @noRd
rlm_chat_dots <- function(dots) {
  fixed <- c("model", "input", "system_prompt", "host", "simplify", "token")
  placeholders <- vector("list", length(fixed))
  names(placeholders) <- fixed
  call <- as.call(c(list(quote(lms_chat)), placeholders, dots))
  matched <- as.list(match.call(lms_chat, call))[-1]
  matched[setdiff(names(matched), fixed)]
}

#' Create a base request for the LM Studio API
#'
#' @param host Character. The host address of the local server.
#'   Defaults to "http://localhost:1234".
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` falls through to the `rlmstudio.token` option and
#'   then to the `RLMSTUDIO_API_TOKEN` environment variable. When a token
#'   resolves, the request carries it as a bearer token in the `Authorization`
#'   header, which httr2 prints as `<REDACTED>`.
#'
#' @return An httr2 request object.
#'
#' @noRd
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#'
#' req <- lms_client("http://localhost:1234")
#' # req is a base httr2 request object that can be further modified
#' }
lms_client <- function(host = "http://localhost:1234", token = NULL) {
  req <- httr2::request(host) |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "Accept" = "application/json"
    )

  resolved <- rlm_token(token)
  if (is.null(resolved)) {
    return(req)
  }

  httr2::req_auth_bearer_token(req, resolved)
}
