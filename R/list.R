#' List available models
#'
#' Retrieves a list of models available on your system via the LM Studio REST
#' API.
#'
#' @param loaded Logical. If \code{TRUE}, returns only currently loaded models.
#'   Defaults to \code{FALSE}.
#' @param type Character vector. The types of models to include. Defaults to
#'   \code{c("llm", "embedding")}.
#' @param detailed Logical. Show all information about each model. Defaults to
#'   \code{FALSE}.
#' @param quiet Logical. If \code{TRUE}, suppresses informative console
#'   messages. Defaults to \code{FALSE}. Does not suppress the abort raised
#'   when the server is not running.
#' @param host Character. The host address of the local server.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#'
#' @seealso [LM Studio List Models
#'   API](https://lmstudio.ai/docs/developer/rest/list)
#'
#' @return A \code{data.frame} containing information about the available
#' models. By default, it includes columns for \code{state}, \code{type},
#' \code{display_name}, \code{key}, \code{architecture}, and \code{size_gb}.
#' If \code{detailed = TRUE}, it returns a comprehensive \code{data.frame}
#' including all raw metadata columns provided by the API. Returns an empty
#' \code{data.frame} if no models match the criteria.
#'
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#' lms_download("google/gemma-3-1b")
#' lms_load("google/gemma-3-1b")
#'
#' # List all downloaded models
#' list_models()
#'
#' # List only currently loaded models
#' list_models(loaded = TRUE)
#'
#' # Get detailed information about loaded text models
#' list_models(loaded = TRUE, type = "llm", detailed = TRUE)
#' }
list_models <- function(
  loaded = FALSE,
  type = c("llm", "embedding"),
  detailed = FALSE,
  quiet = FALSE,
  host = "http://localhost:1234",
  token = NULL
) {
  stop_if_no_server(host)

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/models") |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200) {
    rlm_abort_api(resp, "API List Failed", !is.null(rlm_token(token)))
  }

  body <- parse_ok_body(resp, "API List Failed")
  fault <- model_list_fault(body)
  if (!is.null(fault)) {
    rlm_abort_bad_reply(resp, "API List Failed", fault, "a model list")
  }

  if (length(body[["models"]]) == 0) {
    if (!quiet) {
      rlm_inform(c("i" = "No models found on host {.url {host}}."))
    }
    return(invisible(data.frame()))
  }

  # The check above ran on the unsimplified parse, where every JSON type keeps
  # its own R form. Simplifying first would coerce a bad field in a later
  # entry to the type of the first entry, and the check could not see it.
  df <- parse_json_body(resp, simplifyVector = TRUE)[["models"]]

  # Apply type filters
  df <- df[df$type %in% type, , drop = FALSE]

  # Evaluate load state for all matching models
  if (nrow(df) > 0) {
    df$state <- ifelse(
      vapply(
        df$loaded_instances,
        function(x) {
          if (is.data.frame(x)) nrow(x) > 0 else length(x) > 0
        },
        logical(1)
      ),
      "loaded",
      "unloaded"
    )

    # Apply loaded filter
    if (isTRUE(loaded)) {
      df <- df[df$state == "loaded", , drop = FALSE]
    }
  }

  if (nrow(df) == 0) {
    if (!quiet) {
      rlm_inform(c(
        "!" = "No models found matching criteria: loaded = {.val {loaded}}, type = {.val {type}}."
      ))
    }
    return(invisible(data.frame()))
  }

  # Format size for readability
  if ("size_bytes" %in% names(df)) {
    df$size_gb <- round(df$size_bytes / (1024^3), 2)
  }

  # Clean up and select columns
  if (!isTRUE(detailed)) {
    core_cols <- c(
      "state",
      "type",
      "display_name",
      "key",
      "architecture",
      "size_gb"
    )
    available_cols <- intersect(core_cols, names(df))
    df <- df[, available_cols, drop = FALSE]
  }

  return(df)
}

#' Find the first way a model-list body breaks its shape rules
#'
#' The one check of a model-list body. `list_models()` aborts on what it
#' returns, and `lms_server_ready()` reports `FALSE` for it, so the two
#' functions accept the same bodies. The rules cover the fields that the
#' package reads from the list:
#'
#' 1. The body is a JSON object whose `models` is an array.
#' 2. Each entry of `models` is a JSON object. Its `type` and `key` are
#'    strings, and its `loaded_instances` is an array.
#' 3. The `size_bytes` of an entry is a number, or absent, or `null`.
#' 4. Each entry of `loaded_instances` is a JSON object whose `id` is a string
#'    with a character that is not whitespace.
#'
#' Fields are read with `[[`, which matches exact names only, so a field whose
#' name extends a rule's name, such as `keyX`, is not read in its place.
#'
#' @param body The body as `parse_json_body()` returns it with
#'   `simplifyVector = FALSE`. A JSON object is then a named list, even when
#'   empty, and a JSON array is a list with no names.
#' @return `NULL` when the body passes, or one character string that names
#'   the first field or entry that breaks a rule.
#'
#' @noRd
model_list_fault <- function(body) {
  if (!is_json_object(body)) {
    return("the response body is not a JSON object.")
  }
  models <- body[["models"]]
  if (!is_json_array(models)) {
    return("`models` is not an array.")
  }

  for (i in seq_along(models)) {
    entry <- models[[i]]
    where <- paste("entry", i, "of `models`")
    if (!is_json_object(entry)) {
      return(paste0(where, " is not a JSON object."))
    }
    for (field in c("type", "key")) {
      if (!is_json_string(entry[[field]])) {
        return(paste0("`", field, "` of ", where, " is not a string."))
      }
    }
    size <- entry[["size_bytes"]]
    if (!is.null(size) && !is_json_number(size)) {
      return(paste0("`size_bytes` of ", where, " is not a number."))
    }
    instances <- entry[["loaded_instances"]]
    if (!is_json_array(instances)) {
      return(paste0("`loaded_instances` of ", where, " is not an array."))
    }

    for (j in seq_along(instances)) {
      instance <- instances[[j]]
      inner <- paste0("entry ", j, " of `loaded_instances` in ", where)
      if (!is_json_object(instance)) {
        return(paste0(inner, " is not a JSON object."))
      }
      id <- instance[["id"]]
      if (!is_json_string(id) || !grepl("[^[:space:]]", id)) {
        return(paste0("`id` of ", inner, " is not a string with content."))
      }
    }
  }

  NULL
}

#' Tell JSON types apart in an unsimplified parse
#'
#' `jsonlite::parse_json()` with `simplifyVector = FALSE` turns a JSON object
#' into a named list, an empty one included, and a JSON array into a list with
#' no names. A string, a number, and a boolean become length-one character,
#' numeric, and logical vectors. `null` becomes `NULL`.
#'
#' @param x A value out of such a parse.
#' @return `TRUE` or `FALSE`.
#'
#' @noRd
is_json_object <- function(x) is.list(x) && !is.null(names(x))

#' @rdname is_json_object
#' @noRd
is_json_array <- function(x) is.list(x) && is.null(names(x))

#' @rdname is_json_object
#' @noRd
is_json_string <- function(x) is.character(x) && length(x) == 1L

#' @rdname is_json_object
#' @noRd
is_json_number <- function(x) is.numeric(x) && length(x) == 1L
