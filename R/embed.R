#' Turn Text into Embedding Vectors
#'
#' Sends one or more texts to an embedding model and returns the vector that
#' the model produced for each one. The whole input vector travels in a single
#' request.
#'
#' @param model Character. The loaded embedding model name.
#' @param input Character. The texts to embed. A vector of length `n` returns
#'   `n` embeddings, in the order given.
#' @param host Character. Server URL.
#' @param simplify Logical. If `TRUE`, returns a numeric matrix with one row
#'   per input. If `FALSE`, returns the parsed response body unchanged.
#' @param ... Additional API arguments (e.g., `dimensions`,
#'   `encoding_format`).
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
  if (!is.character(input) || length(input) == 0) {
    cli::cli_abort(
      "{.arg input} must be a non-empty character vector.",
      call = NULL
    )
  }

  stop_if_no_server(host)

  # as.list() is what keeps a single input an array of one rather than a bare
  # string: jsonlite serializes an unnamed list as a JSON array whatever its
  # length, while auto-unboxing would turn a length-one character vector into
  # a scalar.
  body <- list(model = model, input = as.list(input))
  body <- utils::modifyList(body, list(...))

  resp <- lms_client(host, token = token) |>
    httr2::req_url_path("v1/embeddings") |>
    httr2::req_body_json(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200) {
    rlm_abort_api(resp, "Embeddings Failed", !is.null(rlm_token(token)))
  }

  resp_data <- httr2::resp_body_json(resp)

  if (!isTRUE(simplify)) {
    return(resp_data)
  }

  # The count comes from the body that was actually sent rather than from the
  # `input` argument. R rejects a call that names `input` twice, so today the
  # two are always the same length; reading the body keeps them the same if a
  # later change ever puts the inputs together some other way.
  embed_matrix(resp_data, length(body$input), resp)
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

#' Check the data block of an embeddings response and build the matrix
#'
#' Reads the `data` block of a parsed `/v1/embeddings` body and returns a
#' double matrix with one row per input. Every condition below aborts with
#' class `rlmstudio_bad_response` rather than building a matrix, because a
#' block whose indexes are missing, repeated, or out of range would otherwise
#' pair a vector with the wrong text and corrupt a whole batch without a
#' message.
#'
#' The rows are placed by the `index` field of each element and not by arrival
#' order, which is what the endpoint's own contract promises.
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

  data <- resp_data$data
  if (!is.list(data)) {
    fail("the response carries no {.field data} block.")
  }
  if (length(data) != n) {
    fail(
      "the response carries {length(data)} embedding{?s} for {n} input{?s}."
    )
  }

  indexes <- vapply(
    data,
    function(el) if (is_one_number(el$index)) as.numeric(el$index) else NA_real_,
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
    embedding <- el$embedding
    if (!is.list(embedding) || length(embedding) == 0L) {
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

  widths <- unique(lengths(vectors))
  if (length(widths) > 1L) {
    fail("the embeddings in the {.field data} block are of unequal length.")
  }

  out <- matrix(0, nrow = n, ncol = widths)
  for (i in seq_len(n)) {
    out[indexes[[i]] + 1L, ] <- vectors[[i]]
  }
  dimnames(out) <- NULL
  out
}
