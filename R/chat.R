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
#' @param logprobs `TRUE` or `FALSE`. Whether to return the log probabilities
#'   of the generated tokens. Default is `FALSE`. Any other value, `NULL` and
#'   `NA` included, aborts before the check for a running server.
#' @param simplify `TRUE` or `FALSE`. If `TRUE`, extracts the core text
#'   response. Default is `TRUE`. Any other value, `NULL` and `NA` included,
#'   aborts before the check for a running server.
#' @param ... Additional arguments passed to the selected API body.
#'   The package checks a `stream` here. A `stream` other than `FALSE` or
#'   `NULL` aborts before the call checks for a running server, because the
#'   package reads a whole reply and not a streamed one.
#' @param schema A JSON Schema that the reply must match, or `NULL`. It needs
#'   `api_type = "openai"`, and any other `api_type` aborts before the request.
#'   See [lms_chat_openai()] for its form and for what is returned.
#' @param ttl A whole number of seconds from 1 to `.Machine$integer.max`, or
#'   `NULL`. It is how long the model stays loaded with no request. It needs
#'   `api_type = "openai"`, and any other `api_type`, the default included,
#'   aborts before the request. It has an effect only on a model that this
#'   request loads. The server loads a model that is not loaded yet when its
#'   just-in-time loading setting is on. A model that is already loaded keeps
#'   its idle time.
#' @param previous_response_id One string, or `NULL`. The id of a stored reply
#'   that this chat continues, such as the `response_id` attribute of an
#'   earlier reply. `NULL`, the default, starts a new thread. It needs
#'   `api_type = "native"` or `api_type = "openresponses"`. With
#'   `api_type = "openai"`, a string aborts before the request, because the
#'   OpenAI chat endpoint keeps no thread. `NA`, an empty string, a string of
#'   whitespace only, a value that is not a string, and more or fewer than one
#'   string abort before the check for a running server. Only this exact name
#'   is checked. A shortened name, such as `previous`, goes into the request
#'   body unchecked, under the name you wrote. An id that the server does not
#'   hold raises `rlmstudio_api_error` with status 400.
#' @return Depending on the arguments provided:
#' \itemize{
#'   \item If \code{simplify = FALSE}, returns a parsed list of the raw JSON response.
#'   \item If \code{simplify = TRUE} and \code{logprobs = FALSE}, returns a single character string containing the model's text response. With a \code{schema}, it returns the reply parsed into an R value instead.
#'   \item If \code{simplify = TRUE} and \code{logprobs = TRUE} (and the chosen API type supports it), returns an object of class \code{lms_chat_result} containing both the text and a data.frame of token probabilities.
#' }
#'
#' With `simplify = TRUE` and `api_type = "native"` or
#' `api_type = "openresponses"`, the value carries the id of the reply in a
#' `response_id` attribute. Pass it as `previous_response_id` to continue the
#' thread. The id is the `response_id` field of a native reply and the `id`
#' field of an OpenResponses reply. The value has no attribute when that
#' field is absent or is not one string. A native reply sent with
#' `store = FALSE` in `...` carries no id, and an OpenResponses reply sent
#' with `store = FALSE` still carries one. With `api_type = "openai"`, or
#' with `simplify = FALSE`, the value has no `response_id` attribute.
#' @details
#' This function calls [lms_chat_openresponses()], [lms_chat_openai()], or
#' [lms_chat_native()], according to `api_type`. It runs no request of its own.
#' It can raise `rlmstudio_no_server` and `rlmstudio_api_error` through
#' [lms_chat_openresponses()], [lms_chat_openai()], or [lms_chat_native()].
#' With `simplify = TRUE`, it can raise `rlmstudio_bad_response` through any
#' of the three, for a reply that holds no readable answer text. With either
#' setting of `simplify`, it raises `rlmstudio_bad_response` through any of the
#' three for a status-200 body that does not parse as JSON. With either
#' setting of `simplify`, it raises `rlmstudio_model_mismatch` through
#' [lms_chat_openresponses()] or [lms_chat_openai()] for a reply from a model
#' other than the one asked for.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @inheritSection rlmstudio-conditions Cut-off reply
#' @inheritSection rlmstudio-conditions Reply from another model
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
  ttl = NULL,
  previous_response_id = NULL,
  token = NULL
) {
  api_type <- match.arg(api_type)
  rlm_check_id(model, "model")
  rlm_check_no_na(input, "input")
  rlm_check_schema(schema, ...names())
  rlm_check_schema_route(schema, api_type)
  rlm_check_ttl(ttl)
  rlm_check_ttl_route(ttl, api_type)
  rlm_check_response_id(previous_response_id)
  rlm_check_thread_route(previous_response_id, api_type)
  rlm_check_flag(logprobs, "logprobs")
  rlm_check_flag(simplify, "simplify")

  if (api_type == "openresponses") {
    return(lms_chat_openresponses(
      model = model,
      input = input,
      instructions = system_prompt,
      host = host,
      logprobs = logprobs,
      simplify = simplify,
      ...,
      previous_response_id = previous_response_id,
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
      ttl = ttl,
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
      previous_response_id = previous_response_id,
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
#' @param logprobs `TRUE` or `FALSE`. Whether to return token probabilities.
#'   Any other value, `NULL` and `NA` included, aborts before the check for a
#'   running server.
#' @param simplify `TRUE` or `FALSE`. If `TRUE`, parses output to text and
#'   dataframe. If `FALSE`, returns raw list. Any other value, `NULL` and `NA`
#'   included, aborts before the check for a running server.
#' @param ... Additional API arguments (e.g., top_logprobs, temperature). This
#'   endpoint accepts a `ttl` field and ignores it. The model keeps the idle
#'   time that the server sets.
#'   The package checks a `stream` here. A `stream` other than `FALSE` or
#'   `NULL` aborts before the call checks for a running server, because the
#'   package reads a whole reply and not a streamed one.
#' @param previous_response_id One string, or `NULL`. The id of a stored reply
#'   that this chat continues, such as the `response_id` attribute of an
#'   earlier reply of this function or of [lms_chat_native()]. `NULL`, the
#'   default, starts a new thread. `NA`, an empty string, a string of
#'   whitespace only, a value that is not a string, and more or fewer than one
#'   string abort before the check for a running server. Only this exact name
#'   is checked. A shortened name, such as `previous`, goes into the request
#'   body unchecked, under the name you wrote. An id that the server does not
#'   hold raises `rlmstudio_api_error` with status 400 and the `code`
#'   `"previous_response_not_found"`. [lms_chat()] and [lms_chat_batch()]
#'   refuse a string with `api_type = "openai"`, because the OpenAI chat
#'   endpoint keeps no thread. [lms_chat_openai()] has no such argument. A
#'   `previous_response_id` in its `...` goes into the request body
#'   unchecked, and the endpoint ignores it.
#' @return If \code{simplify = FALSE}, returns a list representing the raw JSON
#'   response. A status-200 body that does not parse as JSON raises
#'   `rlmstudio_bad_response` with either setting of `simplify`. Otherwise,
#'   returns one character string: the `text` of every
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
#'
#'   With `simplify = TRUE`, the string or the `lms_chat_result` carries the
#'   `id` field of the reply in a `response_id` attribute. Pass it as
#'   `previous_response_id` to continue the thread. The value has no
#'   attribute when `id` is absent or is not one string. A reply sent with
#'   `store = FALSE` in `...` still carries an `id`, so its value still
#'   carries the attribute. [lms_chat_native()] reads the attribute from the
#'   `response_id` field of its reply instead. A native reply sent with
#'   `store = FALSE` carries no `response_id`, so its value has no attribute.
#'
#'   With either setting of `simplify`, a reply from a model other than the
#'   one asked for raises `rlmstudio_model_mismatch`. See the "Reply from
#'   another model" section.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @inheritSection rlmstudio-conditions Reply from another model
#' @export
lms_chat_openresponses <- function(
  model,
  input,
  instructions = NULL,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...,
  previous_response_id = NULL,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_no_na(input, "input")
  rlm_check_flag(logprobs, "logprobs")
  rlm_check_flag(simplify, "simplify")
  rlm_check_response_id(previous_response_id)
  rlm_check_stream(list(...))

  stop_if_no_server(host)

  body <- list(
    model = model,
    input = input,
    instructions = instructions,
    previous_response_id = previous_response_id
  )
  if (isTRUE(logprobs)) {
    body$include <- list("message.output_text.logprobs")
  }

  body <- Filter(Negate(is.null), body)
  body <- utils::modifyList(body, list(...))

  req <- lms_client(host, token = token) |>
    httr2::req_url_path("v1/responses") |>
    rlm_req_body(body) |>
    httr2::req_error(is_error = \(resp) FALSE)
  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) == 200) {
    resp_data <- parse_ok_body(resp, "OpenResponses Failed")
    check_reply_model(
      resp,
      resp_data,
      model,
      host,
      token,
      "OpenResponses Failed"
    )
    if (!isTRUE(simplify)) {
      return(resp_data)
    }
    return(with_response_id(
      responses_reply_value(resp, resp_data, logprobs),
      resp_data[["id"]]
    ))
  }

  rlm_abort_api(resp, "OpenResponses Failed", request_sends_token(req))
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
#' @param messages The messages to send. Give an unnamed list with one element
#'   per message, such as `list(list(role = "user", content = "Hi"))`, or a
#'   data frame with at least one row. A data frame is sent as one message per
#'   row, with one field per column. A cell that is `NA` is left out of its
#'   message. The call aborts before it checks for a
#'   running server if `messages` breaks one of these rules:
#'   * `messages` is a list or a data frame.
#'   * A data frame has at least one row, and any other list has at least one
#'     element.
#'   * A list that is not a data frame has no names. A single message not
#'     wrapped in a list, such as `list(role = "user", content = "Hi")`,
#'     breaks this rule.
#'   * Each element of such a list is a list of length one or more, and each
#'     of its fields has a name that is not `NA` and not empty. A data frame
#'     as an element breaks this rule.
#'   * A data frame has at least one column, and no column name is `NA`,
#'     empty, or repeated.
#'   * A data frame has no row in which every cell is `NA` or is a `NULL`
#'     cell of a list column. jsonlite leaves out an `NA` cell of another
#'     column and writes an `NA` or `NULL` list cell as `null`, so such a row
#'     holds no field value. A `list()`
#'     cell is sent as `[]` and a `list(NA)` cell as `[null]`, so a row with
#'     such a cell is sent. A column with a `dim` attribute of any length
#'     whose first extent is the row count, such as a matrix or an array,
#'     counts as empty in a row when each of its cells in that row is empty.
#'     Such a column with no cells in a row, such as a 2-by-0 matrix, is not
#'     empty in that row, because jsonlite writes that row of it as `[]` or
#'     as nested empty arrays. A data-frame column counts as empty in a row
#'     when each of its own columns is empty in that row. So a data-frame
#'     column with no columns counts as empty in every row. A column that
#'     is neither an atomic vector nor a list, such as an environment, never
#'     counts as empty.
#'   * `messages`, when it is a list and not a data frame, has no `dim`
#'     attribute, such as a matrix or an array of messages.
#'   * A message that is a list has no `dim` attribute.
#'   * No list inside a message has a `dim` attribute. The rule reads each
#'     field, each list at any depth below a field, and each cell of a list
#'     column. jsonlite would send such a list as nested arrays with each
#'     cell in an array of its own. A list column of a data frame with one,
#'     three, or more dimensions also breaks this rule. An atomic matrix
#'     field is sent as an array of arrays. A list-matrix column of any data
#'     frame is sent, one row of cells for each message. jsonlite does not
#'     unbox a value inside a list-matrix cell, at any depth in a list,
#'     unless `jsonlite::unbox()` wraps it. A data frame in a cell is sent as
#'     an array of objects whose values are not boxed. So a length-one
#'     atomic cell is sent as a one-element array, such as `["a"]`, and a
#'     `NULL` cell is sent as `null`. For example, a row with `role`
#'     `"user"`, `content` `"hi"`, and the cells `"a"`, `NULL`, and
#'     `list(k = "v")` in a list-matrix column `tags` is sent as
#'     `{"role":"user","content":"hi","tags":[["a"],null,{"k":["v"]}]}`.
#'   * No message, and no list or data frame inside a message or inside a
#'     cell or column of a data frame, has a name that is `NA`, empty, or
#'     repeated. jsonlite would send an `NA` or empty name as a number and
#'     rename a repeated name `a` to `a.1`. A list with no names passes. The
#'     names of a list column are not checked, because they are not sent.
#'     The names of an atomic vector and the column names of a matrix are
#'     not checked, because jsonlite sends those values as arrays.
#'
#'   The error for each rule above opens with "`messages` must be a data
#'   frame or an unnamed list of messages." and shows the form of a message.
#'   Four more rules are checked after them. Their error opens with
#'   "`messages` holds a field value that cannot be sent as JSON." and shows
#'   no form:
#'   * No function sits inside `messages`: not as a field, in a list below a
#'     field, as a column of a data frame, or in a cell of a list column.
#'     jsonlite would send a function as its source text. A function with a
#'     class gets the error of this rule, not the error of a later one.
#'   * Each value inside `messages`, in the places the rule above reads, is
#'     an atomic vector, a list, or `NULL`. An environment, a symbol, a
#'     call, a formula, an expression vector, an external pointer, or an S4
#'     object breaks this rule, and the error names its type. The rule reads
#'     the storage type, so a class set by hand on such a value does not
#'     hide it. jsonlite would send such a value as printed text, as `null`,
#'     or as an object or array of other data, or it would fail. A `NULL`
#'     field passes and is sent as `null`. An S4 object whose class contains
#'     an atomic type, such as `"numeric"`, passes this rule, and jsonlite
#'     sends its data part without its other slots. An S4 object whose class
#'     contains `"list"` passes, and the rule reads its elements. The rule
#'     does not read the class of a vector or a list. A vector with a class
#'     set by hand, such as `structure(1L, class = "NULL")`, passes, and
#'     jsonlite writes it by that class.
#'   * No number inside `messages` is `NA`, `NaN`, `Inf`, or `-Inf`. The
#'     rule reads a double or integer vector with no class or with the class
#'     `"AsIs"` alone, such as a field wrapped in [I()]. jsonlite would send
#'     such a number as the string `"NA"`, `"NaN"`, `"Inf"`, or `"-Inf"`.
#'     The rule reads a field,
#'     an element of a field, a list at any depth below a field, a cell of a
#'     list column or a list-matrix column, and a matrix or array column. An
#'     atomic column with no `dim` attribute, of a data frame at any depth,
#'     is the exception. jsonlite leaves an `NA`, `NaN`, `Inf`, or `-Inf`
#'     cell of such a column out of its message. There the rule refuses
#'     `Inf` and `-Inf` alone, and an `NA` or `NaN` cell is left out as a
#'     missing field. A number with another class, such as a `Date`, is
#'     written by its class, so `as.Date(NA)` is sent as `null` and
#'     `as.Date(Inf)` as `"Inf"`. Below a message, the rule reads the parts
#'     of a list whose class is neither `"AsIs"` nor a data frame only when
#'     jsonlite writes that list as it writes the list without its class,
#'     such as a list with the class `c("foo", "list")`. It does not read
#'     the parts of a `POSIXlt` value.
#'   * jsonlite can write the value, with the options that the request uses.
#'     If it cannot, the error gives the jsonlite message. This rule is
#'     checked last.
#'
#'   A list that is not a data frame is sent without its class attribute, and
#'   each of its messages is sent without its class attribute. A class on a
#'   field inside a message is kept, so a field wrapped in [I()] is sent as an
#'   array. A data frame and its columns keep their classes. A kept class that
#'   jsonlite has no method for, such as a field with the class `"foo"` alone,
#'   breaks the last rule.
#'
#'   The package checks the shape of `messages`. Of the field values, it
#'   refuses a function, a value that is not an atomic vector, a list, or
#'   `NULL`, a number with no class or with the class `"AsIs"` alone that
#'   jsonlite would send as a string or, in a data-frame column, would leave
#'   out because it is infinite, and a value that jsonlite cannot write. It
#'   does not check any other value of a role, the content, or another field
#'   of a message. The server checks them.
#' @param host Character. Server URL.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param logprobs `TRUE` or `FALSE`. Whether to request logprobs (currently
#'   stubbed by LM Studio). Any other value, `NULL` and `NA` included, aborts
#'   before the check for a running server.
#' @param simplify `TRUE` or `FALSE`. If `TRUE`, parses output to text. Any
#'   other value, `NULL` and `NA` included, aborts before the check for a
#'   running server.
#' @param ... Additional API arguments. A `response_format` here cannot be
#'   combined with `schema`.
#'   The package checks a `stream` here. A `stream` other than `FALSE` or
#'   `NULL` aborts before the call checks for a running server, because the
#'   package reads a whole reply and not a streamed one.
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
#' @param ttl A whole number of seconds from 1 to `.Machine$integer.max`, or
#'   `NULL` to leave it out. It is how long the model stays loaded with no
#'   request. It has an effect only on a model that this request loads. The
#'   server loads a model that is not loaded yet when its just-in-time loading
#'   setting is on. A model that is already loaded keeps its idle time.
#' @return If \code{simplify = FALSE}, returns a list representing the raw JSON
#'   response. A status-200 body that does not parse as JSON raises
#'   `rlmstudio_bad_response` with either setting of `simplify`. Otherwise,
#'   returns a character string containing the generated
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
#'   the reply stays a string. With a `schema`, `simplify = TRUE`, and
#'   `logprobs = FALSE`, a reply that a length limit ended raises
#'   `rlmstudio_bad_response`, also when it parses. With `simplify = TRUE` in
#'   any other setting, such a reply whose content is one string is returned
#'   with a warning. See the "Cut-off reply" section.
#'
#'   With `simplify = TRUE`, the reply is read from the first element of the
#'   `choices` field. No other element of `choices` is read. A request with
#'   `n` in `...` therefore returns the first choice alone, and the cut-off
#'   warning and abort depend on the finish reason of that choice alone. With
#'   `simplify = FALSE`, the body holds every choice.
#'
#'   With either setting of `simplify`, a reply from a model other than the
#'   one asked for raises `rlmstudio_model_mismatch`. See the "Reply from
#'   another model" section.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @inheritSection rlmstudio-conditions Cut-off reply
#' @inheritSection rlmstudio-conditions Reply from another model
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
  ttl = NULL,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_messages(messages)
  rlm_check_schema(schema, ...names())
  rlm_check_ttl(ttl)
  rlm_check_flag(logprobs, "logprobs")
  rlm_check_flag(simplify, "simplify")
  rlm_check_stream(list(...))

  stop_if_no_server(host)

  body <- list(model = model, messages = unclass_messages(messages))
  if (isTRUE(logprobs)) {
    body$logprobs <- TRUE
  }

  body <- Filter(Negate(is.null), body)
  if (!is.null(schema)) {
    body$response_format <- schema_response_format(schema)
  }
  # An R integer is written as a JSON integer whatever the serializer does
  # with a double. The check has already made the value whole and in range.
  if (!is.null(ttl)) {
    body$ttl <- as.integer(ttl)
  }
  body <- utils::modifyList(body, list(...))

  req <- lms_client(host, token = token) |>
    httr2::req_url_path("v1/chat/completions") |>
    rlm_req_body(body) |>
    httr2::req_error(is_error = \(resp) FALSE)
  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) == 200) {
    # Every OpenAI condition about the reply carries these two fields, so a
    # caller can read them without checking which fault it caught. A
    # condition from the model-list lookup does not.
    resp_data <- parse_ok_body(
      resp,
      "OpenAI API Failed",
      content = NULL,
      finish_reason = NULL
    )
    check_reply_model(
      resp,
      resp_data,
      model,
      host,
      token,
      "OpenAI API Failed",
      content = NULL,
      finish_reason = NULL
    )
    if (!isTRUE(simplify)) {
      return(resp_data)
    }
    return(openai_reply_value(resp, resp_data, logprobs, schema))
  }

  rlm_abort_api(resp, "OpenAI API Failed", request_sends_token(req))
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
  check_body_object(
    resp,
    resp_data,
    "OpenAI API Failed",
    content = NULL,
    finish_reason = NULL
  )
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
    value <- validate_lms_chat_result(
      new_lms_chat_result(text = res_text, logprobs = NULL)
    )
    warn_if_cut_off(finish_reason)
    return(value)
  }
  if (!is.null(schema)) {
    # A reply that a length limit ended is not a whole answer, also when what
    # the model wrote so far parses, such as a lone digit (D-021).
    if (identical(finish_reason, "length")) {
      # `abort_unread_reply()` words the detail for this finish reason.
      abort_unread_reply(
        resp,
        res_text,
        "OpenAI API Failed",
        NULL,
        finish_reason
      )
    }
    return(parse_schema_reply(
      resp,
      res_text,
      "OpenAI API Failed",
      finish_reason = finish_reason
    ))
  }
  warn_if_cut_off(finish_reason)
  res_text
}

