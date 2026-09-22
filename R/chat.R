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
#' With a `schema`, it can raise `rlmstudio_bad_response` through
#' [lms_chat_openai()].
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
#'   response. Otherwise, returns a character string containing the generated
#'   text. If \code{logprobs = TRUE}, returns an object of class
#'   \code{lms_chat_result} incorporating both the text and probability data.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
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

    content <- resp_data$output[[1]]$content[[1]]

    if (
      isTRUE(logprobs) &&
        !is.null(content$logprobs) &&
        length(content$logprobs) > 0
    ) {
      logprobs_df <- do.call(
        rbind,
        lapply(content$logprobs, function(step) {
          step_tok <- if (is.null(step$token)) NA_character_ else step$token
          step_lp <- if (is.null(step$logprob)) NA_real_ else step$logprob

          if (is.null(step$top_logprobs) || length(step$top_logprobs) == 0) {
            return(data.frame(
              step_token = step_tok,
              step_logprob = step_lp,
              candidate_token = NA_character_,
              candidate_logprob = NA_real_,
              stringsAsFactors = FALSE
            ))
          }

          do.call(
            rbind,
            lapply(step$top_logprobs, function(cand) {
              data.frame(
                step_token = step_tok,
                step_logprob = step_lp,
                candidate_token = if (is.null(cand$token)) {
                  NA_character_
                } else {
                  cand$token
                },
                candidate_logprob = if (is.null(cand$logprob)) {
                  NA_real_
                } else {
                  cand$logprob
                },
                stringsAsFactors = FALSE
              )
            })
          )
        })
      )
      rownames(logprobs_df) <- NULL

      # Use S3 Constructor and Validator
      return(validate_lms_chat_result(
        new_lms_chat_result(text = content$text, logprobs = logprobs_df)
      ))
    }

    return(content$text)
  }

  rlm_abort_api(resp, "OpenResponses Failed", !is.null(rlm_token(token)))
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
#'   currently stubbed in the LM Studio OpenAI endpoint.
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

    # A 200 with no reply in it would otherwise fail on the `[[1]]` below with
    # a subscript error that names neither the response nor the field.
    choices <- resp_data$choices
    if (!is.list(choices) || length(choices) == 0L) {
      rlm_abort_bad_response(
        resp,
        "OpenAI API Failed",
        "The response holds no reply in its `choices` field.",
        content = NULL,
        finish_reason = NULL
      )
    }
    res_text <- choices[[1]]$message$content

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
        finish_reason = choices[[1]]$finish_reason
      ))
    }
    return(res_text)
  }

  rlm_abort_api(resp, "OpenAI API Failed", !is.null(rlm_token(token)))
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
    if (identical(finish_reason, "length")) {
      detail <- paste(
        "The token limit cut the reply off before it was complete.",
        "Raise `max_tokens` to allow a longer reply."
      )
    }
    # The detail is inserted into the message as text, so cli markup in it
    # would print as written. The hint below is a template of its own.
    rlm_abort_bad_response(
      resp,
      label,
      detail,
      hint = paste(
        "The reply text is in the {.field content} field of the condition,",
        "and the finish reason is in its {.field finish_reason} field."
      ),
      content = content,
      finish_reason = finish_reason
    )
  }

  if (!is.character(content) || length(content) != 1L || is.na(content)) {
    abort_unread("The reply content is not one string.")
  }
  tryCatch(
    jsonlite::parse_json(content, simplifyVector = TRUE),
    error = function(cnd) abort_unread("The reply content is not valid JSON.")
  )
}

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
#'   response. If \code{simplify = TRUE}, returns a character string containing
#'   the model's text output.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
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
    return(resp_data$output[[1]]$content)
  }

  rlm_abort_api(resp, "Native API Failed", !is.null(rlm_token(token)))
}

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
#'   \item \code{"vector"}: A character vector of responses. This format is only supported if \code{simplify = TRUE} and \code{logprobs = FALSE}. With a \code{schema}, it warns and returns the list instead.
#'   \item \code{"list"}: A list where each element is the response corresponding to the provided input. With a \code{schema}, \code{simplify = TRUE}, and \code{logprobs = FALSE}, each element is the parsed reply.
#'   \item \code{"data.frame"}: A data.frame containing \code{input} and \code{output} columns. If \code{logprobs = TRUE}, an additional list-column named \code{logprobs} is included. With a \code{schema} and \code{logprobs = FALSE}, \code{output} is a list-column of parsed replies.
#' }
#' @details
#' This function calls [lms_chat()] once for each element of `inputs`. It
#' raises `rlmstudio_no_server` itself, before the first call. It can raise
#' `rlmstudio_api_error` through [lms_chat()]. With a `schema`, it can raise
#' `rlmstudio_bad_response` through [lms_chat()].
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

  stop_if_no_server(host)
  format <- match.arg(format)

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

  results <- lapply(inputs, function(input) {
    call_chat <- function() {
      lms_chat(
        model = model,
        input = input,
        system_prompt = system_prompt,
        host = host,
        simplify = simplify,
        ...,
        token = token
      )
    }
    # A reply that does not parse loses one answer, not the whole batch. Its
    # slot keeps the condition, which carries the reply text. Every other
    # error still aborts, because it says nothing about one input alone.
    res <- if (has_parsed) {
      tryCatch(call_chat(), rlmstudio_bad_response = function(cnd) cnd)
    } else {
      call_chat()
    }
    if (!should_be_quiet) {
      cli::cli_progress_update(id = pb)
    }
    res
  })

  failed <- which(vapply(
    results,
    inherits,
    logical(1),
    "rlmstudio_bad_response"
  ))
  if (length(failed) > 0L) {
    # Shown whatever `quiet` says, because it is the only signal that some
    # answers are missing (D-010).
    cli::cli_warn(c(
      "Could not read the structured reply for {length(failed)} input{?s}, at position{?s} {failed}.",
      "i" = "Each of those elements holds the {.cls rlmstudio_bad_response} condition, with the reply text in its {.field content} field."
    ))
  }

  if (format == "data.frame") {
    if (!isTRUE(simplify)) {
      cli::cli_abort(
        "The {.val data.frame} format requires {.code simplify = TRUE}.",
        call = NULL
      )
    }

    if (has_parsed) {
      df <- data.frame(input = inputs, stringsAsFactors = FALSE)
      df$output <- results
      return(df)
    }

    any_logprobs <- any(vapply(
      results,
      inherits,
      logical(1),
      "lms_chat_result"
    ))

    if (any_logprobs) {
      df <- data.frame(
        input = inputs,
        output = vapply(
          results,
          function(x) if (inherits(x, "lms_chat_result")) x$text else x,
          character(1)
        ),
        stringsAsFactors = FALSE
      )
      # Add the logprobs as a list-column
      df$logprobs <- lapply(results, function(x) {
        if (inherits(x, "lms_chat_result")) x$logprobs else NULL
      })
      return(df)
    } else {
      return(data.frame(
        input = inputs,
        output = unlist(results),
        stringsAsFactors = FALSE
      ))
    }
  }

  if (format == "vector") {
    if (!isTRUE(simplify)) {
      cli::cli_warn(
        "The {.val vector} format is not compatible with simplify = FALSE. Returning list."
      )
      return(results)
    }
    if (has_parsed) {
      # A scalar reply would fit a vector, but a batch can mix reply shapes,
      # and a vector that depends on what the model returned is not one a
      # script can rely on (GP2). A batch with a failed reply has already
      # warned, and one warning is enough.
      if (length(failed) == 0L) {
        cli::cli_warn(
          "The {.val vector} format cannot store replies parsed from {.arg schema}. Returning list."
        )
      }
      return(results)
    }
    if (has_logprobs) {
      cli::cli_warn(
        "The {.val vector} format cannot store logprobs dataframes. Returning list."
      )
      return(results)
    }
    return(unlist(results))
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
