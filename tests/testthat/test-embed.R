# lms_embed() is driven through the shared recorder in helper-mock-http.R.
# A healthy server cannot produce the malformed bodies the response check
# rejects, so those bodies are written here rather than recorded (D-004). The
# happy path has a recorded cassette of its own, in the embed_live directory.

# Read the request body as bytes rather than through the parsed form that
# request_target() returns. `jsonlite::fromJSON()` with its default
# simplification turns both `["one"]` and `"one"` into a character vector of
# length one, so the parsed form cannot tell an array of one from a bare
# string (LESSONS, M008). Parsing with simplifyVector = FALSE keeps the
# difference: an array arrives as a list, a bare string as a character scalar.
sent_body <- function(req) {
  require_httpuv()
  out <- httr2::req_dry_run(req, quiet = TRUE, redact_headers = FALSE)
  jsonlite::fromJSON(rawToChar(out$body), simplifyVector = FALSE)
}

# Build one element of a response `data` block.
embed_element <- function(index, values) {
  sprintf(
    '{"object": "embedding", "index": %s, "embedding": [%s]}',
    format(index, scientific = FALSE),
    paste(format(values, scientific = FALSE), collapse = ", ")
  )
}

# Build a whole response body from already-rendered elements.
embed_body <- function(...) {
  sprintf(
    '{"object": "list", "model": "test-embed", "data": [%s]}',
    paste(c(...), collapse = ", ")
  )
}

# The three-input, five-dimension response the order tests are built on. Every
# value is fractional, so a coercion that dropped the fraction would show.
row_one <- c(0.11, 0.12, 0.13, 0.14, 0.15)
row_two <- c(0.21, 0.22, 0.23, 0.24, 0.25)
row_three <- c(0.31, 0.32, 0.33, 0.34, 0.35)

three_inputs <- c("first text", "second text", "third text")

in_order_body <- embed_body(
  embed_element(0, row_one),
  embed_element(1, row_two),
  embed_element(2, row_three)
)

# Run lms_embed() against a body of the caller's choosing and return both the
# value and the requests that were sent.
drive_embed <- function(body, ..., status = 200L) {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_recorder(mock_response(status, body))
  value <- lms_embed(model = "test-embed", ...)
  list(value = value, requests = recorder$requests)
}


# The request ---------------------------------------------------------------

test_that("lms_embed sends one POST to v1/embeddings carrying the inputs", {
  run <- drive_embed(in_order_body, input = three_inputs)

  expect_length(run$requests, 1L)

  target <- request_target(run$requests[[1]])
  expect_equal(target$method, "POST")
  expect_equal(target$path, "/v1/embeddings")

  body <- sent_body(run$requests[[1]])
  expect_equal(body$model, "test-embed")
  expect_true(is.list(body$input))
  expect_equal(unlist(body$input), three_inputs)
})

test_that("a single input still travels as an array of one", {
  run <- drive_embed(
    embed_body(embed_element(0, row_one)),
    input = "only one"
  )

  body <- sent_body(run$requests[[1]])

  # This is the assertion that fails if the input stops being wrapped in a
  # list: jsonlite auto-unboxes a character vector of length one into a bare
  # JSON string, and `is.list()` then reports FALSE.
  expect_true(is.list(body$input))
  expect_length(body$input, 1L)
  expect_identical(body$input[[1]], "only one")
})

test_that("a named input vector still travels as an array", {
  # `setNames(df$text, df$id)` is an ordinary way to reach this function, and
  # `as.list()` carries those names over. jsonlite writes a named list as a
  # JSON object, so without `unname()` the body sends an object where the
  # endpoint wants an array. `is.list()` cannot tell the two apart, so these
  # assertions read the names.
  one <- sent_body(drive_embed(
    embed_body(embed_element(0, row_one)),
    input = c(doc1 = "only one")
  )$requests[[1]])
  expect_null(names(one$input))
  expect_identical(one$input[[1]], "only one")

  two <- sent_body(drive_embed(
    embed_body(embed_element(0, row_one), embed_element(1, row_two)),
    input = c(a = "first", b = "second")
  )$requests[[1]])
  expect_null(names(two$input))
  expect_equal(unlist(two$input), c("first", "second"))
})


# The returned matrix -------------------------------------------------------

# Assert the whole promised shape of one returned matrix: a double matrix of
# the expected size, with no names, whose rows are the expected rows in the
# expected places. Each arrival-order case below runs the same assertions, so
# a case cannot pass by checking less than its neighbours.
expect_embedding_matrix <- function(out, rows) {
  expect_true(is.matrix(out))
  expect_type(out, "double")
  expect_equal(dim(out), c(length(rows), length(rows[[1]])))
  expect_null(dimnames(out))
  for (i in seq_along(rows)) {
    expect_equal(out[i, ], rows[[i]])
  }
}

