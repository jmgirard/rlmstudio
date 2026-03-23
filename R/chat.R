#' Chat Completion with LM Studio
#'
#' Send a prompt to a locally running LM Studio model. This wrapper
#' automatically routes your request to the appropriate subfunction based on the
#' selected API type.
#'
#' @param model Character. The name of the loaded model.
#' @param input Character. The user prompt to send to the model.
#' @param system_prompt Character. An optional system prompt to guide model
#'   behavior.
#' @param host Character. The base URL of the LM Studio server. Default is
#'   "http://localhost:1234".
#' @param api_type Character. The LM Studio API endpoint to use. Options are
#'   "openresponses" (default), "openai", or "native".
#' @param logprobs Logical. Whether to return the log probabilities of the
#'   generated tokens. Default is FALSE.
#' @param simplify Logical. If TRUE, extracts the core text response. Default is
#'   TRUE.
#' @param ... Additional arguments passed to the selected API body.
#'
#' @export
lms_chat <- function(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  api_type = c("openresponses", "openai", "native"),
  logprobs = FALSE,
  simplify = TRUE,
  ...
) {
  api_type <- match.arg(api_type)

  if (api_type == "openresponses") {
    return(lms_chat_openresponses(
      model = model,
      input = input,
      instructions = system_prompt,
      host = host,
      logprobs = logprobs,
      simplify = simplify,
      ...
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
      ...
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
      ...
    ))
  }
}

#' Chat Completion via OpenResponses API
#'
#' Direct interface to LM Studio's OpenResponses endpoint. Supports logprobs and
#' custom instructions.
#'
#' @param model Character. The loaded model name.
#' @param input Character. The user prompt.
#' @param instructions Character. Optional system instructions.
#' @param host Character. Server URL.
#' @param logprobs Logical. Whether to return token probabilities.
#' @param simplify Logical. If TRUE, parses output to text and dataframe. If
#'   FALSE, returns raw list.
#' @param ... Additional API arguments (e.g., top_logprobs, temperature).
#'
#' @export
lms_chat_openresponses <- function(
  model,
  input,
  instructions = NULL,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...
) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      call = NULL
    )
  }

  body <- list(model = model, input = input, instructions = instructions)
  if (isTRUE(logprobs)) {
    body$include <- list("message.output_text.logprobs")
  }

  body <- Filter(Negate(is.null), body)
  body <- utils::modifyList(body, list(...))

  resp <- lms_client(host) |>
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

  err_msg <- tryCatch(
    {
      httr2::resp_body_json(resp)$error$message
    },
    error = function(e) ""
  )
  if (is.null(err_msg) || err_msg == "") {
    err_msg <- paste("HTTP Status", httr2::resp_status(resp))
  }
  cli::cli_abort(c("x" = "OpenResponses Failed: {err_msg}"), call = NULL)
}

#' Chat Completion via OpenAI Compatibility API
#'
#' Direct interface to LM Studio's OpenAI-compatible endpoint. Uses the messages
#' array format.
#'
#' @param model Character. The loaded model name.
#' @param messages List. A structured list of role and content pairs.
#' @param host Character. Server URL.
#' @param logprobs Logical. Whether to request logprobs (currently stubbed by LM
#'   Studio).
#' @param simplify Logical. If TRUE, parses output to text.
#' @param ... Additional API arguments.
#'
#' @export
lms_chat_openai <- function(
  model,
  messages,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...
) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      call = NULL
    )
  }

  body <- list(model = model, messages = messages)
  if (isTRUE(logprobs)) {
    body$logprobs <- TRUE
  }

  body <- Filter(Negate(is.null), body)
  body <- utils::modifyList(body, list(...))

  resp <- lms_client(host) |>
    httr2::req_url_path("v1/chat/completions") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) == 200) {
    resp_data <- httr2::resp_body_json(resp)
    if (!isTRUE(simplify)) {
      return(resp_data)
    }

    res_text <- resp_data$choices[[1]]$message$content

    if (isTRUE(logprobs)) {
      # Return S3 object with NULL logprobs (since OpenAI endpoint is a stub in LM Studio)
      return(validate_lms_chat_result(
        new_lms_chat_result(text = res_text, logprobs = NULL)
      ))
    }
    return(res_text)
  }

  err_msg <- tryCatch(
    {
      httr2::resp_body_json(resp)$error$message
    },
    error = function(e) ""
  )
  if (is.null(err_msg) || err_msg == "") {
    err_msg <- paste("HTTP Status", httr2::resp_status(resp))
  }
  cli::cli_abort(c("x" = "OpenAI API Failed: {err_msg}"), call = NULL)
}

