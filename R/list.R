#' List available models
#'
#' Retrieves a list of models available on your system via the LM Studio REST
#' API.
#'
#' @param loaded `TRUE` or `FALSE`. If \code{TRUE}, returns only currently
#'   loaded models. Defaults to \code{FALSE}. Any other value, `NULL` and `NA`
#'   included, aborts before the check for a running server.
#' @param type Character vector. The types of models to include. Defaults to
#'   \code{c("llm", "embedding")}. It must hold one or more elements, and no
#'   element can be `NA`, empty, or whitespace only. Each element must be
#'   valid in its declared encoding and not marked `"bytes"`. Any other value,
#'   `NULL` and a factor included, aborts before the check for a running
#'   server. A type that no model has, such as `"vlm"`, matches nothing. A
#'   classed filter matches by its value, and a class method such as
#'   `as.character()` does not change the match.
#' @param detailed `TRUE` or `FALSE`. Show all information about each model.
#'   Defaults to \code{FALSE}. Any other value, `NULL` and `NA` included,
#'   aborts before the check for a running server.
#' @param quiet `TRUE`, `FALSE`, or `NULL`, the default. `NULL` follows the
#'   `rlmstudio.quiet` option. `TRUE` hides the message printed when no model
#'   is found, and `FALSE` prints it, also when the option is `TRUE`. Any other
#'   value, `NA` included, aborts before the check for a running server. Does
#'   not suppress the abort raised when the server is not running.
#' @param host Character. The host address of the local server.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#'
#' @seealso [LM Studio List Models
#'   API](https://lmstudio.ai/docs/developer/rest/list), and
#'   [list_instances()] for one row per loaded instance.
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
#' @inheritSection rlmstudio-conditions Malformed model list
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
  quiet = NULL,
  host = "http://localhost:1234",
  token = NULL
) {
  rlm_check_flag(loaded, "loaded")
  type <- rlm_check_type(type)
  rlm_check_flag(detailed, "detailed")
  rlm_check_flag(quiet, "quiet", null_ok = TRUE)
  stop_if_no_server(host)

  got <- request_model_list(host, token, "API List Failed")
  resp <- got$resp
  body <- got$body

  if (length(body[["models"]]) == 0) {
    # `quiet` goes in, so that `FALSE` overrides the option (D-028).
    rlm_inform(
      c("i" = "No models found on host {.url {host}}."),
      quiet = quiet
    )
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
    rlm_inform(
      c(
        "!" = "No models found matching criteria: loaded = {.val {loaded}}, type = {.val {type}}."
      ),
      quiet = quiet
    )
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

#' List loaded model instances
#'
#' Retrieves the loaded model instances on the server via the LM Studio REST
#' API, one row per instance, with the load configuration of each instance in
#' columns. It is the view that `lms ps` prints, read from the same model list
#' that [list_models()] reads, so it honors `host` and `token`.
#'
#' The model list does not carry four fields that `lms ps --json` reports: the
#' generation status, the queued requests, the ttl, and the last-used time.
#'
#' @section Columns:
#' The first four columns are character columns:
#'
#' - `id`: the id of the instance.
#' - `key`: the key of its model.
#' - `type`: the type of its model, such as `"llm"` or `"embedding"`.
#' - `display_name`: the display name of its model, or `NA` when the model
#'   list gives none.
#'
#' Rows follow the order of the models in the model list, then the order of
#' the instances of a model. Two instances with the same id, or two models
#' with the same key, give separate rows.
#'
#' After the four columns, the frame has one column for each field name in the
#' `config` object of an instance, in order of first appearance. When one
#' `config` holds a name twice, the first value counts. A row whose `config`
#' lacks the field, or has no `config`, holds `NA` there, or `NULL` in a
#' list-column.
#'
#' A column takes the field name as it is, with no name repair, so a name such
#' as `a-b` needs backticks or `[[`. A field name that is empty, or that equals
#' one of the four column names or the column name of an earlier field, takes
#' the prefix `config.`, again and again while the name still clashes. A field
#' named `id` so gives the column `config.id`.
#'
#' The column type follows the values of the field that are present and not
#' `null`:
#'
#' - All strings give a character column.
#' - All numbers give a double column, whole numbers included.
#' - All booleans give a logical column.
#' - No such values give a logical column of `NA`.
#'
#' In these four kinds, a `null` value is `NA`. Any other mix, or any JSON
#' object or array, gives a list-column. It holds each value as
#' [jsonlite::parse_json()] returns it, and `NULL` where the field is absent or
#' `null`.
#'
#' @param type Character vector. The types of models to include. Defaults to
#'   \code{c("llm", "embedding")}. It must hold one or more elements, and no
#'   element can be `NA`, empty, or whitespace only. Each element must be
#'   valid in its declared encoding and not marked `"bytes"`. Any other value,
#'   `NULL` and a factor included, aborts before the check for a running
#'   server. A type that no model has, such as `"vlm"`, matches nothing. A
#'   classed filter matches by its value, and a class method such as
#'   `as.character()` does not change the match.
#' @param quiet `TRUE`, `FALSE`, or `NULL`, the default. `NULL` follows the
#'   `rlmstudio.quiet` option. `TRUE` hides the message printed when no
#'   instance is found, and `FALSE` prints it, also when the option is `TRUE`.
#'   Any other value, `NA` included, aborts before the check for a running
#'   server. Does not suppress the abort raised when the server is not
#'   running.
#' @param host Character. The host address of the local server.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#'
#' @seealso [LM Studio List Models
#'   API](https://lmstudio.ai/docs/developer/rest/list), and [list_models()]
#'   for one row per model.
#'
#' @return A \code{data.frame} with one row per loaded instance of a model
#'   whose type is in `type`, with the columns that the "Columns" section
#'   describes. If there is no such instance, it returns a \code{data.frame}
#'   with zero rows and the four character columns, invisibly, and prints a
#'   message that `quiet` controls.
#'
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @inheritSection rlmstudio-conditions Malformed model list
#'
#' @export
#'
#' @examples
#' \dontrun{
#' lms_server_start()
#' lms_load("google/gemma-3-1b")
#'
#' # One row per loaded instance, with its load configuration
#' list_instances()
#'
#' # Only the loaded embedding models
#' list_instances(type = "embedding")
#' }
list_instances <- function(
  type = c("llm", "embedding"),
  quiet = NULL,
  host = "http://localhost:1234",
  token = NULL
) {
  type <- rlm_check_type(type)
  rlm_check_flag(quiet, "quiet", null_ok = TRUE)
  stop_if_no_server(host)

  label <- "API List Failed"
  got <- request_model_list(host, token, label)
  models <- got$body[["models"]]

  fault <- instance_list_fault(models, type)
  if (!is.null(fault)) {
    rlm_abort_bad_reply(got$resp, label, fault, "a model list")
  }

  rows <- list()
  for (model in models) {
    if (!model[["type"]] %in% type) {
      next
    }
    display_name <- model[["display_name"]]
    if (is.null(display_name)) {
      display_name <- NA_character_
    }
    for (instance in model[["loaded_instances"]]) {
      rows[[length(rows) + 1L]] <- list(
        id = instance[["id"]],
        key = model[["key"]],
        type = model[["type"]],
        display_name = display_name,
        config = instance[["config"]]
      )
    }
  }

  if (length(rows) == 0) {
    # `quiet` goes in, so that `FALSE` overrides the option (D-028).
    rlm_inform(
      c(
        "i" = "No loaded model instances of type {.val {type}} found on host {.url {host}}."
      ),
      quiet = quiet
    )
    return(invisible(data.frame(
      id = character(),
      key = character(),
      type = character(),
      display_name = character()
    )))
  }

  column <- function(name) vapply(rows, function(row) row[[name]], character(1))
  df <- data.frame(
    id = column("id"),
    key = column("key"),
    type = column("type"),
    display_name = column("display_name")
  )

  configs <- lapply(rows, function(row) row[["config"]])
  fields <- unique(unlist(lapply(configs, names)))
  for (field in fields) {
    name <- field
    while (name == "" || name %in% names(df)) {
      name <- paste0("config.", name)
    }
    df[[name]] <- config_column(configs, field)
  }

  df
}

#' Find the first way a model list breaks the rules of the instance table
#'
#' The checks that `list_instances()` adds to `model_list_fault()`, which it
#' runs first through `request_model_list()`. They cover the fields that only
#' the instance table reads, and only in a model whose `type` is in `type` and
#' that has at least one instance:
#'
#' 1. The `display_name` of the model is a string, or absent, or `null`.
#' 2. The `config` of each instance is a JSON object, or absent, or `null`.
#'
#' The checks live here and not in `model_list_fault()`, so `list_models()`
#' and `lms_server_ready()` accept the same bodies as before.
#'
#' @param models The `models` array of a body that `model_list_fault()`
#'   passed, as `parse_json_body()` returns it with `simplifyVector = FALSE`.
#' @param type Character vector. The model types that the table keeps.
#' @return `NULL` when the list passes, or one character string that names
#'   the first field that breaks a rule.
#'
#' @noRd
instance_list_fault <- function(models, type) {
  for (i in seq_along(models)) {
    entry <- models[[i]]
    instances <- entry[["loaded_instances"]]
    if (!entry[["type"]] %in% type || length(instances) == 0) {
      next
    }
    where <- paste("entry", i, "of `models`")
    display_name <- entry[["display_name"]]
    if (!is.null(display_name) && !is_json_string(display_name)) {
      return(paste0("`display_name` of ", where, " is not a string."))
    }
    for (j in seq_along(instances)) {
      config <- instances[[j]][["config"]]
      if (!is.null(config) && !is_json_object(config)) {
        return(paste0(
          "`config` of entry ", j, " of `loaded_instances` in ", where,
          " is not a JSON object."
        ))
      }
    }
  }
  NULL
}

#' Build one configuration column of the instance table
#'
#' Reads one field out of each instance configuration and picks the column
#' type from the values that are present and not `null`. Strings give a
#' character column, numbers a double column, and booleans a logical column,
#' with `NA` where the field is absent or `null`. No such values give a
#' logical column of `NA`. Any other mix, or any JSON object or array, gives a
#' list-column that holds each value as `jsonlite::parse_json()` returns it,
#' with `NULL` where the field is absent or `null`.
#'
#' @param configs A list with one element per row: the `config` object of the
#'   instance as a named list, or `NULL` where the instance has none.
#' @param field Character. The field name. The first entry of a configuration
#'   with that exact name is read, and an empty name is matched too, which
#'   `[[` does not do.
#' @return A vector or list with one element per row.
#'
#' @noRd
config_column <- function(configs, field) {
  values <- lapply(configs, function(cfg) {
    at <- match(field, names(cfg))
    if (is.na(at)) NULL else cfg[[at]]
  })
  present <- Filter(Negate(is.null), values)

  kind <- function(x) {
    if (is_json_string(x)) {
      "character"
    } else if (is_json_number(x)) {
      "double"
    } else if (is.logical(x) && length(x) == 1L) {
      "logical"
    } else {
      "other"
    }
  }
  kinds <- unique(vapply(present, kind, character(1)))

  if (length(kinds) == 0) {
    return(rep(NA, length(values)))
  }
  if (length(kinds) > 1 || kinds == "other") {
    return(values)
  }
  vapply(
    values,
    function(x) as.vector(if (is.null(x)) NA else x, kinds),
    vector(kinds, 1)
  )
}

#' Request the model list and check its body
#'
#' The request and the checks that `list_models()` runs after its server
#' probe. The model check of the chat functions runs them too, so a model list
#' fails there with the same classes.
#'
#' @param host Character. The base URL of the server.
#' @param token Character or `NULL`. The API token, resolved as the calling
#'   function resolves it.
#' @param label Character. The label that opens every message.
#' @return A list with `resp`, the httr2 response, and `body`, the body as
#'   `parse_json_body()` returns it with `simplifyVector = FALSE`.
#'
#' @noRd
request_model_list <- function(host, token, label) {
  req <- lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/models") |>
    httr2::req_error(is_error = \(resp) FALSE)
  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) != 200) {
    rlm_abort_api(resp, label, request_sends_token(req))
  }

  body <- parse_ok_body(resp, label)
  fault <- model_list_fault(body)
  if (!is.null(fault)) {
    rlm_abort_bad_reply(resp, label, fault, "a model list")
  }
  list(resp = resp, body = body)
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
#' 3. The `size_bytes` and the `max_context_length` of an entry are each a
#'    number, or absent, or `null`. `lms_load()` reads `max_context_length`.
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
    for (field in c("size_bytes", "max_context_length")) {
      value <- entry[[field]]
      if (!is.null(value) && !is_json_number(value)) {
        return(paste0("`", field, "` of ", where, " is not a number."))
      }
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
