#' Reject a model or job name that is not one usable string
#'
#' The wrappers name `model` and `job_id` as arguments, so GP4 puts the input
#' check on the package rather than on the server. The check runs before the
#' server probe, because a fault in the argument is knowable without a server.
#'
#' @param value The value the caller passed.
#' @param arg Character. The argument name to report.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_id <- function(value, arg) {
  fault <- id_fault(value)
  if (!is.null(fault)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be one name, given as a single string.",
        "x" = "{fault}"
      ),
      call = NULL
    )
  }
  invisible(value)
}

#' Reject a wait that is not one usable number of seconds
#'
#' `lms_server_start(wait =)` names a number of seconds, so the check runs
#' before the CLI runs. A fault in the argument is knowable without starting
#' anything, and a start that has already run cannot be undone.
#'
#' @param value The value the caller passed.
#' @param arg Character. The argument name to report.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_wait <- function(value, arg = "wait") {
  fault <- wait_fault(value)
  if (!is.null(fault)) {
    cli::cli_abort(
      c(
        "{.arg {arg}} must be one number of seconds, zero or more.",
        "x" = "{fault}"
      ),
      call = NULL
    )
  }
  invisible(value)
}

#' Which rule did this wait break?
#'
#' Returns plain text rather than a cli string, for the reason `id_fault()`
#' states. `NaN` is reported as a missing value, because `is.na(NaN)` is
#' `TRUE` and the two are the same fault to a caller.
#'
#' @param value The value the caller passed.
#' @return A one-sentence detail, or `NULL` when the value is usable.
#'
#' @noRd
wait_fault <- function(value) {
  if (is.null(value)) {
    return("You gave NULL.")
  }
  # A bare `NA` is a logical, so this runs ahead of the type check. A caller
  # who wrote `wait = NA` is told about the missing value, not the type.
  if (is.atomic(value) && length(value) == 1L && is.na(value)) {
    return("You gave a missing value.")
  }
  if (!is.numeric(value)) {
    cls <- class(value)[[1]]
    return(paste0("You gave ", article_for(cls), " ", cls, " value."))
  }
  if (!is.null(dim(value))) {
    return("You gave an array rather than a single number.")
  }
  if (length(value) != 1L) {
    return(paste0("You gave ", length(value), " values rather than one."))
  }
  if (!is.finite(value)) {
    return("You gave a value that is not finite.")
  }
  if (value < 0) {
    return("You gave a negative number of seconds.")
  }
  NULL
}

#' Which rule did this model or job name break?
#'
#' Returns plain text rather than a cli string. The caller interpolates the
#' result as a value, so braces inside it are never read as a cli format
#' string (LESSONS, M012). The detail also names no value back to the user.
#'
#' @param value The value the caller passed.
#' @return A one-sentence detail, or `NULL` when the value is usable.
#'
#' @noRd
id_fault <- function(value) {
  if (is.null(value)) {
    return("You gave NULL.")
  }
  if (!is.character(value)) {
    cls <- class(value)[[1]]
    return(paste0("You gave ", article_for(cls), " ", cls, " value."))
  }
  if (!is.null(dim(value))) {
    return("You gave an array rather than a single string.")
  }
  if (length(value) != 1L) {
    return(paste0("You gave ", length(value), " values rather than one."))
  }
  if (is.na(value)) {
    return("You gave NA.")
  }
  if (!nzchar(value)) {
    return("You gave an empty string.")
  }
  # `trimws()` strips space, tab, carriage return, and line feed and nothing
  # else, so a form feed or a vertical tab survives it. The rule is stated
  # over the whole `[[:space:]]` class, so the test reads that class.
  if (!grepl("[^[:space:]]", value)) {
    return("You gave a string of whitespace only.")
  }
  NULL
}

#' The indefinite article that a class name takes
#'
#' @param word Character. One class name.
#' @return `"a"` or `"an"`.
#'
#' @noRd
article_for <- function(word) {
  if (grepl("^[aeiou]", word, ignore.case = TRUE)) "an" else "a"
}

#' Reject a ttl that is not one whole number of seconds in range
#'
#' LM Studio accepts a bad `ttl`, such as `"abc"` or `-5`, with no error and
#' keeps its default idle time, so GP4 puts the check on the package. The
#' upper bound is the largest R integer, because the value goes into the body
#' through `as.integer()`.
#'
#' @param value The value the caller passed as `ttl`.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_ttl <- function(value) {
  fault <- ttl_fault(value)
  if (!is.null(fault)) {
    # A cli brace that opens with a dot names a style, so the bound goes in
    # through a variable.
    max_ttl <- format(.Machine$integer.max)
    cli::cli_abort(
      c(
        "{.arg ttl} must be one whole number from 1 to {max_ttl}, or {.code NULL}.",
        "x" = "{fault}"
      ),
      call = NULL
    )
  }
  invisible(value)
}

