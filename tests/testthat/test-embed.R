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
  out <- request_dry_run(req, redact_headers = FALSE)
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

test_that("simplify = FALSE returns the parsed body unchanged, in a list of one", {
  out <- drive_embed(in_order_body, input = three_inputs, simplify = FALSE)$value

  expect_identical(
    out,
    list(httr2::resp_body_json(mock_response(200L, in_order_body)))
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
    list(httr2::resp_body_json(mock_response(200L, ragged)))
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

# Nineteen probes over the thirteen conditions the response check rejects,
# with three of them aimed at the not-a-list-of-numbers branch, two at the
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
    # The block is right there; it just holds the wrong thing. Reporting this
    # as a missing block would send the user looking for a field that is
    # already in front of them.
    label = "a data block holding a plain value",
    input = "text",
    body = '{"data": "oops"}',
    detail = "plain value rather than an array"
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

test_that("good JSON under a non-JSON content type is read, not misreported", {
  # A proxy that rewrites the content-type header sends good JSON under the
  # wrong label. Reading by content rather than by header is what keeps the
  # parse-failure message above true: this body parses, so no abort is right,
  # and calling it a parse failure would have named the wrong fault and left
  # no way through.
  for (type in c("text/plain", "text/html", "application/octet-stream")) {
    local_mocked_bindings(is_server_running = function(...) TRUE)
    local_request_recorder(mock_response(
      200L,
      '{"data": [{"index": 0, "embedding": [0.1, 0.2]}]}',
      content_type = type
    ))

    out <- lms_embed("test-embed", input = "text")
    expect_true(is.matrix(out))
    expect_identical(dim(out), c(1L, 2L))
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

  headers <- request_target(run$requests[[1]], redact_headers = FALSE)$headers
  expect_equal(headers$authorization, "Bearer embed-token")
})

test_that("lms_embed sends no Authorization header without a token", {
  withr::local_options(rlmstudio.token = NULL)
  withr::local_envvar(RLMSTUDIO_API_TOKEN = "")

  run <- drive_embed(embed_body(embed_element(0, row_one)), input = "text")

  headers <- request_target(run$requests[[1]], redact_headers = FALSE)$headers
  expect_null(headers$authorization)
})


# The batch size ------------------------------------------------------------

# Each value is a fault of a different kind: no value, a missing value of two
# types, two values of the wrong type, two values, and five numbers out of range
# or not whole.
batch_size_bad_values <- list(
  NULL,
  NA,
  NA_real_,
  TRUE,
  "10",
  c(1, 2),
  0,
  -1,
  1.5,
  Inf,
  2^31
)

test_that("a bad batch_size aborts, named, before the server probe", {
  probe <- new.env(parent = emptyenv())
  probe$calls <- 0L
  local_mocked_bindings(
    is_server_running = function(...) {
      probe$calls <- probe$calls + 1L
      TRUE
    }
  )
  recorder <- local_request_recorder()

  for (value in batch_size_bad_values) {
    label <- paste("batch_size =", deparse(value))
    err <- expect_error(
      lms_embed("test-embed", three_inputs, batch_size = value),
      "`batch_size` must be one whole number from 1 to",
      fixed = TRUE,
      info = label
    )
    # An argument fault carries no condition class of the package (D-008).
    expect_false(
      inherits(err, c("rlmstudio_no_server", "rlmstudio_api_error")),
      info = label
    )
  }
  expect_identical(probe$calls, 0L)
  expect_length(recorder$requests, 0L)
})

test_that("a good batch_size passes the check", {
  # Each value sends the three inputs in one request, so one reply serves it.
  # Sizes below the input count are driven by the batch tests below.
  for (value in list(3, 3L, 100, .Machine$integer.max)) {
    run <- drive_embed(in_order_body, input = three_inputs, batch_size = value)
    expect_identical(dim(run$value), c(3L, 5L), info = deparse(value))
  }
})


# Batches -------------------------------------------------------------------

# The vector served for input `i`: three values that no other input shares.
input_vector <- function(i, width = 3L) i + seq_len(width) / 10

# A reply for the inputs at `positions`, one element per input, with the
# element order given by `order` (a permutation of the positions' ranks).
batch_reply <- function(positions, order = seq_along(positions), width = 3L) {
  elements <- vapply(
    order,
    function(k) embed_element(k - 1L, input_vector(positions[[k]], width)),
    character(1)
  )
  mock_response(200L, do.call(embed_body, as.list(elements)))
}

batch_inputs <- stats::setNames(
  paste("text", seq_len(250)),
  paste0("id", seq_len(250))
)

test_that("250 inputs at batch_size 100 go out as three ordered requests", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(
    batch_reply(1:100),
    # Served in reverse, so only the index can put these rows in place.
    batch_reply(101:200, order = 100:1),
    batch_reply(201:250)
  ))

  out <- lms_embed(
    "test-embed",
    batch_inputs,
    ttl = 60,
    dimensions = 3,
    batch_size = 100
  )

  expect_length(recorder$requests, 3L)
  sent <- lapply(recorder$requests, sent_body)
  expected_rows <- list(1:100, 101:200, 201:250)
  for (b in 1:3) {
    label <- paste("request", b)
    body <- sent[[b]]
    expect_identical(body$model, "test-embed", info = label)
    expect_identical(body$ttl, 60L, info = label)
    expect_identical(body$dimensions, 3L, info = label)
    # A JSON array arrives as an unnamed list, an object as a named one.
    expect_true(is.list(body$input), info = label)
    expect_null(names(body$input), info = label)
    expect_identical(
      unlist(body$input),
      unname(batch_inputs[expected_rows[[b]]]),
      info = label
    )
  }

  expect_identical(dim(out), c(250L, 3L))
  for (i in seq_len(250)) {
    expect_equal(out[i, ], input_vector(i), info = paste("row", i))
  }
})

test_that("a batch_size of 1 sends one request per input", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(lapply(1:3, batch_reply))

  out <- lms_embed("test-embed", three_inputs, batch_size = 1)

  expect_length(recorder$requests, 3L)
  for (i in 1:3) {
    expect_identical(unlist(sent_body(recorder$requests[[i]])$input), three_inputs[[i]])
    expect_equal(out[i, ], input_vector(i))
  }
})

test_that("a later batch of another width aborts, carrying the rows so far", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(
    batch_reply(1:2),
    batch_reply(3:4, width = 4L),
    batch_reply(5)
  ))

  err <- expect_error(
    lms_embed("test-embed", paste("text", 1:5), batch_size = 2),
    "inputs 3 to 4 have 4 dimensions, and earlier ones have 3",
    class = "rlmstudio_bad_response"
  )
  # The third request never goes out.
  expect_length(recorder$requests, 2L)
  expected <- matrix(NA_real_, nrow = 5, ncol = 3)
  expected[1, ] <- input_vector(1)
  expected[2, ] <- input_vector(2)
  expect_identical(err$results, expected)
})

