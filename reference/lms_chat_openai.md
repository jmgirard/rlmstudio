# Chat Completion via OpenAI Compatibility API

Direct interface to LM Studio's OpenAI-compatible endpoint. Uses the
messages array format.

## Usage

``` r
lms_chat_openai(
  model,
  messages,
  host = "http://localhost:1234",
  logprobs = FALSE,
  simplify = TRUE,
  ...,
  schema = NULL,
  ttl = NULL,
  token = NULL
)
```

## Arguments

- model:

  Character. The loaded model name. Must be one name, given as a single
  string.

- messages:

  The messages to send. Give an unnamed list with one element per
  message, such as `list(list(role = "user", content = "Hi"))`, or a
  data frame with at least one row. A data frame is sent as one message
  per row, with one field per column. A cell that is `NA` is left out of
  its message. The call aborts before it checks for a running server if
  `messages` breaks one of these rules:

  - `messages` is a list or a data frame.

  - A data frame has at least one row, and any other list has at least
    one element.

  - A list that is not a data frame has no names. A single message not
    wrapped in a list, such as `list(role = "user", content = "Hi")`,
    breaks this rule.

  - Each element of such a list is a list of length one or more, and
    each of its fields has a name that is not `NA` and not empty. A data
    frame as an element breaks this rule.

  - A data frame has at least one column, and no column name is `NA`,
    empty, or repeated.

  - A data frame has no row in which every cell is `NA` or is a `NULL`
    cell of a list column. jsonlite leaves out an `NA` cell of another
    column and writes an `NA` or `NULL` list cell as `null`, so such a
    row holds no field value. A
    [`list()`](https://rdrr.io/r/base/list.html) cell is sent as `[]`
    and a `list(NA)` cell as `[null]`, so a row with such a cell is
    sent. A column with a `dim` attribute of any length whose first
    extent is the row count, such as a matrix or an array, counts as
    empty in a row when each of its cells in that row is empty. Such a
    column with no cells in a row, such as a 2-by-0 matrix, is not empty
    in that row, because jsonlite writes that row of it as `[]` or as
    nested empty arrays. A data-frame column counts as empty in a row
    when each of its own columns is empty in that row. So a data-frame
    column with no columns counts as empty in every row. A column that
    is neither an atomic vector nor a list, such as an environment,
    never counts as empty.

  - `messages`, when it is a list and not a data frame, has no `dim`
    attribute, such as a matrix or an array of messages.

  - A message that is a list has no `dim` attribute.

  - No list inside a message has a `dim` attribute. The rule reads each
    field, each list at any depth below a field, and each cell of a list
    column. jsonlite would send such a list as nested arrays with each
    cell in an array of its own. A list column of a data frame with one,
    three, or more dimensions also breaks this rule. An atomic matrix
    field is sent as an array of arrays. A list-matrix column of any
    data frame is sent, one row of cells for each message. jsonlite does
    not unbox a value inside a list-matrix cell, at any depth in a list,
    unless
    [`jsonlite::unbox()`](https://jeroen.r-universe.dev/jsonlite/reference/unbox.html)
    wraps it. A data frame in a cell is sent as an array of objects
    whose values are not boxed. So a length-one atomic cell is sent as a
    one-element array, such as `["a"]`, and a `NULL` cell is sent as
    `null`. For example, a row with `role` `"user"`, `content` `"hi"`,
    and the cells `"a"`, `NULL`, and `list(k = "v")` in a list-matrix
    column `tags` is sent as
    `{"role":"user","content":"hi","tags":[["a"],null,{"k":["v"]}]}`.

  - No message, and no list or data frame inside a message or inside a
    cell or column of a data frame, has a name that is `NA`, empty, or
    repeated. jsonlite would send an `NA` or empty name as a number and
    rename a repeated name `a` to `a.1`. A list with no names passes.
    The names of a list column are not checked, because they are not
    sent. The names of an atomic vector and the column names of a matrix
    are not checked, because jsonlite sends those values as arrays.

  The error for each rule above opens with "`messages` must be a data
  frame or an unnamed list of messages." and shows the form of a
  message. Four more rules are checked after them. Their error opens
  with "`messages` holds a field value that cannot be sent as JSON." and
  shows no form:

  - No function sits inside `messages`: not as a field, in a list below
    a field, as a column of a data frame, or in a cell of a list column.
    jsonlite would send a function as its source text. A function with a
    class gets the error of this rule, not the error of a later one.

  - Each value inside `messages`, in the places the rule above reads, is
    an atomic vector, a list, or `NULL`. An environment, a symbol, a
    call, a formula, an expression vector, an external pointer, or an S4
    object breaks this rule, and the error names its type. The rule
    reads the storage type, so a class set by hand on such a value does
    not hide it. jsonlite would send such a value as printed text, as
    `null`, or as an object or array of other data, or it would fail. A
    `NULL` field passes and is sent as `null`. An S4 object whose class
    contains an atomic type, such as `"numeric"`, passes this rule, and
    jsonlite sends its data part without its other slots. An S4 object
    whose class contains `"list"` passes, and the rule reads its
    elements. The rule does not read the class of a vector or a list. A
    vector with a class set by hand, such as
    `structure(1L, class = "NULL")`, passes, and jsonlite writes it by
    that class.

  - No number inside `messages` is `NA`, `NaN`, `Inf`, or `-Inf`. The
    rule reads a double or integer vector with no class or with the
    class `"AsIs"` alone, such as a field wrapped in
    [`I()`](https://rdrr.io/r/base/AsIs.html). jsonlite would send such
    a number as the string `"NA"`, `"NaN"`, `"Inf"`, or `"-Inf"`. The
    rule reads a field, an element of a field, a list at any depth below
    a field, a cell of a list column or a list-matrix column, and a
    matrix or array column. An atomic column with no `dim` attribute, of
    a data frame at any depth, is the exception. jsonlite leaves an
    `NA`, `NaN`, `Inf`, or `-Inf` cell of such a column out of its
    message. There the rule refuses `Inf` and `-Inf` alone, and an `NA`
    or `NaN` cell is left out as a missing field. A number with another
    class, such as a `Date`, is written by its class, so `as.Date(NA)`
    is sent as `null` and `as.Date(Inf)` as `"Inf"`. Below a message,
    the rule reads the parts of a list whose class is neither `"AsIs"`
    nor a data frame only when jsonlite writes that list as it writes
    the list without its class, such as a list with the class
    `c("foo", "list")`. It does not read the parts of a `POSIXlt` value.

  - jsonlite can write the value, with the options that the request
    uses. If it cannot, the error gives the jsonlite message. This rule
    is checked last.

  A list that is not a data frame is sent without its class attribute,
  and each of its messages is sent without its class attribute. A class
  on a field inside a message is kept, so a field wrapped in
  [`I()`](https://rdrr.io/r/base/AsIs.html) is sent as an array. A data
  frame and its columns keep their classes. A kept class that jsonlite
  has no method for, such as a field with the class `"foo"` alone,
  breaks the last rule.

  The package checks the shape of `messages`. Of the field values, it
  refuses a function, a value that is not an atomic vector, a list, or
  `NULL`, a number with no class or with the class `"AsIs"` alone that
  jsonlite would send as a string or, in a data-frame column, would
  leave out because it is infinite, and a value that jsonlite cannot
  write. It does not check any other value of a role, the content, or
  another field of a message. The server checks them.

- host:

  Character. Server URL.

- logprobs:

  Logical. Whether to request logprobs (currently stubbed by LM Studio).

- simplify:

  Logical. If TRUE, parses output to text.

- ...:

  Additional API arguments. A `response_format` here cannot be combined
  with `schema`. The package checks a `stream` here. A `stream` other
  than `FALSE` or `NULL` aborts before the call checks for a running
  server, because the package reads a whole reply and not a streamed
  one.

- schema:

  A JSON Schema, written as a named list, that the reply must match, or
  `NULL` for a free text reply. It is sent as the `schema` field of a
  `response_format` of type `"json_schema"`, with the name `"response"`
  and `strict` set to `true`. A JSON array of one item must be written
  as a list, such as `required = list("score")`, or wrapped in
  [`I()`](https://rdrr.io/r/base/AsIs.html). A plain vector of length
  one is sent as a single value, not as an array. An empty object nested
  in the schema, such as `properties`, is written
  `setNames(list(), character())`, because
  [`list()`](https://rdrr.io/r/base/list.html) is sent as the empty
  array `[]`. The package checks only that `schema` is a named list, an
  empty list, or `NULL`. The server checks the schema itself.

- ttl:

  A whole number of seconds from 1 to `.Machine$integer.max`, or `NULL`
  to leave it out. It is how long the model stays loaded with no
  request. It has an effect only on a model that this request loads. The
  server loads a model that is not loaded yet when its just-in-time
  loading setting is on. A model that is already loaded keeps its idle
  time.

- token:

  Character or `NULL`. An API token for a server that requires
  authentication. `NULL` reads the `rlmstudio.token` option and then the
  `RLMSTUDIO_API_TOKEN` environment variable. See
  [rlmstudio_token](https://jmgirard.github.io/rlmstudio/reference/rlmstudio_token.md).

## Value

If `simplify = FALSE`, returns a list representing the raw JSON
response. A status-200 body that does not parse as JSON raises
`rlmstudio_bad_response` with either setting of `simplify`. Otherwise,
returns a character string containing the generated text. If
`logprobs = TRUE`, it returns an `lms_chat_result` object with the log
probabilities populated as `NULL` since they are currently stubbed in
the LM Studio OpenAI endpoint. With `simplify = TRUE`, reply content
that is not one string, such as the `null` content of a reply that holds
only a tool call, raises `rlmstudio_bad_response`.

With a `schema`, `simplify = TRUE`, and `logprobs = FALSE`, the reply is
parsed with `jsonlite::parse_json(simplifyVector = TRUE)` and the parsed
value is returned. A JSON object becomes a named list, and an array of
numbers becomes a vector. With `simplify = FALSE` or `logprobs = TRUE`,
the reply stays a string. With a `schema`, `simplify = TRUE`, and
`logprobs = FALSE`, a reply that a length limit ended raises
`rlmstudio_bad_response`, also when it parses. With `simplify = TRUE` in
any other setting, such a reply whose content is one string is returned
with a warning. See the "Cut-off reply" section.

With `simplify = TRUE`, the reply is read from the first element of the
`choices` field. No other element of `choices` is read. A request with
`n` in `...` therefore returns the first choice alone, and the cut-off
warning and abort depend on the finish reason of that choice alone. With
`simplify = FALSE`, the body holds every choice.

With either setting of `simplify`, a reply from a model other than the
one asked for raises `rlmstudio_model_mismatch`. See the "Reply from
another model" section.

## Server not running

Functions that call the LM Studio REST API open a TCP connection to the
hostname and port named in `host` before they send the request. A
function that checks its own arguments does that first, so a bad
`model`, `job_id`, `input`, `inputs`, `messages`, `schema`, `ttl`, or
`batch_size`, or a `stream` in the `...` of a chat function, aborts with
an argument message and no condition class even when the server is down.
A condition of class `rlmstudio_no_server` is raised when that
connection cannot be opened. A refused connection raises it. So do an
address the package cannot parse and a hostname that does not resolve.
An address that neither accepts nor refuses the connection also raises
it. That case waits for the operating system to give up, which can take
a minute. Start the server with
[`lms_server_start()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_start.md),
or give `host` the address that your server listens on.

The check reads the port and nothing else. Any process holding that port
accepts the connection, so the condition is not raised even though no LM
Studio server is there. The call then does not raise
`rlmstudio_no_server`, and what it does depends on what answers. On a
status-200 body that does not parse as JSON, the chat functions,
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
and
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
raise `rlmstudio_bad_response`.
[`lms_unload()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload.md)
does not read the body, so it can report success. A body that parses as
JSON but has another shape can come back unchanged with
`simplify = FALSE`. With `simplify = TRUE`, the chat functions and
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
raise `rlmstudio_bad_response` for it.
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
raises it for a model list with another shape, and so do
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
and
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
without `force = TRUE`, which read that list.
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
and
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
raise it for a reply of their own with another shape, such as
[`{}`](https://rdrr.io/r/base/Paren.html). A process that does not
answer in HTTP gives an `httr2_failure` error. Use
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
for the stronger test: it asks the host for a model list and reports
`TRUE` only for a model list that
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
can read.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
checks the server once before its first input, and
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
checks it again for each input. If that check finds the server gone
during the batch, the batch aborts with `rlmstudio_no_server`, and no
request goes out after that. The condition then carries a `results`
field, a list as long as `inputs`. Its elements before the lost input
hold the values that `format = "list"` returns for those inputs. The
element of the lost input and every element after it are `NULL`. The
check before the first input adds no `results` field. A connection that
fails after the check passes, such as a server that stops during a
request, raises an `httr2_failure` error instead. That error aborts the
batch and carries no `results` field.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
checks the server before each request, and a request carries at most
`batch_size` inputs. If a check after the first request finds the server
gone, the call aborts with `rlmstudio_no_server`. Once a request has
succeeded, the condition carries a `results` field. With
`simplify = TRUE`, `results` is a matrix with `NA` in each row whose
embedding did not arrive. With `simplify = FALSE`, it is a list with one
element per batch, with `NULL` in the element of the request that ended
the call and in every element after it.

## API failure

A condition of class `rlmstudio_api_error` is raised when a REST call
returns a response that the wrapper treats as a failure. The condition
carries a `status` field, which holds the HTTP response status as an
integer. It also carries a `code` field. The field holds the string at
`error.code` of the response body, such as `"model_not_found"`. It is
`NULL` when the body does not parse, when `error` is not a JSON object,
or when its `code` is not one string.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
aborts on it when its `status` is 401, 403, or 404, and when its
`status` is 400 and its `code` is `"model_not_found"`. No request goes
out after that input. The condition then carries a `results` field that
follows the rule for a lost server in the "Server not running" section:
its elements before the failed input hold the values that
`format = "list"` returns for those inputs, and the element of the
failed input and every element after it are `NULL`. For any other
status, the element of the failed input holds the condition, or `NA`
where the result is text, and the batch warns once and goes on. See the
details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
follows the same rule for each request. A 401, 403, or 404 aborts the
call, and once a request has succeeded the condition carries a `results`
field, a matrix or a list as the "Server not running" section describes.
Any other status fails the inputs of that request alone, and the call
warns once and goes on. If every request fails, the call aborts with the
first condition. See the details of
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md).

## Malformed response

A condition of class `rlmstudio_bad_response` is raised when the server
answers with a status the wrapper accepts and a body the wrapper cannot
read. It is raised where a wrapper checks the body before it reshapes
it, rather than indexing straight into whatever arrived. Ten functions
raise it:
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md),
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md),
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
`lms_chat_openai()`,
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md),
and
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md).
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
raises it through the chat function it calls.
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
raises it through
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md),
and so does
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
unless `force = TRUE`.

All ten raise it for a status-200 body that does not parse as JSON, such
as an HTML page from a proxy, JSON text that stops part way, or an empty
body. In the functions that take `simplify`, the body is parsed before
`simplify` is read, so the condition is raised whatever `simplify` is.
The body is parsed by its content and not by its `Content-Type` header,
so valid JSON under `text/plain` is read as JSON. The body is read as
JSON text and nothing else. A body whose text is a URL or the path of a
file does not parse, and the package does not fetch the URL or read the
file. The message says that the body did not parse as JSON and that
something other than LM Studio may be answering on the host. It does not
hold the body text.

[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md)
also raises it for a status-200 model list with the wrong shape.
[`lms_unload_all()`](https://jmgirard.github.io/rlmstudio/reference/lms_unload_all.md)
and
[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
without `force = TRUE` raise it through
[`list_models()`](https://jmgirard.github.io/rlmstudio/reference/list_models.md).
A model list must follow four rules. Each field is read by its exact
name, so a field named `keyX` does not stand in for `key`.

1.  The body is a JSON object whose `models` field is an array. The
    array can be empty.

2.  Each entry of `models` is a JSON object. Its `type` and `key` are
    strings, and its `loaded_instances` is an array.

3.  The `size_bytes` of an entry is a number, or absent, or `null`.

4.  Each entry of `loaded_instances` is a JSON object whose `id` is a
    string with a character that is not whitespace.

The rules are checked before the `type` and `loaded` filters, so an
entry that the filters drop can still raise the condition. The message
names the field or entry that broke a rule.
[`lms_server_ready()`](https://jmgirard.github.io/rlmstudio/reference/lms_server_ready.md)
applies the same rules and returns `FALSE` for a body that breaks one.

[`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md),
[`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md),
and
[`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
also raise it for a status-200 reply of their own with the wrong shape.
Each reply must follow the rule of its function. Each field is read by
its exact name. The rules check the type of a field and not its value,
with four exceptions. The `status` of a load reply must be `"loaded"`. A
download reply whose `status` is `"already_downloaded"` needs no
`job_id`. A download reply whose `status` is `"failed"` always aborts.
The `job_id` of any other download reply must hold a character that is
not whitespace.

1.  A reply of
    [`lms_load()`](https://jmgirard.github.io/rlmstudio/reference/lms_load.md)
    is a JSON object whose `status` is the string `"loaded"`. With
    `echo_load_config = TRUE`, its `load_config` is also a JSON object.

2.  A reply of
    [`lms_download()`](https://jmgirard.github.io/rlmstudio/reference/lms_download.md)
    is a JSON object whose `status` is a string other than `"failed"`.
    If the status is not `"already_downloaded"`, its `job_id` is a
    string with a character that is not whitespace. For a `"failed"`
    status, the message says that LM Studio reports that the download
    failed. It names the reply's `job_id` if that is a string with a
    character that is not whitespace.

3.  A reply of
    [`lms_download_status()`](https://jmgirard.github.io/rlmstudio/reference/lms_download_status.md)
    is a JSON object whose `job_id` and `status` are strings. Its
    `total_size_bytes`, `downloaded_bytes`, and `bytes_per_second` are
    each a number, or absent, or `null`.

For the other faults, the message names the field that broke the rule,
or it says that the body is not a JSON object. It also says that
something other than LM Studio may be answering on the host.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
raises it on an embeddings block it cannot trust. The vectors it returns
are placed by the index that the response reports, so a block with a
missing, repeated, or out-of-range index would otherwise pair a vector
with the wrong text and give back a matrix that is silently wrong.

[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
reads each request on its own. A bad body, of either kind above, fails
the inputs of that request alone, and the call warns once and goes on.
The call aborts with the condition only if every request fails, and then
with the condition of the first. With `simplify = TRUE`, it also aborts
with `rlmstudio_bad_response` for a request whose embeddings have
another number of dimensions than those of an earlier request. That
condition carries a `results` field, a matrix as the "Server not
running" section describes. See the details of
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md).

[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md)
and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
raise it with `simplify = TRUE` when the reply holds no readable answer
text. Both read the answer from the items of type `"message"` in the
`output` array. They raise it when `output` is missing, empty, or not an
array, or when an item in it is not a JSON object. They also raise it
when no item has the type `"message"`, as in a reply that holds only
reasoning or a tool call. The text of a message must be one string. For
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md)
that is the `content` of the item. For
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
it is the `text` of each part of type `"output_text"`. For
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
only, the `content` of each message must be an array of JSON objects,
and the messages together must hold at least one `"output_text"` part.

With `simplify = TRUE` and `logprobs = TRUE`,
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
also raises it for a `logprobs` value that breaks one of these rules.
The `logprobs` value of each `"output_text"` part is checked. A
`logprobs` value, `token`, `logprob`, or `top_logprobs` that is `null`
or absent passes its rule. A `null` step or candidate breaks rule 2 or
rule 5.

1.  The value is an array.

2.  Each step in the array is a JSON object.

3.  The `token` of a step is a string.

4.  The `logprob` of a step is a number.

5.  The `top_logprobs` of a step is an array of JSON objects.

6.  The `token` and `logprob` of each of those objects follow rules 3
    and 4.

The parts are checked in order, then the steps of a part, then the
candidates of a step, one at a time. Within a step, rules 3 and 4 and
the array test of rule 5 come before the candidates. The message names
the first broken rule that this order reaches. These checks run only
after the text of every `"output_text"` part is read, so a reply that
also has a bad `text` in any part gets the text message. Parts of other
types, such as a refusal, are not checked, and with `logprobs = FALSE`
no part is checked. Fields are read by their exact names, so a field
whose name only starts with the one asked for, such as `tokenX`, reads
as absent and gives `NA` in the data frame.

Apart from a body that does not parse as JSON, `lms_chat_openai()`
raises it in four cases, all only with `simplify = TRUE`. The first case
is a response whose `choices` field is missing, empty, or not an array,
or whose first element is not a JSON object with a `message` object in
it, so there is no reply to read. This case is raised with or without a
`schema`, and with `logprobs = TRUE` as well. The second case is a reply
that does not parse. A `schema` was given, `logprobs = FALSE`, and the
reply content is not one string of valid JSON. The third case is reply
content that is not one string, such as `null`, a missing `content`
field, a number, or an array. A reply that holds only a tool call has
`null` content. This case is raised without a `schema`, and with
`logprobs = TRUE` with or without one. The fourth case is a cut-off
reply. A `schema` was given, `logprobs = FALSE`, and the server reports
the finish reason `"length"`. This case is raised also when the reply
content parses, because a reply that stops part way can parse to a wrong
value, such as the first digit of a longer number. In the second, third,
and fourth cases, if the server reports the finish reason `"length"`, a
length limit ended the reply. The limit is `max_tokens` or the context
length of the model. The message then says so and names both. A cut-off
reply that is returned as text gives a warning of class
`rlmstudio_reply_cut_off` instead, which
[rlmstudio-conditions](https://jmgirard.github.io/rlmstudio/reference/rlmstudio-conditions.md)
describes.

With `simplify = TRUE`,
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md),
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md),
and `lms_chat_openai()` also raise it for a body that is a bare JSON
value, such as `5`, `"s"`, or `true`. The message says that the response
body is not a JSON object. A body of `null` gets the message about its
missing `output` or `choices` field instead.
[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
can raise the condition through all three chat functions.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
does not abort on it, except on the subclass `rlmstudio_model_mismatch`,
as the "Reply from another model" section of
[rlmstudio-conditions](https://jmgirard.github.io/rlmstudio/reference/rlmstudio-conditions.md)
says. The element of the failed input holds the condition, or `NA` where
the result is text, and the batch warns once and goes on. See the
details of
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md).

The condition carries a `status` field, which holds the HTTP response
status as an integer. Today the status is always 200: each of these
functions reads the body only after a 200, and reports every other
status as an `rlmstudio_api_error` instead. A condition from
`lms_chat_openai()` about its reply also carries two more fields. A
condition from the model-list lookup does not, as the "Reply from
another model" section says. The `content` field holds the reply content
of the first choice, and the `finish_reason` field holds the finish
reason of the first choice. Both are `NULL` for a response with no
`choices`. In the third case, `content` holds the value that was read,
which is `NULL` for `null` or missing content. For the second, third,
and fourth cases, the message names the `content` field, so you can read
what the model wrote without a second request. The other messages of the
chat functions and
[`lms_embed()`](https://jmgirard.github.io/rlmstudio/reference/lms_embed.md)
name `simplify = FALSE`, which returns the body unchanged, with one
exception. A body that did not parse as JSON is checked before that
argument is read, so its message points at the host instead. For such a
body, the `content` and `finish_reason` fields of a condition from
`lms_chat_openai()` are `NULL`.

## Cut-off reply

A warning of class `rlmstudio_reply_cut_off` is given when a length
limit ended a reply that `lms_chat_openai()` returns as text. The server
reports this with the finish reason `"length"`. The limit is
`max_tokens` or the context length of the model, and the reply does not
say which one. The message names both. The warning is given with
`simplify = TRUE` for reply content that is one string, in three
settings: no `schema`, `logprobs = TRUE`, and a `schema` with
`logprobs = TRUE`. The call returns what the same reply returns without
the cut-off. A `schema` reply with `logprobs = FALSE` raises
`rlmstudio_bad_response` instead, as the "Malformed response" section
says. The warning and that abort read the finish reason of the first
choice, which is the choice that the call reads. No other element of
`choices` is read. With `simplify = FALSE`, the call returns the body
with every choice and no warning.

[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
gives the warning through `lms_chat_openai()` with
`api_type = "openai"`.
[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
gives one warning of this class for the whole batch in place of one for
each input. It names the count and the positions of the cut-off inputs,
and each of those elements keeps its reply. It comes after the warning
about failed inputs. A batch that aborts with a `results` field gives
this warning before the abort. It names the cut-off inputs whose replies
the `results` field of the abort holds. The native and OpenResponses
routes give no such warning.

The warning shows whatever `quiet` and the `rlmstudio.quiet` option say,
because it is the only sign that an answer is not complete.

## Reply from another model

`lms_chat_openai()` and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md)
read the `model` field of each status-200 reply, with either setting of
`simplify`. On LM Studio 0.4.25+1 with one chat model loaded, both
routes answered a model name that the server could not find with status
200 and a reply from the loaded model. With two chat models loaded, they
answered with status 400 and the `code` `"model_not_found"`, as the "API
failure" section describes. The `model` field names the loaded instance
that answered. Its id can differ from the key that the call asked for.

If the `model` field equals the name that the call sent, the reply is
accepted. If it differs, the call sends one request for the model list
to `api/v1/models` on the same host, with the token of the call, and
prints no message. The reply is accepted if a model whose key equals the
asked name in any letter case has a loaded instance whose id is the
`model` field. Otherwise the call aborts with a condition of class
`rlmstudio_model_mismatch`. That condition is also an
`rlmstudio_bad_response`, and its `status` is 200. Its `model` field
holds the asked name, and its `reply_model` field holds the `model`
field of the reply. The message names both. A condition from
`lms_chat_openai()` also carries the `content` and `finish_reason`
fields, both `NULL`.

The check runs before the reply is read, so it also runs with
`logprobs = TRUE`, with a `schema` on `lms_chat_openai()`, and for a
reply with no answer text. A reply is not checked if its body is not a
JSON object, if it has no `model` field, or if its `model` is not one
string or holds only whitespace. A body that is not a JSON object is
returned with `simplify = FALSE`, and with `simplify = TRUE` it raises
the error that the "Malformed response" section describes. If the
instance that answered is unloaded before the model-list request, the
call aborts, also when that instance belongs to the asked model.

If the model-list request fails, the call raises the condition of that
failure. The message opens with the label of the chat function, followed
by "because the model-list lookup failed". A status other than 200
raises `rlmstudio_api_error`. A body that does not parse as JSON, or
that breaks a rule of a model list in the "Malformed response" section,
raises `rlmstudio_bad_response`. A server that the port check before the
request cannot reach raises `rlmstudio_no_server`. A condition from the
lookup does not carry the `content` and `finish_reason` fields, also
when `lms_chat_openai()` raises it.

[`lms_chat()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat.md)
runs the check through `lms_chat_openai()` and
[`lms_chat_openresponses()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_openresponses.md).
[`lms_chat_native()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_native.md)
does not check the reply. On LM Studio 0.4.25+1, `/api/v1/chat` answered
a name that it could not find with status 404, which raises
`rlmstudio_api_error`.

[`lms_chat_batch()`](https://jmgirard.github.io/rlmstudio/reference/lms_chat_batch.md)
aborts at the first input that raises `rlmstudio_model_mismatch`, on the
`"openai"` and `"openresponses"` routes. It also aborts at an
`rlmstudio_api_error` with status 400 whose `code` is
`"model_not_found"`. No request goes out after that input. In both
cases, the condition carries a `results` field that follows the rule for
a lost server in the "Server not running" section.

## Examples

``` r
if (FALSE) { # \dontrun{
lms_chat_openai(
  model = "google/gemma-3-1b",
  messages = list(
    list(role = "user", content = "Rate 'Great value.' from 1 to 5.")
  ),
  schema = list(
    type = "object",
    properties = list(score = list(type = "integer")),
    required = list("score")
  )
)
} # }
```