test_that("three inputs answered in order give three rows in order", {
  expect_embedding_matrix(
    drive_embed(in_order_body, input = three_inputs)$value,
    list(row_one, row_two, row_three)
  )
})

test_that("three inputs answered out of order are placed by index", {
  permuted <- embed_body(
    embed_element(2, row_three),
    embed_element(0, row_one),
    embed_element(1, row_two)
  )

  # The same three rows in the same places as the in-order body. A build that
  # used arrival order would put row_three first.
  expect_embedding_matrix(
    drive_embed(permuted, input = three_inputs)$value,
    list(row_one, row_two, row_three)
  )
})

test_that("two inputs answered in order give two rows in order", {
  in_order_two <- embed_body(
    embed_element(0, row_one),
    embed_element(1, row_two)
  )

  expect_embedding_matrix(
    drive_embed(in_order_two, input = c("one", "two"))$value,
    list(row_one, row_two)
  )
})

test_that("two inputs answered out of order are placed by index", {
  # The smallest case that tells index placement from arrival placement. A
  # build reading arrival order would put row_two first.
  swapped <- embed_body(
    embed_element(1, row_two),
    embed_element(0, row_one)
  )

  expect_embedding_matrix(
    drive_embed(swapped, input = c("one", "two"))$value,
    list(row_one, row_two)
  )
})

test_that("a single input returns a matrix and not a vector", {
  expect_embedding_matrix(
    drive_embed(embed_body(embed_element(0, row_one)), input = "only one")$value,
    list(row_one)
  )
})


test_that("a response recorded from a live server builds the matrix", {
  # The cassette in embed_live/ was recorded against a real LM Studio server
  # running text-embedding-nomic-embed-text-v1.5. Regenerate it with
  # data-raw/record-embed-cassette.R, which carries the full provenance.
  local_mocked_bindings(is_server_running = function(...) TRUE)

  # The cassette was recorded with no token and carries no request header.
  # This machine normally has the environment variable set, so the test
  # clears both sources and reads the cassette the way it was written.
  withr::local_envvar(RLMSTUDIO_API_TOKEN = NA)
  withr::local_options(rlmstudio.token = NULL)

  httptest2::with_mock_dir("embed_live", {
    out <- lms_embed(
      model = "text-embedding-nomic-embed-text-v1.5",
      input = c(
        "the first document",
        "the second document",
        "the third document"
      ),
      host = "http://localhost:1234"
    )

    expect_true(is.matrix(out))
    expect_type(out, "double")
    expect_equal(dim(out), c(3L, 768L))
    expect_null(dimnames(out))

    # Read off the recorded body: the first number of the element whose index
    # is 0. It is fractional, so a coercion that lost the fraction would show.
    expect_equal(out[1, 1], 0.014852429740130901)

    # Three different texts give three different vectors, so the matrix is not
    # one row copied across. All three pairs are compared.
    expect_false(isTRUE(all.equal(out[1, ], out[2, ])))
    expect_false(isTRUE(all.equal(out[2, ], out[3, ])))
    expect_false(isTRUE(all.equal(out[1, ], out[3, ])))
  })
})


# simplify = FALSE ----------------------------------------------------------

test_that("simplify = FALSE returns the parsed body unchanged", {
  out <- drive_embed(in_order_body, input = three_inputs, simplify = FALSE)$value

  expect_identical(
    out,
    httr2::resp_body_json(mock_response(200L, in_order_body))
  )
})

test_that("simplify = FALSE returns a body the response check rejects", {
  ragged <- embed_body(
    embed_element(0, row_one),
    embed_element(1, row_two[1:3]),
    embed_element(2, row_three)
  )

  # The control: the same body aborts under the default.
  expect_error(
    drive_embed(ragged, input = three_inputs),
    class = "rlmstudio_bad_response"
  )

  out <- drive_embed(ragged, input = three_inputs, simplify = FALSE)$value
  expect_identical(
    out,
    httr2::resp_body_json(mock_response(200L, ragged))
  )
})


# Conditions ----------------------------------------------------------------

test_that("lms_embed aborts with class rlmstudio_no_server", {
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_embed(model = "test-embed", input = "text"),
    class = "rlmstudio_no_server"
  )
})

