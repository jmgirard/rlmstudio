#' Turn Text into Embedding Vectors
#'
#' Sends one or more texts to an embedding model and returns the vector that
#' the model produced for each one. The whole input vector travels in a single
#' request.
#'
#' @param model Character. The loaded embedding model name. Must be one name,
#'   given as a single string.
#' @param input Character. The texts to embed. A vector of length `n` returns
#'   `n` embeddings, in the order given. Must hold at least one value and no
#'   missing values.
#' @param host Character. Server URL.
#' @param simplify Logical. If `TRUE`, the default, returns a numeric matrix
#'   with one row per input. Any other value returns the parsed response body
#'   unchanged.
#' @param ... Additional fields for the request body. LM Studio ignores a
#'   field it does not recognize, and two OpenAI fields are worth naming for
#'   that reason: LM Studio ignores `dimensions`, so asking for a narrower
#'   vector has no effect. `encoding_format = "base64"` is untested against LM
#'   Studio: a server that honors it returns embeddings this function cannot
#'   read, and the default `simplify = TRUE` path then aborts.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @return If `simplify = FALSE`, a list representing the raw JSON response.
#'   Otherwise, a double matrix with one row per input text and one column per
#'   embedding dimension. The row at position `i` holds the embedding that the
#'   response reported for the input at position `i`. The matrix carries no
#'   row or column names.
#' @inheritSection rlmstudio-conditions Server not running
#' @inheritSection rlmstudio-conditions API failure
#' @inheritSection rlmstudio-conditions Malformed response
#' @export
#' @examples
#' \dontrun{
#' vectors <- lms_embed(
#'   model = "text-embedding-nomic-embed-text-v1.5",
#'   input = c("the first document", "the second document")
#' )
#' dim(vectors)
#' }
lms_embed <- function(
  model,
  input,
  host = "http://localhost:1234",
  simplify = TRUE,
  ...,
  token = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_text(input, "input")

  stop_if_no_server(host)

  # as.list() is what keeps a single input an array of one rather than a bare
  # string: jsonlite serializes an unnamed list as a JSON array whatever its
  # length, while auto-unboxing would turn a length-one character vector into
  # a scalar. unname() is what keeps the list unnamed: as.list() carries the
  # vector's names over, and jsonlite writes a named list as a JSON object.
  # `setNames(df$text, df$id)` is an ordinary way to reach this function.
  body <- list(model = model, input = as.list(unname(input)))
  body <- utils::modifyList(body, list(...))

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path("v1/embeddings") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200) {
    rlm_abort_api(resp, "Embeddings Failed", !is.null(rlm_token(token)))
  }

  # A 200 whose body is not JSON at all reaches here: a proxy or a captive
  # portal answering on the host serves an HTML page under a success status.
  # Left unguarded, httr2 or the jsonlite lexer raises an unclassed error, so
  # the fault the whole check exists to name escapes it on a technicality.
  # `simplify = FALSE` cannot rescue this one, because the parse runs first,
  # so the hint says something the caller can act on instead.
  #
  # `check_type = FALSE` is what keeps that message true. Left on, the same
  # error covers two different causes: a body that will not parse, and a body
  # that parses perfectly under a content type httr2 declines to read. A proxy
  # that rewrites the header to `text/plain` sends good JSON, and reporting
  # that as a parse failure names the wrong fault and leaves no way through.
  # Parsing by content rather than by header leaves the parse failure as the
  # only cause this branch can have.
  resp_data <- tryCatch(
    httr2::resp_body_json(resp, check_type = FALSE),
    error = function(cnd) {
      rlm_abort_bad_response(
        resp,
        "Embeddings Failed",
        "the response body did not parse as JSON.",
        hint = paste(
          "The server returned a response this package cannot read.",
          "Something other than LM Studio may be answering on this host."
        )
      )
    }
  )

  if (!isTRUE(simplify)) {
    return(resp_data)
  }

  # The count comes from the body that was actually sent rather than from the
  # `input` argument. R rejects a call that names `input` twice, so today the
  # two are always the same length; reading the body keeps them the same if a
  # later change ever puts the inputs together some other way.
  embed_matrix(resp_data, length(body[["input"]]), resp)
}

#' Is this value one number?
#'
#' `httr2::resp_body_json()` parses with `simplifyVector = FALSE` (LESSONS,
#' M005), so every number in the body arrives as a length-one numeric and a
#' JSON `null` arrives as `NULL`. A logical passes `is.numeric()` nowhere, and
#' a base64 string fails on the type.
#'
#' @param x Any value read out of a parsed response body.
#' @return `TRUE` when `x` is one number that is not `NA`.
#'
#' @noRd
is_one_number <- function(x) {
  is.numeric(x) && length(x) == 1L && !is.na(x)
}

#' Did this value parse from a JSON object?
#'
#' A JSON object parses to a named list, a JSON array to an unnamed one, and
#' anything else to an atomic value. The distinction matters because `[[` on
#' an atomic value is an error rather than a missing field.
#'
#' @param x Any value read out of a parsed response body.
#' @return `TRUE` when `x` parsed from a JSON object.
#'
#' @noRd
is_json_object <- function(x) {
  is.list(x) && !is.null(names(x))
}