test_that("the width abort names a batch of one input by its position", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    batch_reply(1:2),
    batch_reply(3:4),
    batch_reply(5, width = 4L)
  ))

  expect_error(
    lms_embed("test-embed", paste("text", 1:5), batch_size = 2),
    "the embedding of input 5 has 4 dimensions, and earlier ones have 3",
    class = "rlmstudio_bad_response"
  )
})


# Failed batches --------------------------------------------------------------

# A reply that `embed_matrix()` rejects: one element for a batch of two.
short_reply <- function(position) batch_reply(position)

error_reply <- function(status) {
  mock_response(status, sprintf('{"error": "status %s"}', status))
}

five_inputs <- paste("text", 1:5)

# Run `expr` and keep every warning it gives, so a test can count them.
# `expect_warning()` catches one and lets a second go by.
collect_warnings <- function(expr) {
  warnings <- list()
  value <- withCallingHandlers(
    expr,
    warning = function(w) {
      warnings[[length(warnings) + 1L]] <<- w
      invokeRestart("muffleWarning")
    }
  )
  list(value = value, warnings = warnings)
}

test_that("a bad reply for one batch leaves its rows NA and the call goes on", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(
    batch_reply(1:2),
    short_reply(3),
    batch_reply(5)
  ))

  run <- collect_warnings(lms_embed("test-embed", five_inputs, batch_size = 2))
  out <- run$value
  expect_length(run$warnings, 1L)
  expect_match(
    conditionMessage(run$warnings[[1]]),
    "2 inputs failed, at positions 3 and 4.",
    fixed = TRUE
  )

  expect_length(recorder$requests, 3L)
  expect_equal(out[1, ], input_vector(1))
  expect_equal(out[2, ], input_vector(2))
  expect_true(all(is.na(out[3:4, ])))
  expect_equal(out[5, ], input_vector(5))
})

test_that("an API failure for one batch leaves its rows NA and the call goes on", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    error_reply(400L),
    batch_reply(3:4),
    error_reply(500L)
  ))

  expect_warning(
    out <- lms_embed("test-embed", five_inputs, batch_size = 2),
    "3 inputs failed, at positions 1, 2, and 5."
  )

  expect_true(all(is.na(out[c(1, 2, 5), ])))
  expect_equal(out[3, ], input_vector(3))
  expect_equal(out[4, ], input_vector(4))
})