#' Which rule did this ttl break?
#'
#' Returns plain text rather than a cli string, for the reason `id_fault()`
#' states.
#'
#' @param value The value the caller passed.
#' @return A one-sentence detail, or `NULL` when the value is usable.
#'
#' @noRd
ttl_fault <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  if (!is.numeric(value)) {
    cls <- class(value)[[1]]
    return(paste0("You gave ", article_for(cls), " ", cls, " value."))
  }
  if (length(value) != 1L) {
    return(paste0("You gave ", length(value), " values rather than one."))
  }
  if (is.na(value)) {
    return("You gave a missing value.")
  }
  if (!is.finite(value)) {
    return("You gave an infinite value.")
  }
  if (value != trunc(value)) {
    return("You gave a number that is not whole.")
  }
  if (value < 1 || value > .Machine$integer.max) {
    return(paste0("You gave ", format(value), ", which is out of range."))
  }
  NULL
}

#' Reject a ttl sent to a route whose endpoint does not honor one
#'
#' On 2026-09-27, LM Studio 0.4.25+1 honored `ttl` on `/v1/chat/completions`,
#' the `"openai"` route of `lms_chat()`. `/v1/responses` accepted it and kept
#' the default idle time, and `/api/v1/chat` rejected it with status 400.
#'
#' @param ttl The value the caller passed as `ttl`.
#' @param api_type Character. The route, already matched.
#' @return `ttl`, invisibly.
#'
#' @noRd
rlm_check_ttl_route <- function(ttl, api_type) {
  if (!is.null(ttl) && !identical(api_type, "openai")) {
    cli::cli_abort(
      c(
        "{.arg ttl} needs {.code api_type = \"openai\"}.",
        "x" = "You gave {.code api_type = {.str {api_type}}}.",
        "i" = "Of the LM Studio chat endpoints, only the OpenAI one honors a ttl."
      ),
      call = NULL
    )
  }
  invisible(ttl)
}

#' Reject a stream field that would make the server stream its reply
#'
#' The chat functions read one whole JSON reply. A `stream` of `TRUE` makes
#' the server send Server Sent Events, which fail as a bad response. The check
#' refuses any value other than `NULL` or one `FALSE`, as `isFALSE()` reads it,
#' so names or attributes on a `FALSE` pass (D-023). Every element named
#' `stream` is checked, so a later bad value is refused too, even though
#' `utils::modifyList()` sends only the first.
#'
#' @param dots The list of the caller's `...` values.
#' @return `dots`, invisibly.
#'
#' @noRd
rlm_check_stream <- function(dots) {
  nms <- names(dots)
  if (is.null(nms)) {
    return(invisible(dots))
  }
  for (value in dots[nms == "stream"]) {
    if (!is.null(value) && !isFALSE(value)) {
      # A long value is cut short, so the message stays one readable line.
      given <- deparse1(value)
      if (nchar(given) > 60L) {
        given <- paste0(substr(given, 1L, 57L), "...")
      }
      cli::cli_abort(
        c(
          "{.field stream} in {.arg ...} must be {.code FALSE} or {.code NULL}.",
          "x" = "You gave {.code {given}}.",
          "i" = "The chat functions read a whole reply, not a streamed one."
        ),
        call = NULL
      )
    }
  }
  invisible(dots)
}

#' Reject a schema that cannot be sent as a JSON object
#'
#' `schema` becomes the `schema` field of the `response_format` body, which
#' LM Studio reads as a JSON Schema object. jsonlite writes a named list as an
#' object and an unnamed list as an array, so the check is on the names. The
#' content of the schema is left to the server (D-003). A `response_format` in
#' `...` is refused alongside `schema`, because `utils::modifyList()` merges
#' the two field by field and sends a mix of both.
#'
#' @param value The value the caller passed as `schema`.
#' @param dot_names Character. The names of the caller's `...`.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_schema <- function(value, dot_names = character()) {
  fault <- schema_fault(value)
  if (!is.null(fault)) {
    cli::cli_abort(
      c(
        "{.arg schema} must be a named list, an empty list, or {.code NULL}.",
        "x" = "{fault}"
      ),
      call = NULL
    )
  }
  if (!is.null(value) && "response_format" %in% dot_names) {
    cli::cli_abort(
      "Give either {.arg schema} or a {.field response_format} in {.arg ...}, not both.",
      call = NULL
    )
  }
  invisible(value)
}

#' Which rule did this schema break?
#'
#' Returns plain text rather than a cli string, for the reason `id_fault()`
#' states.
#'
#' @param value The value the caller passed.
#' @return A one-sentence detail, or `NULL` when the value is usable.
#'
#' @noRd
schema_fault <- function(value) {
  if (is.null(value)) {
    return(NULL)
  }
  if (is.data.frame(value)) {
    return("You gave a data frame.")
  }
  if (!is.list(value)) {
    cls <- class(value)[[1]]
    return(paste0("You gave ", article_for(cls), " ", cls, " value."))
  }
  if (length(value) == 0L) {
    return(NULL)
  }
  nms <- names(value)
  if (is.null(nms) || anyNA(nms) || !all(nzchar(nms))) {
    return("You gave a list with at least one element that has no name.")
  }
  NULL
}

