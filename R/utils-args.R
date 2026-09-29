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

#' Check the batch size of a batched call
#'
#' The same range as `ttl`, for the same reason: the count is compared with
#' R integers and must be one whole number. Unlike `ttl`, it has no `NULL`
#' form, because every call sends at least one batch.
#'
#' @param value The value the caller passed as `batch_size`.
#' @return `value`, invisibly.
#'
#' @noRd
rlm_check_batch_size <- function(value) {
  fault <- if (is.null(value)) "You gave `NULL`." else ttl_fault(value)
  if (!is.null(fault)) {
    max_size <- format(.Machine$integer.max)
    cli::cli_abort(
      c(
        "{.arg batch_size} must be one whole number from 1 to {max_size}.",
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
#' on the package, and it runs before the server probe (D-008). The shape
#' rules read the shape of the value and the names at each level, and their
#' abort carries the named-list hint. Four value rules follow, under a header
#' of their own and with no hint: a function anywhere inside the value, a
#' value anywhere inside it that is not an atomic vector, a list, or `NULL`,
#' a number that jsonlite writes as a string or leaves out, and a trial write
#' that asks jsonlite to write it. The number rule refuses an `NA`, `NaN`,
#' `Inf`, or `-Inf` in a double or integer vector whose class attribute is
#' absent or is `"AsIs"`, because jsonlite writes it as a string. It skips a
#' number inside a classed list that jsonlite writes by its class, such as a
#' `POSIXlt`. In an atomic
#' column with no `dim` attribute, of a data frame at any depth, jsonlite
#' leaves such a cell out of the row. There the rule refuses `Inf` and `-Inf`
#' alone, and an `NA` or `NaN` cell is a missing field, as `empty_rows()`
#' reads it. Those four kinds are the only field values the package judges. The
#' server judges a role, a content value, and any other field value, as D-003
#' states for API fields. A data frame passes, because jsonlite writes it as
#' one JSON object per row.
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
  if (has_function(value)) {
    fault <- paste(
      "You gave a field value that is a function, which jsonlite would send",
      "as its source text."
    )
  } else {
    type <- non_vector_type(value)
    fault <- if (!is.null(type)) {
      paste0(
        "You gave a field value of type \"",
        type,
        "\", which is not an atomic vector, a list, or NULL."
      )
    } else if (has_unsendable_number(value)) {
      paste(
        "You gave a number that is NA, NaN, or infinite, which jsonlite would",
        "send as a string or leave out."
      )
    } else {
      messages_write_fault(value)
    }
  }
  if (!is.null(fault)) {
    cli::cli_abort(
      c(
        "{.arg messages} holds a field value that cannot be sent as JSON.",
        "x" = "{fault}"
      ),
      call = NULL
    )
  }
  invisible(value)
}

#' Can jsonlite write this messages value?
#'
#' The request body is written by `rlm_json_text()` after the server probe.
#' A value that jsonlite cannot write, such as a field with a class that has
#' no jsonlite method, would fail there with an error that does not name
#' `messages`. So the value is written once here by the same function. The
#' trial write and the sent body go through one helper with the same
#' options, so a `messages` value that passes the trial write is sent as
#' jsonlite writes it. The jsonlite message is returned as a value, and the
#' abort splices it in, so cli does not read its braces.
#'
#' @param value A `messages` value that passed `messages_fault()` and holds
#'   no function.
#' @return A detail that holds the jsonlite message, or `NULL` when the write
#'   works.
#'
#' @noRd
messages_write_fault <- function(value) {
  tryCatch(
    {
      rlm_json_text(unclass_messages(value))
      NULL
    },
    error = function(e) {
      paste("You gave a value that jsonlite cannot write:", conditionMessage(e))
    }
  )
}

#' Does a function sit anywhere inside this messages value?
#'
#' jsonlite writes a function as an array of its source lines, with no error,
#' so the trial write does not catch one. The walk goes down every list, and a
#' data frame is a list of its columns, so it reads each column, each cell of
#' a list or list-matrix column, and each nested data frame. A `for` loop
#' reads the elements as stored, for the reason `any_holds_list_array()`
#' states.
#'
#' @param value A `messages` value that passed `messages_fault()`.
#' @return `TRUE` when the walk reaches a function.
#'
#' @noRd
has_function <- function(value) {
  if (is.function(value)) {
    return(TRUE)
  }
  if (!is.list(value)) {
    return(FALSE)
  }
  for (element in value) {
    if (has_function(element)) {
      return(TRUE)
    }
  }
  FALSE
}

#' Which value inside this messages value is not a vector, a list, or NULL?
#'
#' jsonlite has a method for a vector, a list, or a data frame alone. It
#' writes any other value by its class attribute: as printed text, as `null`,
#' as an object or array of other data, such as the slots of a class
#' definition, or not at all. So a class set by hand on an environment or a call can make
#' the trial write pass and send junk. The rule reads the storage type, which
#' a class does not change. `is.null()` is read on its own, because
#' `is.atomic(NULL)` is `FALSE` from R 4.4.0. The walk is the walk of
#' `has_function()`, which runs first, so a function never reaches this rule.
#'
#' @param value A `messages` value that passed `messages_fault()` and holds
#'   no function.
#' @return The `typeof()` of the first such value the walk reaches, or `NULL`
#'   when there is none.
#'
#' @noRd
non_vector_type <- function(value) {
  if (is.list(value)) {
    for (element in value) {
      type <- non_vector_type(element)
      if (!is.null(type)) {
        return(type)
      }
    }
    return(NULL)
  }
  if (is.atomic(value) || is.null(value) || is.function(value)) {
    return(NULL)
  }
  typeof(value)
}

#' Does this messages value hold a number jsonlite cannot send as a number?
#'
#' jsonlite writes an `NA`, `NaN`, `Inf`, or `-Inf` in a double or integer
#' vector as the string `"NA"`, `"NaN"`, `"Inf"`, or `"-Inf"`. In an atomic
#' column with no `dim` attribute, of a data frame at any depth, it leaves
#' such a cell out of the row instead. There the rule reads `Inf` and `-Inf`
#' alone, because an `NA` or `NaN` cell is a missing field, as
#' `empty_rows()` reads it. The rule reads a number whose class attribute is
#' absent or is `"AsIs"`. A number with another class, such as a `Date`, is
#' written by that class and passes. The non-vector rule runs first, so each
#' value the walk reaches is an atomic vector, a list, or `NULL`. It starts from the value that
#' `unclass_messages()` returns, which is the value sent. Below the messages,
#' it goes into a list whose class is not `"AsIs"` or a data frame only when
#' `written_as_list()` finds that jsonlite writes it as a plain list. A
#' `POSIXlt` in a zone with a name holds an integer `NA` in its `gmtoff` part,
#' and jsonlite writes it as a date and time, so the walk does not go into it.
#'
#' @param value A `messages` value that passed the function rule and the
#'   non-vector rule.
#' @return `TRUE` when the walk reaches such a number.
#'
#' @noRd
has_unsendable_number <- function(value) {
  unclassed <- unclass_messages(value)
  if (is.data.frame(unclassed)) {
    return(is_or_holds_unsendable_number(unclassed))
  }
  for (message in unclassed) {
    for (field in message) {
      if (is_or_holds_unsendable_number(field)) {
        return(TRUE)
      }
    }
  }
  FALSE
}

#' The walk behind `has_unsendable_number()`, from one value in a message
#'
#' @param value Any value found inside a message, or a data frame.
#' @return `TRUE` when `value` is, or holds, such a number.
#'
#' @noRd
is_or_holds_unsendable_number <- function(value) {
  if (is.data.frame(value)) {
    for (column in value) {
      if (is.atomic(column) && is.null(attr(column, "dim", exact = TRUE))) {
        if (is_plain_number(column) && any(is.infinite(column))) {
          return(TRUE)
        }
      } else if (is_or_holds_unsendable_number(column)) {
        return(TRUE)
      }
    }
    return(FALSE)
  }
  if (is.list(value)) {
    value_class <- oldClass(value)
    if (
      !is.null(value_class) &&
        !identical(value_class, "AsIs") &&
        !written_as_list(value)
    ) {
      return(FALSE)
    }
    for (element in value) {
      if (is_or_holds_unsendable_number(element)) {
        return(TRUE)
      }
    }
    return(FALSE)
  }
  is_plain_number(value) && !all(is.finite(value))
}

#' Does jsonlite write this classed list as it writes the bare list?
#'
#' jsonlite writes a `POSIXlt` as a date and time, but it writes a list with
#' the class `c("foo", "list")` as a plain list, so a number inside it is
#' written as a string. The two writes use `rlm_json_text()`, as the
#' sent body does. A write that fails returns `FALSE`, and the trial write
#' refuses the value later.
#'
#' @param value A list with a class attribute.
#' @return `TRUE` when both writes give the same text.
#'
#' @noRd
written_as_list <- function(value) {
  tryCatch(
    identical(rlm_json_text(value), rlm_json_text(unclass(value))),
    error = function(e) FALSE
  )
}

#' Is this a double or integer vector with no class but `"AsIs"`?
#'
#' `oldClass()` reads the class attribute alone, so a matrix passes.
#'
#' @param value Any value.
#' @return `TRUE` or `FALSE`.
#'
#' @noRd
is_plain_number <- function(value) {
  (is.double(value) || is.integer(value)) &&
    (is.null(oldClass(value)) || identical(oldClass(value), "AsIs"))
}

#' Remove the class of a messages list and of each of its messages
#'
#' jsonlite has no method for most S3 classes, so a list with such a class
#' would fail after the server probe. The class goes from the outer list and
#' from each message alone. A class below them, such as `I()` on a field,
#' changes how jsonlite writes the field, so it stays. A data frame keeps its
#' class, because `unclass()` turns it into a list of columns. Run it after
#' `rlm_check_messages()`, which reads the value as the caller passed it.
#'
#' @param value A `messages` value that passed `rlm_check_messages()`.
#' @return `value` with those classes removed, or a data frame unchanged.
#'
#' @noRd
unclass_messages <- function(value) {
  if (is.data.frame(value)) {
    return(value)
  }
  lapply(unclass(value), unclass)
}

#' Which rule did this messages value break?
#'
#' Returns plain text rather than a cli string, for the reason `id_fault()`
#' states. Each rule has one detail text. jsonlite writes a list with any
#' names attribute as a JSON object, even when every name is empty, so a list
#' with names is refused whatever the names are.
#'
#' `unclass_messages()` runs `lapply()`, which drops a `dim` attribute, so a
#' list-matrix would be sent flat in column order. A message with a `dim` is
#' written with each field boxed in an array. Each `dim` rule runs before the
#' names rule at its level, because `names()` reads the dimnames of a
#' one-dimensional list array.
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
    return(data_frame_messages_fault(value))
  }
  if (length(value) == 0L) {
    return("You gave no messages.")
  }
  if (!is.null(dim(value))) {
    return(
      "You gave a list with a dim attribute, such as a matrix of messages."
    )
  }
  if (!is.null(names(value))) {
    return("You gave a list with names, which is sent as one JSON object.")
  }
  for (message in value) {
    if (
      is.list(message) && !is.data.frame(message) && !is.null(dim(message))
    ) {
      return("You gave a message with a dim attribute, such as a list array.")
    }
    if (!is_named_message(message)) {
      return(
        "You gave a message that is not a list with a name on each field."
      )
    }
  }
  if (has_inner_list_array(value)) {
    return(inner_list_array_detail)
  }
  nested_names_fault(value)
}

inner_list_array_detail <- paste(
  "You gave a list with a dim attribute inside a message, such as a",
  "list-matrix field."
)

#' Is there a list with a dim attribute inside a message?
#'
#' jsonlite writes such a list as nested arrays with each cell boxed, such as
#' `[[[1],[3]],[[2],[4]]]` for a two-by-two list-matrix. The walk starts at the
#' messages, whose own `dim` the rules before it read, and goes down every
#' list. It reads the attribute and not `dim()`, because `dim()` of a data
#' frame is not `NULL`. A data frame is walked column by column. Its
#' list-matrix column is sent one row of cells per message, so that column
#' passes and its cells are read. A list column with one, three, or more
#' dimensions is refused.
#'
#' @param value A list of messages, or a data frame.
#' @return `TRUE` when the walk reaches a list with a `dim` attribute.
#'
#' @noRd
has_inner_list_array <- function(value) {
  if (is.data.frame(value)) {
    for (column in value) {
      if (is.data.frame(column)) {
        if (has_inner_list_array(column)) {
          return(TRUE)
        }
      } else if (is.list(column)) {
        column_dim <- attr(column, "dim", exact = TRUE)
        if (!is.null(column_dim) && length(column_dim) != 2L) {
          return(TRUE)
        }
        if (any_holds_list_array(column)) {
          return(TRUE)
        }
      }
    }
    return(FALSE)
  }
  for (message in value) {
    if (any_holds_list_array(message)) {
      return(TRUE)
    }
  }
  FALSE
}

#' Does any element of this list hold a list with a dim attribute?
#'
#' A `for` loop reads the elements as stored. `vapply()` would call an
#' `as.list()` method first. For a `POSIXlt` of length one, that method
#' returns a list that holds the same `POSIXlt` again.
#'
#' @param value A list.
#' @return `TRUE` when `is_or_holds_list_array()` is `TRUE` for an element.
#'
#' @noRd
any_holds_list_array <- function(value) {
  for (element in value) {
    if (is_or_holds_list_array(element)) {
      return(TRUE)
    }
  }
  FALSE
}

#' The walk behind `has_inner_list_array()`, from one value inside a message
#'
#' @param value Any value found inside a message.
#' @return `TRUE` when `value` is, or holds, a list with a `dim` attribute.
#'
#' @noRd
is_or_holds_list_array <- function(value) {
  if (!is.list(value)) {
    return(FALSE)
  }
  if (is.data.frame(value)) {
    return(has_inner_list_array(value))
  }
  if (!is.null(attr(value, "dim", exact = TRUE))) {
    return(TRUE)
  }
  any_holds_list_array(value)
}

#' Does any object that jsonlite writes as an object have a bad name?
#'
#' jsonlite writes an `NA` or empty name under a number, and it renames a
#' repeated name `a` to `a.1`. The walk reads the names of each list and data
#' frame it reaches, from the value handed to it down. A list whose names
#' attribute is `NULL` is written as an array and has no names to read. A
#' list column of a data frame is written one cell per row, and its own names
#' are not written, so the walk reads its cells and not its names. Any other
#' value, such as an environment, ends the walk there. A value rule in
#' `rlm_check_messages()` reports such a value.
#'
#' @param value A list of messages, one message, or a data frame.
#' @return A one-sentence detail, or `NULL` when no name is bad.
#'
#' @noRd
nested_names_fault <- function(value) {
  if (has_bad_name(value)) {
    return(paste(
      "You gave a message, or a list or data frame inside one, with a name",
      "that is NA, empty, or repeated."
    ))
  }
  NULL
}

#' The walk behind `nested_names_fault()`
#'
#' @param value Any value found inside `messages`.
#' @return `TRUE` when the walk from `value` reaches a bad name.
#'
#' @noRd
has_bad_name <- function(value) {
  if (!is.list(value)) {
    return(FALSE)
  }
  nms <- names(value)
  if (
    !is.null(nms) && (anyNA(nms) || !all(nzchar(nms)) || anyDuplicated(nms))
  ) {
    return(TRUE)
  }
  if (is.data.frame(value)) {
    for (column in value) {
      cells <- if (is.list(column) && !is.data.frame(column)) {
        column
      } else {
        list(column)
      }
      for (cell in cells) {
        if (has_bad_name(cell)) {
          return(TRUE)
        }
      }
    }
    return(FALSE)
  }
  for (element in value) {
    if (has_bad_name(element)) {
      return(TRUE)
    }
  }
  FALSE
}

#' Which data-frame rule did this messages value break?
#'
#' jsonlite writes a data frame with no columns, or a row whose cells are all
#' `NA`, as an empty message. When list columns hold the `NA`, the message has
#' a `null` field for each list column. A matrix column is the exception: its
#' `NA` cells are written as an array, of `null` for a character matrix, but
#' such a row is refused all the same. A numeric matrix with such a row is
#' refused here too, before the number rule of `rlm_check_messages()`. That
#' rule refuses an `NA`, `NaN`, `Inf`, or `-Inf` in a double or integer vector
#' whose class attribute is absent or is `"AsIs"`, because jsonlite writes it
#' as a string. It skips a number inside a classed list that jsonlite writes
#' by its class, such as a `POSIXlt`. An `NA` or `NaN` cell of an atomic
#' column with no `dim` attribute passes, because jsonlite leaves that cell
#' out of the row, and such a cell counts toward an empty row here. jsonlite
#' writes a column named `NA` or `""` under a number, and it renames a
#' repeated column name with a suffix. The column rule runs first, because a
#' data frame with no columns also has rows in which every cell is `NA`.
#'
#' @param value A data frame with at least one row.
#' @return A one-sentence detail, or `NULL` when the value is usable.
#'
#' @noRd
data_frame_messages_fault <- function(value) {
  nms <- names(value)
  if (
    length(nms) == 0L || anyNA(nms) || !all(nzchar(nms)) || anyDuplicated(nms)
  ) {
    return(
      "You gave a data frame that has no columns or a column name that is missing or repeated."
    )
  }
  if (any(empty_rows(value))) {
    return(
      "You gave a data frame with a row in which every cell is NA or a NULL list cell."
    )
  }
  if (has_inner_list_array(value)) {
    return(inner_list_array_detail)
  }
  nested_names_fault(value)
}

#' Which rows of a messages data frame hold no field value?
#'
#' A cell is empty when `is.na()` says so, or when it is a `NULL` cell of a
#' list column. jsonlite leaves out an atomic `NA` cell and writes an `NA` or
#' `NULL` list cell as `null`. A `list()` cell is written as `[]` and a
#' `list(NA)` cell as `[null]`, which are field values, so neither is empty.
#' A column with a `dim` attribute whose first extent is the row count, a
#' list array included, counts as empty in a row when each cell whose first
#' index is that row is empty. `is.na()` keeps the `dim` of the column, so
#' `apply()` reads those cells for each row. A row of such a column that holds
#' no cells, because an extent after the first is zero, is not empty.
#' jsonlite writes it as `[]` or as nested empty arrays, and `apply()` would
#' call `all()` on no cells and return `TRUE`. jsonlite writes a character or
#' logical matrix row of `NA` as `null`, but the rule refuses the row, as it
#' did before `NULL` cells counted. It refuses a numeric one too, before the
#' number rule of `rlm_check_messages()` reads it. An `NA` or `NaN` cell of
#' an atomic column with no `dim` is empty here, and the number rule leaves
#' it alone, because jsonlite leaves it out of the row. A data-frame column
#' counts as empty in a row
#' when this rule finds that row of it empty, so a data-frame column with no
#' columns counts as empty in every row. A column that is neither an
#' atomic vector nor a list, such as a function, an environment, or a symbol,
#' is never empty and is not passed to `is.na()`, which warns on most such
#' columns. The
#' function rule or the non-vector rule refuses it later. The columns are read
#' one at a time, because `is.na()` on the whole data frame spreads a matrix
#' column over several.
#'
#' @param value A data frame.
#' @return A logical vector with one element per row of `value`.
#'
#' @noRd
empty_rows <- function(value) {
  empty <- rep(TRUE, nrow(value))
  for (column in value) {
    if (is.data.frame(column)) {
      column_empty <- empty_rows(column)
    } else if (!is.atomic(column) && !is.list(column)) {
      column_empty <- FALSE
    } else {
      cell_empty <- is.na(column)
      if (is.list(column)) {
        cell_empty[] <- cell_empty | vapply(column, is.null, logical(1))
      }
      column_dim <- dim(column)
      column_empty <- if (
        !is.null(column_dim) && column_dim[[1L]] == nrow(value)
      ) {
        if (prod(column_dim[-1L]) == 0) {
          rep(FALSE, nrow(value))
        } else {
          apply(cell_empty, 1L, all)
        }
      } else {
        cell_empty
      }
    }
    empty <- empty & column_empty
  }
  empty
}

#' Is this one message a list with a usable name on each field?
#'
#' A data frame is refused, because jsonlite writes it as an array of objects,
#' which nests an array inside `messages`.
#'
#' @param message One element of `messages`.
#' @return `TRUE` or `FALSE`.
#'
#' @noRd
is_named_message <- function(message) {
  if (
    !is.list(message) || is.data.frame(message) || length(message) == 0L
  ) {
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

#' Reject schema property names that cannot name a data-frame column
#'
#' A data-frame batch with an object schema adds one column per top-level
#' property (D-027). A name that is empty, `NA`, repeated, or equal to a
#' column the batch returns already cannot name its own column. The batch
#' aborts rather than rename or skip the column, because a renamed or missing
#' column gives no sign of the change.
#'
#' @param property_names Character or `NULL`. The property names from
#'   `schema_property_columns()`, or `NULL` when the batch adds no columns.
#' @return `property_names`, invisibly.
#'
#' @noRd
rlm_check_property_names <- function(property_names) {
  if (is.null(property_names)) {
    return(invisible(property_names))
  }
  taken <- c("input", "output", reply_columns$openai)
  repeated <- property_names[duplicated(property_names)]
  clashing <- intersect(property_names, taken)
  fault <- if (anyNA(property_names)) {
    "A property name is {.code NA}."
  } else if (any(property_names == "")) {
    "A property name is empty."
  } else if (length(repeated) > 0L) {
    "The property name {.val {repeated[[1]]}} is there more than once."
  } else if (length(clashing) > 0L) {
    "The property {.val {clashing[[1]]}} has the name of a column that the batch returns already."
  }
  if (!is.null(fault)) {
    cli::cli_abort(
      c(
        "Each top-level property of {.arg schema} must have a name that can name its own data-frame column.",
        "x" = fault,
        "i" = "Rename the property, or use {.code format = \"list\"}."
      ),
      call = NULL
    )
  }
  invisible(property_names)
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