test_that("the width is set by the first batch that succeeds", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    error_reply(500L),
    batch_reply(3:4, width = 4L),
    batch_reply(5, width = 4L)
  ))

  expect_warning(
    out <- lms_embed("test-embed", five_inputs, batch_size = 2),
    "2 inputs failed, at positions 1 and 2."
  )
  expect_identical(dim(out), c(5L, 4L))
  expect_true(all(is.na(out[1:2, ])))
  for (i in 3:5) {
    expect_equal(out[i, ], input_vector(i, width = 4L), info = paste("row", i))
  }
})

test_that("the warning names every failed position past twenty", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    error_reply(500L),
    error_reply(500L),
    batch_reply(23:33)
  ))

  run <- collect_warnings(
    lms_embed("test-embed", paste("text", 1:33), batch_size = 11)
  )
  expect_length(run$warnings, 1L)
  # Written out here rather than built by cli, the function that joins them.
  expected <- paste0(
    "22 inputs failed, at positions ",
    paste(1:21, collapse = ", "),
    ", and 22."
  )
  expect_match(conditionMessage(run$warnings[[1]]), expected, fixed = TRUE)
})

test_that("the failed-inputs warning shows when the call is quiet", {
  local_mocked_bindings(is_server_running = function(...) TRUE)

  local_request_sequence(list(batch_reply(1:2), error_reply(500L)))
  expect_warning(
    lms_embed("test-embed", paste("text", 1:3), batch_size = 2, quiet = TRUE),
    "1 input failed, at position 3."
  )

  withr::local_options(rlmstudio.quiet = TRUE)
  local_request_sequence(list(batch_reply(1:2), error_reply(500L)))
  expect_warning(
    lms_embed("test-embed", paste("text", 1:3), batch_size = 2),
    "1 input failed, at position 3."
  )

  local_request_sequence(list(batch_reply(1:2), error_reply(500L)))
  expect_warning(
    lms_embed("test-embed", paste("text", 1:3), batch_size = 2, quiet = TRUE),
    "1 input failed, at position 3."
  )
})

test_that("when every batch fails, the call aborts with the first failure", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    error_reply(400L),
    short_reply(3),
    error_reply(500L)
  ))

  # No warning comes before the abort. `expect_no_warning()` fails on one.
  err <- expect_no_warning(
    tryCatch(
      lms_embed("test-embed", five_inputs, batch_size = 2),
      error = identity
    )
  )
  expect_s3_class(err, "rlmstudio_api_error")
  expect_identical(err$status, 400L)
  expect_false("results" %in% names(err))
})


# Aborts that keep the rows so far -------------------------------------------

# The rows that the first batch of two fills, with the other three NA.
first_two_rows <- function() {
  expected <- matrix(NA_real_, nrow = 5, ncol = 3)
  expected[1, ] <- input_vector(1)
  expected[2, ] <- input_vector(2)
  expected
}

test_that("a server lost between batches aborts, carrying the rows so far", {
  probe <- new.env(parent = emptyenv())
  probe$calls <- 0L
  local_mocked_bindings(
    is_server_running = function(...) {
      probe$calls <- probe$calls + 1L
      probe$calls < 2L
    }
  )
  recorder <- local_request_sequence(list(batch_reply(1:2)))

  err <- expect_error(
    lms_embed("test-embed", five_inputs, batch_size = 2),
    class = "rlmstudio_no_server"
  )
  expect_length(recorder$requests, 1L)
  expect_identical(err$results, first_two_rows())
})

test_that("a 401, 403, or 404 aborts at once, carrying the rows so far", {
  local_mocked_bindings(is_server_running = function(...) TRUE)

  for (status in c(401L, 403L, 404L)) {
    label <- paste("status", status)
    recorder <- local_request_sequence(list(
      batch_reply(1:2),
      error_reply(status)
    ))
    err <- expect_error(
      lms_embed("test-embed", five_inputs, batch_size = 2),
      class = "rlmstudio_api_error"
    )
    expect_identical(err$status, status, info = label)
    # The third request never goes out.
    expect_identical(length(recorder$requests), 2L, info = label)
    expect_identical(err$results, first_two_rows(), info = label)
  }
})

test_that("a 401 on the first batch aborts with no results field", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(error_reply(401L)))

  err <- expect_error(
    lms_embed("test-embed", five_inputs, batch_size = 2),
    class = "rlmstudio_api_error"
  )
  expect_identical(length(recorder$requests), 1L)
  expect_false("results" %in% names(err))
})