#' Chat Completion via Native API
#'
#' Direct interface to LM Studio's v1 Native endpoint. Optimized for stateful chats and hardware control.
#'
#' @param model Character. The loaded model name.
#' @param input Character. The user prompt.
#' @param system_prompt Character. Optional system prompt.
#' @param host Character. Server URL.
#' @param simplify Logical. If TRUE, parses output to text.
#' @param ... Additional API arguments.
#' @export
lms_chat_native <- function(
  model,
  input,
  system_prompt = NULL,
  host = "http://localhost:1234",
  simplify = TRUE,
  ...
) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      call = NULL
    )
  }

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

  resp <- lms_client(host) |>
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

  err_msg <- tryCatch(
    {
      httr2::resp_body_json(resp)$error
    },
    error = function(e) ""
  )
  if (is.null(err_msg) || err_msg == "") {
    err_msg <- paste("HTTP Status", httr2::resp_status(resp))
  }
  cli::cli_abort(c("x" = "Native API Failed: {err_msg}"), call = NULL)
}

#' Batch Chat Completion with LM Studio
#'
#' Process a vector of inputs sequentially through LM Studio.
#'
#' @param model Character. The loaded model name.
#' @param inputs Character vector. The prompts to process.
#' @param system_prompt Character. Optional system prompt.
#' @param format Character. Output format: "vector", "list", or "data.frame".
#' @param host Character. Server URL.
#' @param simplify Logical. If TRUE, parses outputs.
#' @param quiet Logical. Whether to suppress the progress bar.
#' @param ... Additional arguments passed to `lms_chat`.
#'
#' @export
lms_chat_batch <- function(
  model,
  inputs,
  system_prompt = NULL,
  format = c("vector", "list", "data.frame"),
  host = "http://localhost:1234",
  simplify = TRUE,
  quiet = FALSE,
  ...
) {
  if (!is_server_running()) {
    cli::cli_abort(
      "The LM Studio server is not running. Run {.fn lms_server_start} first.",
      call = NULL
    )
  }
  format <- match.arg(format)

  if (!is.character(inputs) || length(inputs) == 0) {
    cli::cli_abort(
      "{.arg inputs} must be a non-empty character vector.",
      call = NULL
    )
  }

  args <- list(...)
  has_logprobs <- isTRUE(args$logprobs)
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
    res <- lms_chat(
      model = model,
      input = input,
      system_prompt = system_prompt,
      host = host,
      simplify = simplify,
      ...
    )
    if (!should_be_quiet) {
      cli::cli_progress_update(id = pb)
    }
    res
  })

  if (format == "data.frame") {
    if (!isTRUE(simplify)) {
      cli::cli_abort(
        "The {.val data.frame} format requires {.code simplify = TRUE}.",
        call = NULL
      )
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

#' Create a base request for the LM Studio API
#'
#' @param host Character. The host address of the local server. Defaults to "http://localhost:1234".
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
lms_client <- function(host = "http://localhost:1234") {
  httr2::request(host) |>
    httr2::req_headers(
      "Content-Type" = "application/json",
      "Accept" = "application/json"
    )
}