test_that("a failed response aborts with class rlmstudio_api_error", {
  for (status in c(400L, 503L)) {
    condition <- tryCatch(
      drive_embed(
        '{"error": {"message": "no such model"}}',
        input = "text",
        status = status
      ),
      rlmstudio_api_error = function(cnd) cnd
    )

    expect_s3_class(condition, "rlmstudio_api_error")
    expect_identical(condition$status, status)
    expect_match(conditionMessage(condition), "no such model")
  }
})


# The response check --------------------------------------------------------

# Eighteen probes over the twelve conditions the response check rejects, with
# three of them aimed at the not-a-list-of-numbers branch, two at the
# out-of-range branch, three at the no-data-block branch, and two at the two
# branches that report a value that is not a JSON object, one for the whole
# body and one for an element of the data block. `detail` is the clause the
# abort must report, so a probe that fired the wrong branch fails rather than
# passing on the shared class.
bad_bodies <- list(
  list(
    label = "a body with no data block",
    input = "text",
    body = '{"object": "list", "model": "test-embed"}',
    detail = "no data block"
  ),
  list(
    # `$` partial-matches, so a `database` field would be read as the data
    # block and a matrix built from it. That is the silent wrong matrix the
    # whole check exists to prevent, so it aborts instead.
    label = "a database field where the data block should be",
    input = "text",
    body = '{"database": [{"index": 0, "embedding": [0.1, 0.2]}]}',
    detail = "no data block"
  ),
  list(
    # A JSON object parses to a list just as an array does, and `length()`
    # would count its members as elements.
    label = "a data block sent as a JSON object",
    input = "text",
    body = '{"data": {"first": {"index": 0, "embedding": [0.1, 0.2]}}}',
    detail = "JSON object rather than an array"
  ),
  list(
    label = "a whole body that is a JSON array",
    input = "text",
    body = '[{"index": 0, "embedding": [0.1, 0.2]}]',
    detail = "no data block"
  ),
  list(
    # `$` on an atomic value is an error, not a missing field, so an
    # unguarded read here would raise an unclassed condition.
    label = "a whole body that is a JSON string",
    input = "text",
    body = '"hello"',
    detail = "not a JSON object"
  ),
  list(
    label = "a data element that is a bare string",
    input = "text",
    body = '{"data": ["aGVsbG8="]}',
    detail = "not a JSON object"
  ),
  list(
    # An empty array is a list of numbers, of none of them, so it needs its
    # own clause rather than the not-a-list-of-numbers one.
    label = "an embedding that is an empty array",
    input = "text",
    body = '{"data": [{"index": 0, "embedding": []}]}',
    detail = "is empty"
  ),
  list(
    label = "an embedding sent as a base64 string",
    input = "text",
    body = '{"data": [{"index": 0, "embedding": "aGVsbG8gd29ybGQ="}]}',
    detail = "no list of numbers"
  ),
  list(
    label = "an embedding of null",
    input = "text",
    body = '{"data": [{"index": 0, "embedding": null}]}',
    detail = "no list of numbers"
  ),
  list(
    label = "an embedding holding something that is not a number",
    input = "text",
    body = '{"data": [{"index": 0, "embedding": [0.1, "two", 0.3]}]}',
    detail = "no list of numbers"
  ),
  list(
    label = "three embeddings whose middle one is shorter",
    input = three_inputs,
    body = embed_body(
      embed_element(0, row_one),
      embed_element(1, row_two[1:3]),
      embed_element(2, row_three)
    ),
    detail = "unequal length"
  ),
  list(
    label = "a missing index",
    input = "text",
    body = '{"data": [{"embedding": [0.1, 0.2]}]}',
    detail = "no usable index"
  ),
  list(
    label = "a fractional index",
    input = "text",
    body = '{"data": [{"index": 0.5, "embedding": [0.1, 0.2]}]}',
    detail = "not a whole number"
  ),
  list(
    label = "a repeated index",
    input = c("one", "two"),
    body = embed_body(
      embed_element(0, row_one),
      embed_element(0, row_two)
    ),
    detail = "repeats an index"
  ),
  list(
    label = "an index of -1",
    input = "text",
    body = '{"data": [{"index": -1, "embedding": [0.1, 0.2]}]}',
    detail = "outside 0 to 0"
  ),
  list(
    label = "an index equal to the input count",
    input = "text",
    body = '{"data": [{"index": 1, "embedding": [0.1, 0.2]}]}',
    detail = "outside 0 to 0"
  ),
  list(
    label = "a data block shorter than the input vector",
    input = c("one", "two"),
    body = embed_body(embed_element(0, row_one)),
    detail = "1 embedding for 2 inputs"
  ),
  list(
    label = "a data block longer than the input vector",
    input = "text",
    body = embed_body(
      embed_element(0, row_one),
      embed_element(1, row_two)
    ),
    detail = "2 embeddings for 1 input"
  )
)