test_that("a 404 after a failed batch and no success carries no results field", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  recorder <- local_request_sequence(list(error_reply(500L), error_reply(404L)))

  err <- expect_error(
    lms_embed("test-embed", five_inputs, batch_size = 2),
    class = "rlmstudio_api_error"
  )
  expect_identical(err$status, 404L)
  expect_identical(length(recorder$requests), 2L)
  expect_false("results" %in% names(err))
})


# simplify = FALSE over batches ------------------------------------------------

test_that("simplify = FALSE returns one parsed body per request, in order", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  replies <- list(
    batch_reply(1:100),
    batch_reply(101:200, order = 100:1),
    batch_reply(201:250)
  )
  local_request_sequence(replies)

  out <- lms_embed("test-embed", batch_inputs, simplify = FALSE, batch_size = 100)

  expect_identical(out, lapply(replies, httr2::resp_body_json))
})

test_that("simplify = FALSE keeps the condition of a failed request", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    batch_reply(1:2),
    error_reply(500L),
    batch_reply(5)
  ))

  run <- collect_warnings(
    lms_embed("test-embed", five_inputs, simplify = FALSE, batch_size = 2)
  )
  out <- run$value
  expect_length(run$warnings, 1L)
  expect_match(
    conditionMessage(run$warnings[[1]]),
    "2 inputs failed, at positions 3 and 4.",
    fixed = TRUE
  )

  expect_length(out, 3L)
  expect_identical(out[[1]], httr2::resp_body_json(batch_reply(1:2)))
  expect_s3_class(out[[2]], "rlmstudio_api_error")
  expect_identical(out[[2]]$status, 500L)
  # The kept copy drops the backtrace that the raised condition carried.
  expect_null(out[[2]]$trace)
  expect_identical(out[[3]], httr2::resp_body_json(batch_reply(5)))
})

test_that("with simplify = FALSE an abort carries the list so far", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(batch_reply(1:2), error_reply(404L)))

  err <- expect_error(
    lms_embed("test-embed", five_inputs, simplify = FALSE, batch_size = 2),
    class = "rlmstudio_api_error"
  )
  expect_identical(
    err$results,
    list(httr2::resp_body_json(batch_reply(1:2)), NULL, NULL)
  )
})


# The progress bar -------------------------------------------------------------

# Record the bars that are made and the updates they get, without drawing any.
local_bar_recorder <- function(.env = parent.frame()) {
  log <- new.env(parent = emptyenv())
  log$bars <- list()
  log$updates <- list()
  local_mocked_bindings(
    cli_progress_bar = function(...) {
      log$bars[[length(log$bars) + 1L]] <- list(...)
      "bar-id"
    },
    cli_progress_update = function(...) {
      log$updates[[length(log$updates) + 1L]] <- list(...)
      invisible()
    },
    cli_progress_done = function(...) invisible(),
    .package = "cli",
    .env = .env
  )
  log
}

run_250 <- function(...) {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  local_request_sequence(list(
    batch_reply(1:100),
    batch_reply(101:200),
    batch_reply(201:250)
  ))
  lms_embed("test-embed", batch_inputs, batch_size = 100, ...)
}

test_that("a call of three requests shows one bar that counts inputs", {
  withr::local_options(rlmstudio.quiet = NULL)
  log <- local_bar_recorder()

  run_250()

  expect_length(log$bars, 1L)
  expect_identical(log$bars[[1]]$total, 250L)
  expect_length(log$updates, 3L)
  expect_identical(
    vapply(log$updates, function(u) as.integer(u$inc), integer(1)),
    c(100L, 100L, 50L)
  )
})

test_that("no bar shows when quiet, or for one request", {
  log <- local_bar_recorder()

  # The option says not quiet, so only the argument can hide the bar.
  withr::with_options(list(rlmstudio.quiet = FALSE), run_250(quiet = TRUE))
  expect_length(log$bars, 0L)

  withr::with_options(list(rlmstudio.quiet = TRUE), run_250())
  expect_length(log$bars, 0L)

  withr::local_options(rlmstudio.quiet = NULL)
  drive_embed(in_order_body, input = three_inputs)
  expect_length(log$bars, 0L)
  expect_length(log$updates, 0L)
})


# Against a live server --------------------------------------------------------

