#' Turn Text into Embedding Vectors
#'
#' Sends one or more texts to an embedding model and returns the vector that
#' the model produced for each one. The texts go out in batches of at most
#' `batch_size`, one request per batch, in the order given.
#'
#' @param model Character. The loaded embedding model name. Must be one name,
#'   given as a single string.
#' @param input Character. The texts to embed. A vector of length `n` returns
#'   `n` embeddings, in the order given. Must hold at least one value and no
#'   missing values.
#' @param host Character. Server URL.
#' @param simplify Logical. If `TRUE`, the default, returns a numeric matrix
#'   with one row per input. Any other value returns a list of the parsed
#'   response bodies, unchanged, one per request.
#' @param ... Additional fields for the request body. LM Studio ignores a
#'   field it does not recognize, and two OpenAI fields are worth naming for
#'   that reason: LM Studio ignores `dimensions`, so asking for a narrower
#'   vector has no effect. `encoding_format = "base64"` is untested against LM
#'   Studio: a server that honors it returns embeddings this function cannot
#'   read, and the default `simplify = TRUE` path then aborts.
#' @param ttl A whole number of seconds from 1 to `.Machine$integer.max`, or
#'   `NULL` to leave it out. It is how long the model stays loaded with no
#'   request. It has an effect only on a model that this request loads. The
#'   server loads a model that is not loaded yet when its just-in-time loading
#'   setting is on. A model that is already loaded keeps its idle time.
#' @param token Character or `NULL`. An API token for a server that requires
#'   authentication. `NULL` reads the `rlmstudio.token` option and then the
#'   `RLMSTUDIO_API_TOKEN` environment variable. See [rlmstudio_token].
#' @param batch_size A whole number from 1 to `.Machine$integer.max`. The
#'   most texts that one request carries. The default is 100. A value at
#'   least as large as `length(input)` sends every text in one request.
#' @param quiet Logical or `NULL`. Whether to suppress the progress bar. `NULL`
#'   reads the `rlmstudio.quiet` option. The bar shows only when the call sends
#'   more than one request. `quiet` does not suppress the warning about failed
#'   inputs.
#' @return If `simplify = FALSE`, a list with one element per request, in
#'   request order. Each element is the parsed JSON body of that request, or
#'   the condition of a request that failed. A call with one request returns
#'   a list of one. Otherwise, a double matrix with one row per input text and
#'   one column per embedding dimension. The row at position `i` holds the
#'   embedding that the response reported for the input at position `i`, or
#'   `NA` for an input whose request failed. The matrix carries no row or
#'   column names.
#' @details
#' Before each request after the first, the function checks again that the
#' server is running.
#'
#' A request that fails with an `rlmstudio_bad_response`, or with an
#' `rlmstudio_api_error` whose `status` is not 401, 403, or 404, fails the
#' inputs it carried alone. Their rows hold `NA`, or their element of the
#' `simplify = FALSE` list holds the condition without its backtrace. The call
#' goes on to the next request and then gives one warning that names the
#' count and the positions of the failed inputs. That warning shows even with
#' `quiet = TRUE`. If every request fails, the call aborts with the condition
#' of the first failed request, and no warning is given.
#'
#' Two faults end the call at once, and no request goes out after them: a
#' server that the check before a request finds gone, and an
#' `rlmstudio_api_error` with `status` 401, 403, or 404. With
#' `simplify = TRUE`, a third fault does the same: a request whose embeddings
#' have another number of dimensions than those of an earlier request. It
#' aborts with `rlmstudio_bad_response`. With `simplify = FALSE`, the bodies
#' do not go through the matrix checks, so bodies of two widths are returned
#' with no abort. Each abort
#' after a request that succeeded carries a `results` field. With
#' `simplify = TRUE`, it is the matrix so far, with `NA` in each row whose
#' embedding did not arrive. With `simplify = FALSE`, it is the list so far,
#' with `NULL` in the element of the request that ended the call and in every
#' element after it. An abort before any
#' request succeeded carries no `results` field. An error of any other class
#' aborts the call unchanged.
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
  ttl = NULL,
  token = NULL,
  batch_size = 100,
  quiet = NULL
) {
  rlm_check_id(model, "model")
  rlm_check_text(input, "input")
  rlm_check_ttl(ttl)
  rlm_check_batch_size(batch_size)

  stop_if_no_server(host)

  # An R integer is written as a JSON integer whatever the serializer does
  # with a double. The check has already made the value whole and in range.
  base <- list(model = model)
  if (!is.null(ttl)) {
    base$ttl <- as.integer(ttl)
  }
  dots <- list(...)
  client <- lms_client(host, token = token)
  has_token <- !is.null(rlm_token(token))

  # Consecutive runs of at most `batch_size` inputs, in input order. The size
  # can be as large as `.Machine$integer.max`, where integer sums overflow, so
  # the ends are computed as doubles and cut back to the input length.
  n <- length(input)
  starts <- seq(1, n, by = batch_size)
  batches <- lapply(starts, function(s) seq.int(s, min(s + batch_size - 1, n)))

  show_bar <- length(batches) > 1L && !is_quiet(quiet)
  if (show_bar) {
    pb <- cli::cli_progress_bar(
      name = "Embedding",
      total = n,
      format = "{cli::pb_name} {cli::pb_bar} {cli::pb_percent} | ETA: {cli::pb_eta}"
    )
    on.exit(cli::cli_progress_done(id = pb), add = TRUE)
  }

  # With `simplify = TRUE` the rows go into one matrix, made once the first
  # request succeeds, because only a reply says how wide a vector is. A failed
  # request leaves its rows NA. With `simplify = FALSE` each request's parsed
  # body takes one slot of a list.
  out <- NULL
  bodies <- vector("list", length(batches))
  any_ok <- FALSE
  failed <- integer()
  first_failure <- NULL

  # A lost server or a fault that holds for every request ends the call, as
  # in `lms_chat_batch()` (D-011, D-019). Once a request has succeeded, the
  # condition carries what the call has so far, so a long run does not lose
  # it. Before that no vectors have arrived, and the condition is unchanged.
  abort_with_results <- function(cnd) {
    if (any_ok) {
      cnd$results <- if (isTRUE(simplify)) out else bodies
    }
    stop(cnd)
  }
  # A failed request loses its own rows, not the whole call. The backtrace is
  # dropped from the kept copy, because it makes each slot large and says
  # nothing about the inputs.
  keep_failure <- function(cnd) {
    if (is.null(first_failure)) {
      first_failure <<- cnd
    }
    cnd$trace <- NULL
    cnd
  }
  # A refused token or a model the server cannot find fails every request the
  # same way, whatever the texts, so these statuses end the call (D-019).
  keep_or_abort_api <- function(cnd) {
    if (isTRUE(cnd$status %in% c(401L, 403L, 404L))) {
      abort_with_results(cnd)
    }
    keep_failure(cnd)
  }

  for (b in seq_along(batches)) {
    rows <- batches[[b]]
    # The probe before the first request ran above. Without this one, a
    # server that stops between two requests makes the next request abort
    # with an `httr2_failure` that carries no `results`.
    if (b > 1L) {
      tryCatch(
        stop_if_no_server(host),
        rlmstudio_no_server = abort_with_results
      )
    }

    # as.list() is what keeps a single input an array of one rather than a
    # bare string: jsonlite serializes an unnamed list as a JSON array
    # whatever its length, while auto-unboxing would turn a length-one
    # character vector into a scalar. unname() is what keeps the list
    # unnamed: as.list() carries the vector's names over, and jsonlite writes
    # a named list as a JSON object. `setNames(df$text, df$id)` is an
    # ordinary way to reach this function.
    body <- c(base, list(input = as.list(unname(input[rows]))))
    body <- utils::modifyList(body, dots)

    res <- tryCatch(
      embed_request(client, body, has_token, simplify),
      rlmstudio_api_error = keep_or_abort_api,
      rlmstudio_bad_response = keep_failure
    )

    if (inherits(res, c("rlmstudio_api_error", "rlmstudio_bad_response"))) {
      failed <- c(failed, rows)
      if (!isTRUE(simplify)) {
        bodies[b] <- list(res)
      }
    } else if (isTRUE(simplify)) {
      if (is.null(out)) {
        out <- matrix(NA_real_, nrow = n, ncol = ncol(res$value))
      } else if (ncol(res$value) != ncol(out)) {
        # Vectors of two widths cannot share a matrix, and no rule says which
        # width is right, so the call ends rather than guess.
        width_fault <- tryCatch(
          rlm_abort_bad_response(
            res$resp,
            "Embeddings Failed",
            cli::format_inline(
              "the embeddings of inputs {min(rows)} to {max(rows)} have {ncol(res$value)} dimension{?s}, and earlier ones have {ncol(out)}."
            )
          ),
          rlmstudio_bad_response = identity
        )
        abort_with_results(width_fault)
      }
      out[rows, ] <- res$value
      any_ok <- TRUE
    } else {
      bodies[b] <- list(res$value)
      any_ok <- TRUE
    }

    if (show_bar) {
      cli::cli_progress_update(id = pb, inc = length(rows))
    }
  }

  if (!any_ok) {
    stop(first_failure)
  }

  if (length(failed) > 0L) {
    # Shown whatever `quiet` says, because it is the only signal that some
    # vectors are missing (D-010, D-011). The positions are joined here,
    # because cli shortens a vector of more than 20 values and would drop
    # some of them.
    positions <- cli::ansi_collapse(failed, trunc = Inf)
    detail <- if (isTRUE(simplify)) {
      "The rows of those inputs hold {.code NA}. Use {.code simplify = FALSE} to keep the conditions."
    } else {
      "The element of each request that carried them holds the {.cls rlmstudio_api_error} or {.cls rlmstudio_bad_response} condition."
    }
    cli::cli_warn(c(
      "{length(failed)} input{?s} failed, at {cli::qty(length(failed))}position{?s} {positions}.",
      "i" = detail
    ))
  }

  if (isTRUE(simplify)) out else bodies
}