for (probe in bad_bodies) {
  local({
    case <- probe
    test_that(paste("the response check rejects", case$label), {
      condition <- tryCatch(
        drive_embed(case$body, input = case$input),
        rlmstudio_bad_response = function(cnd) cnd
      )

      expect_s3_class(condition, "rlmstudio_bad_response")
      expect_identical(condition$status, 200L)

      message <- conditionMessage(condition)
      expect_match(message, case$detail, fixed = TRUE)
      expect_match(message, "simplify = FALSE", fixed = TRUE)
    })
  })
}

# A body that never parses cannot reach the probe table above, which hands
# `embed_matrix()` an already-parsed body. These two drive the wrapper itself.
test_that("a 200 whose body is not JSON aborts with the response class", {
  for (case in list(
    list(body = "<html>oops</html>", type = "text/html"),
    list(body = "not json at all", type = "application/json")
  )) {
    condition <- tryCatch(
      {
        local_mocked_bindings(is_server_running = function(...) TRUE)
        local_request_recorder(mock_response(
          200L,
          case$body,
          content_type = case$type
        ))
        lms_embed("test-embed", input = "text")
      },
      condition = function(cnd) cnd
    )

    expect_s3_class(condition, "rlmstudio_bad_response")
    expect_identical(condition$status, 200L)

    message <- conditionMessage(condition)
    expect_match(message, "did not parse as JSON", fixed = TRUE)

    # The parse runs before the `simplify` branch, so the usual advice would
    # send the caller down a path that fails the same way.
    expect_no_match(message, "simplify = FALSE", fixed = TRUE)
    expect_match(message, "may be answering on this host", fixed = TRUE)
  }
})

test_that("simplify = FALSE cannot rescue a body that does not parse", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_recorder(mock_response(200L, "not json at all"))

  expect_error(
    lms_embed("test-embed", input = "text", simplify = FALSE),
    class = "rlmstudio_bad_response"
  )
})

test_that("the response check stays silent on a block it should accept", {
  # The passing control for the eighteen probes above. It shares their path:
  # three inputs, three elements, one index each, one common width. Nothing
  # here is rejected, so the probes above are rejecting on their own defect.
  expect_true(is.matrix(drive_embed(in_order_body, input = three_inputs)$value))
})

test_that("the dots cannot override the inputs", {
  # `input` is a formal argument, so R rejects a call that names it twice
  # before the function body runs. The count the response check uses is read
  # off the request body, and that body can therefore only ever hold the
  # texts the `input` argument named.
  local_mocked_bindings(is_server_running = function(...) TRUE)

  expect_error(
    lms_embed("test-embed", input = "one", input = "two"),
    "matched by multiple actual arguments"
  )
})


# The input contract --------------------------------------------------------

# The whole message, not a pattern. `lms_chat_batch()` raises the same
# sentence about its own `inputs` argument, so a loose match on "non-empty
# character" passes unchanged if this wrapper ever named the wrong argument.
input_abort_message <- "`input` must be a non-empty character vector."

test_that("lms_embed aborts on an input that is not a character vector", {
  local_mocked_bindings(is_server_running = function(...) TRUE)

  for (bad in list(1:3, list("a"), NULL, character(0))) {
    expect_error(
      lms_embed("test-embed", input = bad),
      input_abort_message,
      fixed = TRUE
    )
  }
})

test_that("the input check runs before the server check", {
  # A bad input aborts on its own message even with no server, so the abort
  # names the caller's mistake rather than the machine's state.
  local_mocked_bindings(is_server_running = function(...) FALSE)
  expect_error(
    lms_embed("test-embed", input = 1:3),
    input_abort_message,
    fixed = TRUE
  )
})


# The token -----------------------------------------------------------------

test_that("lms_embed sends the token as a bearer header", {
  run <- drive_embed(
    embed_body(embed_element(0, row_one)),
    input = "text",
    token = "embed-token"
  )

  headers <- request_target(run$requests[[1]])$headers
  expect_equal(headers$authorization, "Bearer embed-token")
})

test_that("lms_embed sends no Authorization header without a token", {
  withr::local_options(rlmstudio.token = NULL)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")

  run <- drive_embed(embed_body(embed_element(0, row_one)), input = "text")

  headers <- request_target(run$requests[[1]])$headers
  expect_null(headers$authorization)
})