test_that("live: batches of two give the vectors of one request", {
  testthat::skip_on_cran()
  skip_if_no_server()

  # The test never loads a model, so a run leaves the server as it found it.
  model <- "text-embedding-nomic-embed-text-v1.5"
  loaded_embedding_models(model)

  texts <- c(
    "a cat sat on the mat",
    "the stock market fell sharply today",
    "R is a language for statistics",
    "short",
    "embedding vectors from a local server"
  )
  one <- lms_embed(model, texts)
  batched <- lms_embed(model, texts, batch_size = 2, quiet = TRUE)

  expect_identical(dim(batched), c(5L, ncol(one)))
  expect_lt(max(abs(batched - one)), 1e-6)
})

test_that("live: the server embeds only the first context-length tokens", {
  testthat::skip_on_cran()
  skip_if_no_server()

  # The help page says that the server cuts a text at the context length of
  # the loaded instance and says nothing about it. This pins what it says.
  # The test never loads a model, so a run leaves the server as it found it.
  model <- "text-embedding-nomic-embed-text-v1.5"
  models <- loaded_embedding_models(model, detailed = TRUE)

  # With one instance, the request goes to it, so `n` is its context length.
  instances <- models$loaded_instances[[match(model, models$key)]]
  n <- instances$config$context_length
  if (length(n) != 1L || is.na(n)) {
    testthat::skip(
      paste(model, "needs exactly one instance with a context length.")
    )
  }

  # Each word below is at least one token, so a start of `n` words reaches
  # past the cut.
  words <- c("river", "stone", "cloud", "market", "green", "table", "music")
  start <- rep_len(words, n)
  tail_one <- rep_len(c("apple", "house"), 200)
  tail_two <- rep_len(c("ocean", "piano"), 200)
  mid <- n %/% 2
  texts <- c(
    paste(c(start, tail_one), collapse = " "),
    paste(c(start, tail_two), collapse = " "),
    paste(c("window", start[-1], tail_one), collapse = " "),
    paste(c(start[seq_len(mid - 1)], "window", start[-seq_len(mid)], tail_one),
      collapse = " ")
  )

  out <- expect_no_warning(lms_embed(model, texts))
  # Texts that differ only past the cut get the same vector.
  expect_lt(max(abs(out[1, ] - out[2, ])), 1e-6)
  # A text that differs inside the cut gets another vector, so the match
  # above comes from the cut and not from a server that ignores the text.
  expect_gt(max(abs(out[1, ] - out[3, ])), 1e-6)
  # A probe on 2026-09-28 (LM Studio 0.4.25+1, context 2048) put the cut
  # between word 2040 and word 2100 of such a text, about one token per word.
  # So word `mid` lies inside the context, and a server that cut far earlier
  # gives the same vector here.
  expect_gt(max(abs(out[1, ] - out[4, ])), 1e-6)

  bodies <- lms_embed(model, texts, simplify = FALSE)
  expect_identical(bodies[[1]][["usage"]][["prompt_tokens"]], 0L)
})


# simplify = FALSE: the aborts that apply and the one that does not -------------

test_that("with simplify = FALSE, every batch failing aborts with the first", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  # A reply with too few vectors is not a failure here, because this form
  # skips the matrix checks, so both requests fail on status.
  local_request_sequence(list(error_reply(500L), error_reply(400L)))

  err <- expect_no_warning(
    tryCatch(
      lms_embed(
        "test-embed",
        paste("text", 1:4),
        simplify = FALSE,
        batch_size = 2
      ),
      error = identity
    )
  )
  expect_s3_class(err, "rlmstudio_api_error")
  expect_identical(err$status, 500L)
  expect_false("results" %in% names(err))
})

test_that("with simplify = FALSE, a lost server carries the list so far", {
  probe <- new.env(parent = emptyenv())
  probe$calls <- 0L
  local_mocked_bindings(
    is_server_running = function(...) {
      probe$calls <- probe$calls + 1L
      probe$calls < 2L
    }
  )
  local_request_sequence(list(batch_reply(1:2)))

  err <- expect_error(
    lms_embed("test-embed", five_inputs, simplify = FALSE, batch_size = 2),
    class = "rlmstudio_no_server"
  )
  expect_identical(
    err$results,
    list(httr2::resp_body_json(batch_reply(1:2)), NULL, NULL)
  )
})

test_that("with simplify = FALSE, bodies of two widths come back with no abort", {
  local_mocked_bindings(is_server_running = function(...) TRUE)
  replies <- list(
    batch_reply(1:2),
    batch_reply(3:4, width = 4L),
    batch_reply(5)
  )
  local_request_sequence(replies)

  out <- expect_no_error(
    lms_embed("test-embed", five_inputs, simplify = FALSE, batch_size = 2)
  )
  expect_identical(out, lapply(replies, httr2::resp_body_json))
})