#' Reject a messages value that cannot be sent as a list of messages
#'
#' `messages` is a named argument of `lms_chat_openai()`, so GP4 puts the check
#' on the package, and it runs before the server probe (D-008). The check
#' reads the list and the names of each message. Roles, content, and every
#' other field inside a message stay with the server (D-003). A data frame
#' passes, because jsonlite writes it as one JSON object per row.
#'
#' @param value The value the caller passed as `messages`.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_messages <- function(value) {
  fault <- messages_fault(value)
  if (!is.null(fault)) {
    cli::cli_abort(
      c(
        "{.arg messages} must be a data frame or an unnamed list of messages.",
        "x" = "{fault}",
        "i" = "Each message is a named list, such as {.code list(role = \"user\", content = \"Hi\")}."
      ),
      call = NULL
    )
  }
  invisible(value)
}

#' Which rule did this messages value break?
#'
#' Returns plain text rather than a cli string, for the reason `id_fault()`
#' states. Each rule has one detail text. jsonlite writes a list with any
#' names attribute as a JSON object, even when every name is empty, so a list
#' with names is refused whatever the names are.
#'
#' @param value The value the caller passed.
#' @return A one-sentence detail, or `NULL` when the value is usable.
#'
#' @noRd
messages_fault <- function(value) {
  if (!is.list(value)) {
    return("You gave a value that is neither a list nor a data frame.")
  }
  if (is.data.frame(value)) {
    if (nrow(value) == 0L) {
      return("You gave no messages.")
    }
    return(NULL)
  }
  if (length(value) == 0L) {
    return("You gave no messages.")
  }
  if (!is.null(names(value))) {
    return("You gave a list with names, which is sent as one JSON object.")
  }
  for (message in value) {
    if (!is_named_message(message)) {
      return(
        "You gave a message that is not a list with a name on each field."
      )
    }
  }
  NULL
}

#' Is this one message a list with a usable name on each field?
#'
#' @param message One element of `messages`.
#' @return `TRUE` or `FALSE`.
#'
#' @noRd
is_named_message <- function(message) {
  if (!is.list(message) || length(message) == 0L) {
    return(FALSE)
  }
  nms <- names(message)
  !is.null(nms) && !anyNA(nms) && all(nzchar(nms))
}

#' Reject a schema sent to an endpoint that does not take one
#'
#' LM Studio documents structured output on `/v1/chat/completions` alone, which
#' is the `"openai"` route of `lms_chat()`.
#'
#' @param schema The value the caller passed as `schema`.
#' @param api_type Character. The route, already matched.
#' @return `schema`, invisibly.
#'
#' @noRd
rlm_check_schema_route <- function(schema, api_type) {
  if (!is.null(schema) && !identical(api_type, "openai")) {
    cli::cli_abort(
      c(
        "{.arg schema} needs {.code api_type = \"openai\"}.",
        "x" = "You gave {.code api_type = {.str {api_type}}}.",
        "i" = "LM Studio takes a JSON schema on its OpenAI chat endpoint only."
      ),
      call = NULL
    )
  }
  invisible(schema)
}

#' Reject a text argument that is not a usable character vector
#'
#' The strict rule, for the arguments that are genuinely vectors of text:
#' `lms_embed(input)` and `lms_chat_batch(inputs)`.
#'
#' @param value The value the caller passed.
#' @param arg Character. The argument name to report.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_text <- function(value, arg) {
  if (!is.character(value) || length(value) == 0) {
    cli::cli_abort(
      "{.arg {arg}} must be a non-empty character vector.",
      call = NULL
    )
  }
  rlm_check_no_na(value, arg)
}

#' Reject a missing value inside a text argument
#'
#' The loose rule, for the chat wrappers. Their `input` is a named formal, so
#' the dots escape hatch cannot reach it and a type check there would take the
#' structured OpenResponses input form away for good. This checks the character
#' case alone and lets every other shape through to the server.
#'
#' An `NA` reaches the server as JSON `null`, which no server error names back.
#'
#' @param value The value the caller passed.
#' @param arg Character. The argument name to report.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_no_na <- function(value, arg) {
  if (is.character(value) && anyNA(value)) {
    count <- sum(is.na(value))
    cli::cli_abort(
      c(
        "{.arg {arg}} must hold no missing values.",
        "x" = paste0(
          "You gave ",
          count,
          if (count == 1L) " NA value." else " NA values."
        )
      ),
      call = NULL
    )
  }
  invisible(value)
}
