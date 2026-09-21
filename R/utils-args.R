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