#' Read one named field out of a parsed JSON object
#'
#' `$` on a list partial-matches, so `body$data` reads a `database` field when
#' no `data` field exists, and `$` on an atomic value is an error rather than
#' a missing field. This reads the exact name and returns `NULL` for anything
#' the name does not reach.
#'
#' @param x Any value read out of a parsed response body.
#' @param name Character. The exact field name.
#' @return The field, or `NULL`.
#'
#' @noRd
json_field <- function(x, name) {
  if (is_json_object(x) && name %in% names(x)) x[[name]] else NULL
}

#' Check the data block of an embeddings response and build the matrix
#'
#' Reads the `data` block of a parsed `/v1/embeddings` body and returns a
#' double matrix with one row per input. Every condition below aborts with
#' class `rlmstudio_bad_response` rather than building a matrix, because a
#' block whose indexes are missing, repeated, or out of range would otherwise
#' pair a vector with the wrong text and corrupt a whole batch without a
#' message.
#'
#' The rows are placed by the `index` field of each element rather than by
#' arrival order, so a server that answers out of order still pairs each
#' vector with its own text.
#'
#' @param resp_data List. The parsed response body.
#' @param n Integer. How many texts the request asked the server to embed.
#' @param resp The httr2 response, which carries the status the condition
#'   reports.
#' @return A double matrix of `n` rows and one column per embedding dimension.
#'
#' @noRd
embed_matrix <- function(resp_data, n, resp) {
  # Resolve the detail here rather than in the abort helper. cli interpolates
  # the braces of the string it is handed, and not the braces of a value
  # spliced into it, so a detail built in this frame has to be formatted in
  # this frame or it reaches the user with its braces intact.
  fail <- function(detail) {
    rlm_abort_bad_response(
      resp,
      "Embeddings Failed",
      cli::format_inline(detail, .envir = parent.frame())
    )
  }

  if (!is.list(resp_data)) {
    fail("the response body is not a JSON object.")
  }

  data <- json_field(resp_data, "data")
  # Three faults, not one. `json_field()` gives NULL for a name the body does
  # not carry, so that is the only shape that means the block is absent. A
  # block that is there but holds a plain value has to say so, or the user
  # goes looking for a field that is already in front of them. And a JSON
  # array parses to an unnamed list where a JSON object parses to a named one:
  # `length()` on the object form would count its members as though they were
  # array elements, so the names are what tell those two apart.
  if (is.null(data)) {
    fail("the response carries no {.field data} block.")
  }
  if (!is.list(data)) {
    fail("the {.field data} block is a plain value rather than an array.")
  }
  if (!is.null(names(data))) {
    fail("the {.field data} block is a JSON object rather than an array.")
  }
  if (length(data) != n) {
    fail(
      "the response carries {length(data)} embedding{?s} for {n} input{?s}."
    )
  }
  if (!all(vapply(data, is_json_object, logical(1)))) {
    fail("an element of the {.field data} block is not a JSON object.")
  }

  indexes <- vapply(
    data,
    function(el) {
      index <- json_field(el, "index")
      if (is_one_number(index)) as.numeric(index) else NA_real_
    },
    numeric(1)
  )
  if (anyNA(indexes)) {
    fail("an element of the {.field data} block carries no usable index.")
  }
  if (any(indexes != round(indexes))) {
    fail("an index in the {.field data} block is not a whole number.")
  }
  if (anyDuplicated(indexes) > 0) {
    fail("the {.field data} block repeats an index.")
  }
  if (any(indexes < 0) || any(indexes > n - 1)) {
    fail("an index in the {.field data} block falls outside 0 to {n - 1}.")
  }

  vectors <- lapply(data, function(el) {
    embedding <- json_field(el, "embedding")
    if (!is.list(embedding) || !is.null(names(embedding))) {
      return(NULL)
    }
    if (!all(vapply(embedding, is_one_number, logical(1)))) {
      return(NULL)
    }
    as.double(unlist(embedding, use.names = FALSE))
  })

  if (any(vapply(vectors, is.null, logical(1)))) {
    fail("an element of the {.field data} block carries no list of numbers.")
  }
  # An empty JSON array is a list of numbers, of none of them. It needs its
  # own clause, and its own guard: `matrix(ncol = 0)` would otherwise build a
  # matrix of no columns rather than abort.
  if (any(lengths(vectors) == 0L)) {
    fail("an embedding in the {.field data} block is empty.")
  }

  widths <- unique(lengths(vectors))
  if (length(widths) > 1L) {
    fail("the embeddings in the {.field data} block are of unequal length.")
  }

  # `matrix()` returns NULL dimnames and `unlist(use.names = FALSE)` strips
  # the names off every value placed into it, so the matrix is unnamed by
  # construction and needs no `dimnames(out) <- NULL` line to make it so.
  out <- matrix(0, nrow = n, ncol = widths)
  for (i in seq_len(n)) {
    out[indexes[[i]] + 1L, ] <- vectors[[i]]
  }
  out
}