#' Send one embeddings request and read its reply
#'
#' @param client The httr2 request that `lms_client()` built.
#' @param body List. The request body, whose `input` is one batch.
#' @param has_token Logical. Whether a token was sent, for the abort hint.
#' @param simplify Logical. Whether to build the matrix from the reply.
#' @return A list of `value`, the matrix or the parsed body, and `resp`.
#'
#' @noRd
embed_request <- function(client, body, has_token, simplify) {
  resp <- client |>
    httr2::req_url_path("v1/embeddings") |>
    rlm_req_body(body) |>
    httr2::req_error(is_error = \(resp) FALSE) |>
    httr2::req_perform()

  if (httr2::resp_status(resp) != 200) {
    rlm_abort_api(resp, "Embeddings Failed", has_token)
  }

  resp_data <- parse_ok_body(resp, "Embeddings Failed")

  if (!isTRUE(simplify)) {
    return(list(value = resp_data, resp = resp))
  }

  # The count comes from the body that was actually sent rather than from the
  # batch. R rejects a call that names `input` twice, so today the two are
  # always the same length; reading the body keeps them the same if a later
  # change ever puts the inputs together some other way.
  list(value = embed_matrix(resp_data, length(body[["input"]]), resp), resp = resp)
}

#' Is this value one number?
#'
#' `parse_ok_body()` parses with `simplifyVector = FALSE` (LESSONS, M005), so
#' every number in the body arrives as a length-one numeric and a
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