#' Warn that a length limit cut a text reply off
#'
#' Called only after every check on the reply has passed, so a reply never
#' both warns and fails. The warning goes through `cli::cli_warn()` and not
#' through the quiet helpers, because it is the only sign that an answer is
#' not complete (D-021). `lms_chat_batch()` muffles it for each input and
#' gives one warning of the same class for the batch.
#'
#' @param finish_reason The `finish_reason` of the first choice, or `NULL`.
#'
#' @noRd
warn_if_cut_off <- function(finish_reason) {
  if (identical(finish_reason, "length")) {
    cli::cli_warn(
      c(
        "A length limit ended the reply before it was complete.",
        "i" = "The limit is {.code max_tokens} or the context length of the model. Raise the one that is too low."
      ),
      class = "rlmstudio_reply_cut_off",
      call = NULL
    )
  }
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
#' @param ... Extra condition fields, such as the `content` and
#'   `finish_reason` fields that every OpenAI condition about the reply
#'   carries.
#'
#' @noRd
check_body_object <- function(resp, resp_data, label, ...) {
  if (!is.null(resp_data) && !is.list(resp_data)) {
    rlm_abort_bad_response(
      resp,
      label,
      "The response body is not a JSON object.",
      ...
    )
  }
}

#' Abort on a chat reply from a model other than the one asked for
#'
#' LM Studio can answer a model name that it cannot find with a reply from
#' the one chat model it has loaded, under status 200 (M049 work log). The
#' `model` field of the reply names the loaded instance that answered. Its id
#' can differ from the key the caller asked for, so a name that differs
#' starts one model-list request, and the reply is accepted when the
#' answering instance belongs to a model whose key equals the asked name in
#' any letter case (D-025). A reply with no `model` string is not checked.
#' Fields are read with `[[`, because `$` would read a field whose name only
#' starts with the one asked for. The asked name is compared as a plain
#' string, because `identical()` also compares names, class, and the S4 bit,
#' and a named, classed, or S4 string passes `rlm_check_id()`. `unclass()`
#' keeps the S4 bit, and `[[` drops it.
#'
#' Runs before the caller's `simplify` branch, so `simplify = FALSE` cannot
#' return a reply from the wrong model.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param resp_data The parsed response body.
#' @param model Character. The model name the call sent.
#' @param host,token The host and token of the call, for the model list.
#' @param label Character. The calling wrapper's label.
#' @param ... Extra condition fields, such as the `content` and
#'   `finish_reason` fields that `lms_chat_openai()` gives each
#'   `rlmstudio_bad_response` about its reply.
#'
#' @noRd
check_reply_model <- function(resp, resp_data, model, host, token, label, ...) {
  reply_model <- if (is_json_object(resp_data)) resp_data[["model"]]
  if (!is_one_string(reply_model) || !grepl("[^[:space:]]", reply_model)) {
    return(invisible())
  }
  model <- unclass(model)[[1]]
  if (identical(reply_model, model)) {
    return(invisible())
  }
  if (reply_model_serves(model, reply_model, host, token, label)) {
    return(invisible())
  }
  # The names are placed in the detail as text, so braces in a name that the
  # server sent are not read as cli markup.
  rlm_abort_bad_response(
    resp,
    label,
    paste0(
      "The reply came from the model \"",
      reply_model,
      "\", not from the model \"",
      model,
      "\" that the call asked for."
    ),
    hint = paste(
      "LM Studio can answer a model name that it cannot find with a model",
      "that is loaded. Check the name with",
      "{.code list_models(loaded = TRUE)}, or load the model with",
      "{.fn lms_load}."
    ),
    class = "rlmstudio_model_mismatch",
    model = model,
    reply_model = reply_model,
    ...
  )
}

#' Does a loaded instance of the asked model have the reply's id?
#'
#' Reads the model list of every model type through the checks of
#' `list_models()`, with no message. A failed lookup raises the condition of
#' that failure, under a label that names the chat function and the lookup.
#'
#' @param model Character. The model name the call sent.
#' @param reply_model Character. The `model` field of the reply.
#' @param host,token The host and token of the call.
#' @param label Character. The calling wrapper's label.
#' @return `TRUE` when a model whose key equals `model` in any letter case has
#'   a loaded instance whose id is `reply_model`, else `FALSE`.
#'
#' @noRd
reply_model_serves <- function(model, reply_model, host, token, label) {
  lookup_label <- paste0(label, ", because the model-list lookup failed")
  if (!is_server_running(host)) {
    cli::cli_abort(
      c(
        "x" = "{lookup_label}: the LM Studio server is not running.",
        "i" = "Run {.fn lms_server_start} first."
      ),
      class = "rlmstudio_no_server",
      call = NULL
    )
  }
  models <- request_model_list(host, token, lookup_label)$body[["models"]]
  for (entry in models) {
    if (!identical(tolower(entry[["key"]]), tolower(model))) {
      next
    }
    ids <- vapply(entry[["loaded_instances"]], \(x) x[["id"]], character(1))
    if (reply_model %in% ids) {
      return(TRUE)
    }
  }
  FALSE
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
#' finish reason of `"length"` means the server stopped the reply at a length
#' limit, which is the likely reason the JSON is incomplete, so the message
#' says so in place of the generic detail. `openai_reply_value()` aborts on
#' that finish reason before it calls this function.
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

#' Abort on a chat completions reply that cannot be read or is not complete
#'
#' The abort carries the reply content and the finish reason as fields, so a
#' caller can read what the model wrote without sending the request again. A
#' finish reason of `"length"` means the server stopped the reply at
#' `max_tokens` or at the context length of the model, so the reply is not
#' complete. The message then says so in place of `detail`.
#'
#' @param resp The httr2 response, for the status the abort carries.
#' @param content The reply content read out of the response.
#' @param label Character. The calling wrapper's label, which opens the message.
#' @param detail Character. What is wrong with the reply. A finish reason of
#'   `"length"` replaces it, so a caller may pass `NULL` then.
#' @param finish_reason The `finish_reason` of the first choice, or `NULL`.
#'
#' @noRd
abort_unread_reply <-function(resp, content, label, detail, finish_reason) {
  if (identical(finish_reason, "length")) {
    # The server gives this finish reason for either limit, and the reply
    # does not say which one it reached.
    detail <- paste(
      "A length limit ended the reply before it was complete.",
      "The limit is `max_tokens` or the context length of the model.",
      "Raise the one that is too low."
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

#' Attach the reply id that continues a thread
#'
#' What the two thread routes return with `simplify = TRUE` carries the reply
#' id in a `response_id` attribute, so a caller can pass it on as
#' `previous_response_id` (D-030). A value of any other type sets no
#' attribute and never fails the call, as `native_reply_fields()` treats the
#' id. The shared readers do not call this, so the data-frame batch returns
#' its text columns with no attribute.
#'
#' @param value The simplified reply: one string or an `lms_chat_result`.
#' @param id The id field of the parsed reply, read with `[[`.
#' @return `value`, with the attribute when `id` is one string.
#'
#' @noRd
with_response_id <- function(value, id) {
  # The reader in `value` runs first. It aborts on a body that is not a JSON
  # object, where the `[[` read in `id` would fail with a base R error.
  force(value)
  if (is_one_string(id)) {
    attr(value, "response_id") <- id
  }
  value
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
#' @param simplify `TRUE` or `FALSE`. If `TRUE`, parses output to text. Any
#'   other value, `NULL` and `NA` included, aborts before the check for a
#'   running server.
#' @param ... Additional API arguments. This endpoint rejects a `ttl` field
#'   with status 400, which raises `rlmstudio_api_error`.
#'   The package checks a `stream` here. A `stream` other than `FALSE` or
#'   `NULL` aborts before the call checks for a running server, because the
#'   package reads a whole reply and not a streamed one.
#'   The package also checks each element named exactly `logprobs`. It must
#'   be `TRUE`, `FALSE`, or `NULL`, and any other value aborts before the check
#'   for a running server. The endpoint has no logprobs, so no `logprobs` field
#'   goes into the request body, and a `TRUE` warns.
#' @param previous_response_id One string, or `NULL`. The id of a stored reply
#'   that this chat continues, such as the `response_id` attribute of an
#'   earlier reply of this function. `NULL`, the default, starts a new thread.
#'   `NA`, an empty string, a string of whitespace only, a value that is not a
#'   string, and more or fewer than one string abort before the check for a
#'   running server. Only this exact name is checked. A shortened name, such
#'   as `previous`, goes into the request body unchecked, under the name you
#'   wrote. An id that the server does not hold raises `rlmstudio_api_error`
#'   with status 400 and the `code` `"invalid_value"`. [lms_chat()] and
#'   [lms_chat_batch()] refuse a string with `api_type = "openai"`, because
#'   the OpenAI chat endpoint keeps no thread. [lms_chat_openai()] has no
#'   such argument. A `previous_response_id` in its `...` goes into the
#'   request body unchecked, and the endpoint ignores it.
#' @return If \code{simplify = FALSE}, returns a list representing the raw JSON
#'   response. A status-200 body that does not parse as JSON raises
#'   `rlmstudio_bad_response` with either setting of `simplify`. The body can
#'   hold a `response_id` for the reply and a `stats`
#'   object of token counts and timings. With `api_type = "native"` and
#'   `format = "data.frame"`, [lms_chat_batch()] returns the id and six of
#'   the `stats` fields as columns. If \code{simplify = TRUE},
#'   returns one character string: the
#'   `content` of every item of type `"message"` in the `output` array, pasted
#'   together in order with no separator. Items of other types, such as
#'   reasoning and tool calls, are skipped. A reply with no readable answer
#'   text raises `rlmstudio_bad_response`, as described below.
#'
#'   With `simplify = TRUE`, the string carries the `response_id` field of the
#'   reply in a `response_id` attribute. Pass it as `previous_response_id` to
#'   continue the thread. The string has no attribute when `response_id` is
#'   absent or is not one string. A reply sent with `store = FALSE` in `...`
#'   carries no `response_id`, so its string has no attribute.
#'   [lms_chat_openresponses()] reads the attribute from the `id` field of its
#'   reply instead. An OpenResponses reply sent with `store = FALSE` still
#'   carries an `id`, so its value still carries the attribute.
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
  previous_response_id = NULL,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_no_na(input, "input")
  rlm_check_flag(simplify, "simplify")
  rlm_check_response_id(previous_response_id)
  dots <- list(...)
  rlm_check_stream(dots)
  # The endpoint has no logprobs, so each element named exactly `logprobs` is
  # checked as a flag and then dropped (D-029).
  # `%in%` over `names()` would give a length-0 result for unnamed dots.
  is_logprobs <- vapply(
    seq_along(dots),
    function(i) identical(names(dots)[i], "logprobs"),
    logical(1)
  )
  for (value in dots[is_logprobs]) {
    rlm_check_flag(value, "logprobs", null_ok = TRUE)
  }

  stop_if_no_server(host)

  body <- list(
    model = model,
    input = input,
    system_prompt = system_prompt,
    previous_response_id = previous_response_id
  )
  body <- Filter(Negate(is.null), body)

  if (any(vapply(dots[is_logprobs], isTRUE, logical(1)))) {
    cli::cli_warn(
      "The native API does not support logprobs. Ignoring argument."
    )
  }
  body <- utils::modifyList(body, dots[!is_logprobs])

  req <- lms_client(host, token = token) |>
    httr2::req_url_path("api/v1/chat") |>
    rlm_req_body(body) |>
    httr2::req_error(is_error = \(resp) FALSE)
  resp <- httr2::req_perform(req)

  if (httr2::resp_status(resp) == 200) {
    resp_data <- parse_ok_body(resp, "Native API Failed")
    if (!isTRUE(simplify)) {
      return(resp_data)
    }
    return(with_response_id(
      native_reply_text(resp, resp_data),
      resp_data[["response_id"]]
    ))
  }

  rlm_abort_api(resp, "Native API Failed", request_sends_token(req))
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

# The column type that each JSON Schema `type` gives a property column of a
# data-frame batch. Any other `type` gives a list-column.
schema_column_types <- c(
  string = "character",
  integer = "integer",
  number = "double",
  boolean = "logical"
)

#' Read the property columns that a schema adds to a data-frame batch
#'
#' An object schema has a `type` of `"object"`, as a string or as a list that
#' holds that one string, and a `properties` list of one or more entries with
#' a names attribute. Only the top-level properties get columns. The columns
#' come from the schema and not from the replies, so they are there even when
#' every input failed (D-027).
#'
#' @param schema The value the caller passed as `schema`, already checked by
#'   `rlm_check_schema()`.
#' @return `NULL` for a schema that is not an object schema. Otherwise a
#'   character vector named by the properties, in their order, that holds
#'   each column type: `"character"`, `"integer"`, `"double"`, `"logical"`,
#'   or `"list"`. A name can be empty or `NA`, which the caller checks.
#'
#' @noRd
schema_property_columns <- function(schema) {
  if (!is.list(schema) || !identical(one_schema_type(schema[["type"]]), "object")) {
    return(NULL)
  }
  properties <- schema[["properties"]]
  if (!is.list(properties) || length(properties) == 0L || is.null(names(properties))) {
    return(NULL)
  }
  types <- vapply(properties, property_column_type, character(1), USE.NAMES = FALSE)
  names(types) <- names(properties)
  types
}

# One type name, written as a string or as a list that holds that one string,
# or NULL for any other value.
one_schema_type <- function(x) {
  if (is.list(x) && length(x) == 1L) {
    x <- x[[1L]]
  }
  if (is_one_string(x)) x else NULL
}

# The column type of one schema property. A type paired with "null" gives the
# column type of that type, because the cell of a null field is NA anyway.
property_column_type <- function(property) {
  if (!is.list(property)) {
    return("list")
  }
  type <- property[["type"]]
  one <- one_schema_type(type)
  is_pair <- (is.character(type) || is.list(type)) &&
    length(type) == 2L &&
    all(vapply(type, is_one_string, logical(1)))
  if (is.null(one) && is_pair) {
    parts <- unlist(type, use.names = FALSE)
    if (sum(parts == "null") == 1L) {
      one <- parts[parts != "null"]
    }
  }
  if (!is.null(one) && one %in% names(schema_column_types)) {
    schema_column_types[[one]]
  } else {
    "list"
  }
}

#' Read one property cell of a data-frame batch
#'
#' A cell of an atomic column holds the field when it is one value of the
#' column type, and `NA` otherwise. The `output` column keeps the parsed
#' reply, so a value that does not fit is not lost and gives no warning, as
#' for the reply columns (D-013). A cell of a list-column holds the field as
#' parsed, or `NULL` when the field is absent or `null`. The field is read
#' with `[[`, because `$` would read a field whose name only starts with the
#' one asked for.
#'
#' @param result One element of the batch results: a parsed reply, or the
#'   condition of a failed input.
#' @param name Character. The property name.
#' @param type Character. The column type from `schema_property_columns()`.
#' @return One value of the column type, or any value for a list-column.
#'
#' @noRd
schema_property_cell <- function(result, name, type) {
  # A JSON array of objects parses to a data frame, and a failed input holds
  # a condition. Both are named lists with a class, and neither is a reply
  # object. A parsed JSON object has no class.
  field <- if (is_json_object(result) && !is.object(result)) {
    result[[name]]
  }
  switch(
    type,
    character = string_or_na(field),
    integer = integer_or_na(field),
    double = number_or_na(field),
    logical = if (is.logical(field) && length(field) == 1L) field else NA,
    list = field
  )
}

# One integer, or a whole double in the integer range, else NA. The range
# leaves out -2147483648, which R uses for NA_integer_.
integer_or_na <- function(x) {
  if (is.integer(x) && length(x) == 1L) {
    return(x)
  }
  whole <- is.double(x) &&
    length(x) == 1L &&
    is.finite(x) &&
    x == trunc(x) &&
    abs(x) <= .Machine$integer.max
  if (whole) as.integer(x) else NA_integer_
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
#' @param simplify `TRUE` or `FALSE`. If `TRUE`, parses outputs. Any other
#'   value, `NULL` and `NA` included, aborts before the check for a running
#'   server.
#' @param quiet `TRUE`, `FALSE`, or `NULL`, the default. `NULL` follows the
#'   `rlmstudio.quiet` option. `TRUE` starts no progress bar, and `FALSE`
#'   starts one, also when the option is `TRUE`. cli draws a started bar only
#'   after a delay, two seconds by default. Any other value, `NA` included,
#'   aborts before the check for a running server. `quiet` does not hide the
#'   warnings about failed inputs, cut-off replies, a vector format that
#'   returns a list, or a `logprobs = TRUE` that the `"native"` route ignores.
#' @param ... Additional arguments passed to `lms_chat`, such as `api_type`,
#'   `logprobs`, `schema`, `ttl`, or `previous_response_id`. A `schema`, a
#'   `ttl`, a `previous_response_id`, and the `api_type` that each needs are
#'   checked before the first call. A `previous_response_id` goes to every
#'   call, so each input continues the same stored reply.
#'   A `logprobs` here, or a shortened name that [lms_chat()] reads as
#'   `logprobs`, must be `TRUE` or `FALSE`. Any other value, `NULL` and `NA`
#'   included, aborts before the check for a running server.
#'   With `api_type = "native"`, which has no logprobs, a `logprobs` of
#'   `TRUE` is ignored. The batch then returns what it returns with
#'   `logprobs = FALSE`, in each format. It gives one warning for the whole
#'   batch, after the check for a running server, even with `quiet = TRUE`.
#'   Two values here that [lms_chat()] reads as the same argument abort
#'   with a message that names the argument. Examples are
#'   `logprobs = TRUE, logprobs = FALSE`, the shortened names
#'   `log = TRUE, lo = FALSE`, and two `previous_response_id` values. An
#'   exact name and a shortened name, such as `logprobs` and `log`, do not
#'   abort, because R gives the shortened one to the `...` of [lms_chat()].
#'   An `input` here also aborts, because the batch passes each element of
#'   `inputs` as `input`. An `input` reaches `...` only when `inputs` is
#'   given by its full name. Otherwise R reads `input` as a shortened
#'   `inputs`, so it becomes `inputs`, and the value given by position fills
#'   the next unnamed argument, such as `system_prompt`. These aborts come
#'   before every other check of `...` and before the check for a running
#'   server.
#'   The package checks a `stream` here. A `stream` other than `FALSE` or
#'   `NULL` aborts before the call checks for a running server, because the
#'   package reads a whole reply and not a streamed one.
#' @return The return type depends on the \code{format} argument:
#' \itemize{
#'   \item \code{"vector"}: A character vector of responses, with \code{NA} for an input that failed. This format is only supported if \code{simplify = TRUE}, and \code{logprobs = FALSE} or \code{api_type = "native"}. With a \code{schema}, it warns and returns the list instead.
#'   \item \code{"list"}: A list where each element is the response corresponding to the provided input, or the condition for an input that failed. With a \code{schema}, \code{simplify = TRUE}, and \code{logprobs = FALSE}, each element that did not fail is the parsed reply.
#'   \item \code{"data.frame"}: A data.frame containing \code{input} and \code{output} columns, with \code{NA} in \code{output} for an input that failed. If \code{logprobs = TRUE} on the \code{"openresponses"} or \code{"openai"} route, an additional list-column named \code{logprobs} is included, with \code{NULL} for an input that failed. The \code{"native"} route adds no \code{logprobs} column. With a \code{schema} and \code{logprobs = FALSE}, \code{output} is a list-column of parsed replies, with the condition in place of an input that failed. Columns read from each reply follow \code{output}, or \code{logprobs} when it is there, as described below. With an object \code{schema} and \code{logprobs = FALSE}, one column per schema property comes after them, as described below.
#' }
#'
#' On the native and OpenResponses routes with `simplify = TRUE`, [lms_chat()]
#' returns each reply that carries an id with a `response_id` attribute, as
#' its help describes. With `format = "list"`, each reply keeps
#' it. So does each element of the list that `format = "vector"` returns with
#' `logprobs = TRUE` on the OpenResponses route. The character vector of
#' `format = "vector"` and the `output` column of `format = "data.frame"`
#' carry no `response_id` attribute. The data frame holds the ids in its
#' `response_id` column.
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
#' With `api_type = "openresponses"` or `api_type = "openai"` and
#' `format = "data.frame"`, the data frame has four columns read from each
#' reply after `output`, or after `logprobs` when it is there. They are
#' `response_id`, `input_tokens`, `total_output_tokens`, and
#' `reasoning_output_tokens`. These are the first four native column names,
#' but the servers send the values under other names:
#' \itemize{
#'   \item `response_id` is the reply's `id` on both routes.
#'   \item `input_tokens` is `usage.input_tokens` on the OpenResponses route
#'     and `usage.prompt_tokens` on the OpenAI route.
#'   \item `total_output_tokens` is `usage.output_tokens` on the OpenResponses
#'     route and `usage.completion_tokens` on the OpenAI route.
#'   \item `reasoning_output_tokens` is
#'     `usage.output_tokens_details.reasoning_tokens` on the OpenResponses
#'     route and `usage.completion_tokens_details.reasoning_tokens` on the
#'     OpenAI route.
#' }
#' The columns are there for every setting of `logprobs` and `schema`.
#' `response_id` is character, and the three counts are double. The `NA`
#' rule is the one for the native columns: a cell is `NA` when its field is
#' absent or is not one value of the column type, and an empty string is
#' kept. If `usage` is absent or is not a JSON object, all three count cells
#' are `NA`. If the details object is absent or is not a JSON object, only
#' `reasoning_output_tokens` is `NA`. Such a cell does not fail the input and
#' gives no warning.
#'
#' A reply with no readable answer text fails its input, whatever its other
#' fields hold. The row of an input that failed holds `NA` in every column
#' read from the reply. If every input failed, those columns are still there,
#' `response_id` as character and the others as double. The vector and list
#' formats add no such column.
#'
#' With `api_type = "openai"`, `format = "data.frame"`, `logprobs = FALSE`,
#' and an object `schema`, the data frame ends with one column per top-level
#' property of the schema, after the four reply columns. An object schema has
#' a `type` of `"object"`, written as a string or as a list that holds that
#' one string. Its `properties` is a list of one or more named entries. Each
#' column has the property name, in the order of `properties`. The columns
#' come from the schema and not from the replies, so they are there even when
#' every input failed. The properties of a nested object get no columns of
#' their own. Any other schema adds no column.
#'
#' The type of a property column follows the `type` of the property.
#' `"string"` gives character, `"integer"` gives integer, `"number"` gives
#' double, and `"boolean"` gives logical. Each type can be a string or a list
#' that holds that one string. A pair of one of these types and `"null"`,
#' such as `c("integer", "null")`, gives the same column type. Any other
#' `type`, no `type`, or a property that is not a list gives a list-column.
#'
#' A cell of a character, integer, double, or logical property column holds
#' the field of the parsed reply when the field is one value of the column
#' type. A one-item JSON array counts as one value, and an empty string is
#' kept. A double column takes any number. An integer column takes an integer,
#' or a whole number from -2147483647 to 2147483647. Otherwise the cell is
#' `NA`, and the call gives no warning. The `output` column keeps the parsed
#' reply, with the value that did not fit. A cell of a list-column holds the
#' field as parsed, or `NULL` when the field is absent or `null`. A reply that
#' is not a JSON object, such as an array or a number, gives `NA` and `NULL`
#' cells. So does the row of an input that failed.
#'
#' A property name that is empty, `NA`, repeated, or equal to another column
#' name aborts before the call checks for a running server. The other column
#' names are `input`, `output`, `response_id`, `input_tokens`,
#' `total_output_tokens`, and `reasoning_output_tokens`. A data frame with
#' `logprobs = TRUE`, and the list and vector formats, do not check the names.
#' @details
#' This function calls [lms_chat()] once for each element of `inputs`. It
#' raises `rlmstudio_no_server` itself, before the first call.
#'
#' An `rlmstudio_bad_response` that [lms_chat()] raises for one input fails
#' that input alone, unless it is an `rlmstudio_model_mismatch`. So does an
#' `rlmstudio_api_error` with any `status` other than 401, 403, or 404,
#' unless its `status` is 400 and its `code` is `"model_not_found"`. The batch
#' goes on to the next input. Where the
#' result is a list, or the `output` list-column that a `schema` gives, the
#' element for that input holds the condition without its backtrace. An
#' `rlmstudio_bad_response` for reply content that does not
#' parse keeps that content in its `content` field. Where the result is text,
#' the element holds `NA`. The result is text with `format = "vector"` when it
#' returns a vector (`simplify = TRUE`, no `schema`, and `logprobs = FALSE`
#' or the native route), and with a data frame whose replies are not parsed
#' (no `schema`, or `logprobs = TRUE`). On the OpenResponses and OpenAI
#' routes, the `logprobs` column holds `NULL` for a failed input.
#' A reply with no readable answer text, such as one whose content is `null`,
#' fails as an `rlmstudio_bad_response` in the same way. So does a
#' status-200 body that does not parse as JSON, such as an HTML page from a
#' proxy or an empty body. That input fails alone, and the other elements
#' keep their replies. Use `format = "list"`
#' to keep the conditions. The call gives one warning that names the count
#' and the positions of the failed inputs. That warning shows even with
#' `quiet = TRUE`.
#'
#' An `rlmstudio_api_error` with `status` 401, 403, or 404 aborts the batch
#' with that condition, and no request goes out after that input. Such a
#' status comes from a fault that does not depend on the prompt, such as a
#' token that the server refuses, so every later input fails in the same
#' way. The condition carries a `results` field, as described in the "API
#' failure" section below. No warning about failed inputs is given.
#'
#' The batch aborts in the same way at an `rlmstudio_api_error` with `status`
#' 400 and the `code` `"model_not_found"`, and at an
#' `rlmstudio_model_mismatch`. The `"openai"` and `"openresponses"` routes
#' give these for a model name that the server cannot find, so every later
#' input fails in the same way.
#' See the "Reply from another model" section below.
#'
#' A `previous_response_id` that the server does not hold gives status 400
#' with the `code` `"invalid_value"` on the native route and
#' `"previous_response_not_found"` on the OpenResponses route. The batch does
#' not abort at either one. Each such input fails alone, as described above,
#' and the batch goes on to the next input.
#'
#' An `rlmstudio_no_server` from [lms_chat()] also aborts the batch. Its
#' `results` field holds the results so far, as described in the "Server not
#' running" section below. An error of any other class aborts the batch
#' unchanged.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @inheritSection rlmstudio-conditions Cut-off reply
#' @inheritSection rlmstudio-conditions Reply from another model
#' @export
lms_chat_batch <- function(
  model,
  inputs,
  system_prompt = NULL,
  format = c("vector", "list", "data.frame"),
  host = "http://localhost:1234",
  simplify = TRUE,
  quiet = NULL,
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
  ttl <- args[["ttl"]]
  rlm_check_ttl(ttl)
  rlm_check_ttl_route(ttl, api_type)
  previous_response_id <- args[["previous_response_id"]]
  rlm_check_response_id(previous_response_id)
  rlm_check_thread_route(previous_response_id, api_type)
  # The raw dots, because `args` keeps only the first of two same-named
  # values. No `lms_chat()` argument starts with `stream`, so the names match.
  rlm_check_stream(list(...))
  rlm_check_flag(simplify, "simplify")
  rlm_check_flag(quiet, "quiet", null_ok = TRUE)
  # A name test, not `args[["logprobs"]]`, which is `NULL` for an absent name
  # and for a `logprobs = NULL` alike. `lms_chat()` refuses `NULL` there.
  if ("logprobs" %in% names(args)) {
    rlm_check_flag(args[["logprobs"]], "logprobs")
  }

  # An argument fault, so it aborts before the server probe (D-008) and before
  # any request is sent.
  format <- match.arg(format)
  if (format == "data.frame" && !isTRUE(simplify)) {
    cli::cli_abort(
      "The {.val data.frame} format requires {.code simplify = TRUE}.",
      call = NULL
    )
  }

  # The native route has no logprobs, so the batch treats the flag as off
  # there and returns what `logprobs = FALSE` returns. It warns once for the
  # batch, not once per input, and it sends each call `logprobs = FALSE`, so
  # `lms_chat()` does not warn as well. The dot keeps its name and place, so
  # no other dot moves into the `logprobs` of `lms_chat()`.
  native_logprobs <- api_type == "native" && isTRUE(args[["logprobs"]])
  chat_dots <- list(...)
  if (native_logprobs) {
    chat_dots[[rlm_dot_filling(chat_dots, "logprobs")]] <- FALSE
  }
  has_logprobs <- isTRUE(args[["logprobs"]]) && !native_logprobs
  # A data frame of parsed replies adds one column per schema property
  # (D-027). A data frame with logprobs holds text replies, so it adds none.
  property_columns <- if (format == "data.frame" && !has_logprobs) {
    schema_property_columns(schema)
  }
  rlm_check_property_names(names(property_columns))

  stop_if_no_server(host)

  # After the server probe, so a batch that cannot run gives no warning.
  # Shown whatever `quiet` says, because it is the only sign that the
  # logprobs asked for are missing (D-032).
  if (native_logprobs) {
    cli::cli_warn(
      "The 'native' API type does not support logprobs. Ignoring argument."
    )
  }

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

  # A failed input loses its own answer, not the whole batch, unless the
  # failure holds for every input (see `keep_or_abort_api()` below). Its slot
  # keeps the condition, and an `rlmstudio_bad_response` carries the reply
  # content.
  # Every other error still aborts, because it says nothing about one input
  # alone. The backtrace is dropped, because it makes each failed slot large
  # and says nothing about the input.
  keep_failure <- function(cnd) {
    cnd$trace <- NULL
    cnd
  }
  # A lost server fails every later input, so it still aborts (GP3). The
  # condition carries the results so far, so a long batch does not lose them.
  # Slots from the lost input on stay NULL. The results can hold replies that
  # a length limit cut off, so the batch names them before it aborts.
  abort_with_results <- function(cnd) {
    cnd$results <- results
    warn_cut_off_inputs()
    stop(cnd)
  }
  # A refused token or a model the server cannot find fails every input the
  # same way, whatever the prompt, so these statuses abort like a lost server
  # (D-019). The OpenAI and OpenResponses routes answered a model they could
  # not find with status 400 and the code "model_not_found" when two chat
  # models were loaded (D-025). Any other status can come from one prompt, so
  # it fails that input alone.
  keep_or_abort_api <- function(cnd) {
    if (
      isTRUE(cnd[["status"]] %in% c(401L, 403L, 404L)) ||
        (identical(cnd[["status"]], 400L) &&
          identical(cnd[["code"]], "model_not_found"))
    ) {
      abort_with_results(cnd)
    }
    keep_failure(cnd)
  }
  # A reply from another model means that the wrong model answers every
  # input, so it aborts (D-025). The test sits in this handler and not in a
  # handler of its own, because `tryCatch()` runs a handler inside the
  # handlers named after it. The condition that such a handler raises again
  # would reach this one and be kept.
  keep_or_abort_bad <- function(cnd) {
    if (inherits(cnd, "rlmstudio_model_mismatch")) {
      abort_with_results(cnd)
    }
    keep_failure(cnd)
  }
  results <- vector("list", length(inputs))
  names(results) <- names(inputs)
  # A data frame also returns the reply id and the token counts of each reply
  # (D-013, D-014), so it asks for the body and reads the answer out of it
  # here. The answer is read by the helper the single call uses, so a reply
  # fails the same way. `results` still holds what `simplify = TRUE` returns,
  # so the `results` field of an abort does not depend on the format.
  body_frame <- format == "data.frame"
  reply_fields <- vector("list", length(inputs))
  # The single calls return the body only for status 200, so the abort a bad
  # body raises carries that status.
  ok_resp <- httr2::response(status_code = 200L)
  # The value carries the reply id as the single call's does, so `results`
  # holds the same values in every format (D-030). The data frame drops the
  # attribute when it builds its `output` column.
  read_reply <- function(body) {
    value <- switch(
      api_type,
      native = with_response_id(
        native_reply_text(ok_resp, body),
        body[["response_id"]]
      ),
      openresponses = with_response_id(
        responses_reply_value(ok_resp, body, has_logprobs),
        body[["id"]]
      ),
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
  # The positions of replies that a length limit cut off. Each input's own
  # warning is muffled here, and the batch gives one warning for all of them
  # below (D-021). The handler covers `read_reply()` too, because the
  # data-frame format reads the answer after `lms_chat()` returns.
  # `tryCatch()` lets a warning through, so the handler sits inside it.
  cut_off <- integer()
  note_cut_off <- function(w) {
    cut_off[[length(cut_off) + 1L]] <<- i
    invokeRestart("muffleWarning")
  }
  # Shown whatever `quiet` says, because it is the only sign that some
  # answers are not complete (D-021). A class of its own, apart from the
  # failed-inputs warning, so a caller can tell the two faults apart.
  warn_cut_off_inputs <- function() {
    if (length(cut_off) == 0L) {
      return(invisible())
    }
    positions <- cli::ansi_collapse(cut_off, trunc = Inf)
    cli::cli_warn(
      c(
        "A length limit ended the reply to {length(cut_off)} input{?s} before it was complete, at {cli::qty(length(cut_off))}position{?s} {positions}.",
        "i" = "Each of those elements keeps the reply as far as it goes. The limit is {.code max_tokens} or the context length of the model. Raise the one that is too low."
      ),
      class = "rlmstudio_reply_cut_off"
    )
  }
  # The dots go through `chat_dots`, where the native route has set the dot
  # that fills `logprobs` to `FALSE` above.
  # `simplify` comes after `...`, so only its exact name matches it, and
  # `quote = TRUE` passes a dot that holds a call or a symbol as it is.
  chat_once <- function(..., simplify) {
    lms_chat(
      model = model,
      input = inputs[[i]],
      system_prompt = system_prompt,
      host = host,
      simplify = simplify,
      ...,
      token = token
    )
  }
  for (i in seq_along(inputs)) {
    res <- tryCatch(
      withCallingHandlers(
        if (body_frame) {
          body <- do.call(
            chat_once,
            c(chat_dots, list(simplify = FALSE)),
            quote = TRUE
          )
          read <- read_reply(body)
          reply_fields[[i]] <- read$fields
          read$value
        } else {
          do.call(
            chat_once,
            c(chat_dots, list(simplify = simplify)),
            quote = TRUE
          )
        },
        rlmstudio_reply_cut_off = note_cut_off
      ),
      rlmstudio_api_error = keep_or_abort_api,
      rlmstudio_bad_response = keep_or_abort_bad,
      rlmstudio_no_server = abort_with_results
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

  warn_cut_off_inputs()

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

  # Keyed on the schema, not on the replies, so the columns and their types
  # are there even when every input failed (D-027).
  add_property_columns <- function(df) {
    for (name in names(property_columns)) {
      type <- property_columns[[name]]
      df[[name]] <- if (type == "list") {
        lapply(results, schema_property_cell, name = name, type = type)
      } else {
        vapply(
          results,
          schema_property_cell,
          vector(type, 1L),
          name = name,
          type = type,
          USE.NAMES = FALSE
        )
      }
    }
    df
  }

  if (format == "data.frame") {
    if (has_parsed) {
      df <- data.frame(input = inputs, stringsAsFactors = FALSE)
      df$output <- results
      return(add_property_columns(add_reply_columns(df)))
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
#' Two dots that reach the same `lms_chat()` argument abort here, before
#' `match.call()` would fail with a base R error.
#'
#' @param dots The list of `...` values.
#' @return `dots`, with each name replaced by the `lms_chat()` argument it
#'   matches.
#' @noRd
rlm_chat_dots <- function(dots) {
  rlm_check_chat_dots_once(dots)
  placeholders <- vector("list", length(batch_chat_args))
  names(placeholders) <- batch_chat_args
  call <- as.call(c(list(quote(lms_chat)), placeholders, dots))
  matched <- as.list(match.call(lms_chat, call))[-1]
  matched[setdiff(names(matched), batch_chat_args)]
}

# The `lms_chat()` arguments that `lms_chat_batch()` passes by name.
batch_chat_args <- c(
  "model",
  "input",
  "system_prompt",
  "host",
  "simplify",
  "token"
)

#' Which dot of lms_chat_batch() fills one lms_chat() argument?
#'
#' Runs R's own argument matching over the call that `lms_chat_batch()` makes,
#' with each dot replaced by its position. So a dot counts whether it fills
#' the argument by its exact name, a shortened name, or its position. Call it
#' after `rlm_check_chat_dots_once()`, because two dots for one argument make
#' `match.call()` fail.
#'
#' @param dots The list of `...` values.
#' @param arg The name of an `lms_chat()` argument.
#' @return The position in `dots` of the dot that fills `arg`, or `NULL` when
#'   no dot fills it.
#' @noRd
rlm_dot_filling <- function(dots, arg) {
  placeholders <- vector("list", length(batch_chat_args))
  names(placeholders) <- batch_chat_args
  positions <- as.list(seq_along(dots))
  names(positions) <- names(dots)
  call <- as.call(c(list(quote(lms_chat)), placeholders, positions))
  match.call(lms_chat, call)[[arg]]
}

#' Which lms_chat() argument does each dot of lms_chat_batch() reach?
#'
#' Each named dot is matched alone, beside the arguments that
#' `lms_chat_batch()` passes by name, so R's own rules say which `lms_chat()`
#' argument it reaches. R matches exact names before shortened ones, so the
#' arguments that some dot names exactly are held as placeholders too. A
#' shortened name then falls through to the `...` of `lms_chat()`, as in the
#' real call. A dot that reaches no argument goes to that `...`. A dot named
#' as one of the passed arguments collides with it. Of those, only `input`
#' can be a dot, because the others are formals of `lms_chat_batch()`. An
#' unnamed dot fills an argument that nothing else matched, so it reaches
#' none here.
#'
#' @param dots The list of `...` values.
#' @return A character vector as long as `dots`: the argument each dot
#'   reaches, or `NA` for a dot that goes to the `...` of `lms_chat()` or has
#'   no name.
#' @noRd
rlm_dots_reached <- function(dots) {
  reached <- rep(NA_character_, length(dots))
  nms <- names(dots)
  if (is.null(nms)) {
    return(reached)
  }
  arguments <- setdiff(names(formals(lms_chat)), "...")
  named <- !is.na(nms) & nzchar(nms)
  exact <- named & nms %in% c(batch_chat_args, arguments)
  reached[exact] <- nms[exact]
  # Every argument some dot names exactly, so a shortened name skips it.
  held <- unique(c(batch_chat_args, nms[exact]))
  holders <- vector("list", length(held))
  names(holders) <- held
  for (i in which(named & !exact)) {
    call <- as.call(c(list(quote(lms_chat)), holders, dots[i]))
    name <- setdiff(names(as.list(match.call(lms_chat, call))[-1]), held)
    if (name %in% arguments) {
      reached[[i]] <- name
    }
  }
  reached
}

#' Abort when two dots of lms_chat_batch() reach one lms_chat() argument
#'
#' R would fail in `match.call()` or in the call itself with a base R error.
#' This names the argument instead.
#'
#' @param dots The list of `...` values.
#' @return `dots`, invisibly.
#' @noRd
rlm_check_chat_dots_once <- function(dots) {
  nms <- names(dots)
  reached <- rlm_dots_reached(dots)
  for (arg in unique(reached[!is.na(reached)])) {
    given <- nms[!is.na(reached) & reached == arg]
    if (arg %in% batch_chat_args) {
      cli::cli_abort(
        c(
          "{.arg {arg}} is given more than once.",
          "x" = "{.fn lms_chat_batch} passes each element of {.arg inputs} to {.fn lms_chat} as {.arg {arg}}, so {.arg ...} cannot hold an {.arg {arg}}."
        ),
        call = NULL
      )
    }
    if (length(given) > 1L) {
      cli::cli_abort(
        c(
          "{.arg {arg}} is given more than once.",
          "x" = "{.arg ...} holds {length(given)} values that {.fn lms_chat} reads as {.arg {arg}}: {.arg {given}}."
        ),
        call = NULL
      )
    }
  }
  invisible(dots)
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

#' Write a request body as JSON
#'
#' Each function that sends a JSON body writes it here, and the `messages`
#' trial write in `messages_write_fault()` writes through the same function.
#' The options are the defaults of the httr2 JSON body helper. The trial write
#' and the sent body therefore use one writer with one set of options, so a
#' `messages` value that passes the trial write is sent as jsonlite writes it.
#'
#' @param x The body, or the value to try.
#' @return The JSON text, as a character string.
#'
#' @noRd
rlm_json_text <- function(x) {
  as.character(jsonlite::toJSON(
    x,
    auto_unbox = TRUE,
    digits = 22,
    null = "null"
  ))
}

#' Attach a JSON body to a request
#'
#' The body is written once by `rlm_json_text()`, and the request sends that
#' text. The httr2 JSON body helper is not used, because httr2 1.3.0 rebuilds
#' each list in the body before it writes it, with `x[] <- lapply(x, ...)`.
#' On a data frame, that turns a zero-width matrix or array column into `NA`
#' and a 2-by-0 list matrix column into a list of `NULL` cells, sent as
#' `null`. On a `POSIXlt` value, it recurses
#' with no end. The rebuild exists to reveal `httr2::obfuscated()` values,
#' which jsonlite cannot write, so such a value in `...` now fails with the
#' jsonlite error.
#'
#' @param req An httr2 request.
#' @param body The body, a list.
#' @return `req` with the body attached.
#'
#' @noRd
rlm_req_body <- function(req, body) {
  httr2::req_body_raw(req, rlm_json_text(body), type = "application/json")
}
