#' Conditions raised by rlmstudio
#'
#' The functions in this package that talk to the LM Studio REST API raise
#' four condition classes of their own. One of them,
#' `rlmstudio_model_mismatch`, is also an `rlmstudio_bad_response`, and the
#' "Reply from another model" section describes it. Each one is raised through
#' [cli::cli_abort()], so each one is an R error that you can catch by class
#' with [base::tryCatch()]. The chat functions on the OpenAI route also give
#' one warning class of their own, described in the "Cut-off reply" section.
#'
#' @section Server not running:
#' Functions that call the LM Studio REST API open a TCP connection to the
#' hostname and port named in `host` before they send the request. A function
#' that checks its own arguments does that first, so a bad `model`, `job_id`,
#' `input`, `inputs`, `messages`, `schema`, `ttl`, `previous_response_id`,
#' or `batch_size`, a bad
#' `type` of [list_models()] or [list_instances()], a bad `TRUE` or `FALSE`
#' argument such as `simplify`, `logprobs`, `quiet`, `force`, or `store`, a
#' `store` on the `"openai"` route of [lms_chat()] or [lms_chat_batch()], a
#' `stream` in
#' the `...` of a chat function, a `logprobs` in the `...` of
#' [lms_chat_batch()] or [lms_chat_native()], a value in the `...` of
#' [lms_chat_batch()] that [lms_chat()] reads as an argument already given,
#' an `instructions` or `messages` in the `...` of [lms_chat()] or
#' [lms_chat_batch()] on the route where [lms_chat()] sets it, or a name, id,
#' or `type` string that is not valid in its encoding or is marked as bytes,
#' aborts
#' with an argument message and no condition class even when the server is
#' down. A condition of class
#' `rlmstudio_no_server` is raised when that connection cannot be opened. A
#' refused connection raises it. So do an address the package cannot parse and
#' a hostname that does not resolve. An address that neither accepts nor
#' refuses the connection also raises it. That case waits for the operating
#' system to give up, which can take a minute. Start the server with
#' [lms_server_start()], or give `host` the address that your server listens
#' on.
#'
#' The check reads the port and nothing else. Any process holding that port
#' accepts the connection, so the condition is not raised even though no LM
#' Studio server is there. The call then does not raise
#' `rlmstudio_no_server`, and what it does depends on what answers. On a
#' status-200 body that does not parse as JSON, the chat functions,
#' [lms_embed()], [list_models()], [list_instances()], [lms_load()],
#' [lms_download()], [lms_download_status()], and [lms_unload_all()] raise
#' `rlmstudio_bad_response`. [lms_unload()] does not read the body, so it can
#' report success. A body that parses as JSON but has another shape can
#' come back unchanged with `simplify = FALSE`. With `simplify = TRUE`, the
#' chat functions and [lms_embed()] raise `rlmstudio_bad_response` for it.
#' [list_models()] and [list_instances()] raise it for a model list with
#' another shape, and so do [lms_unload_all()] and [lms_load()] without
#' `force = TRUE`, which read that list. [lms_chat_openai()] and
#' [lms_chat_openresponses()] raise it for such a model list too, with either
#' setting of `simplify`, through the model lookup that a reply from another
#' model starts. [lms_chat()] raises it through them. [lms_load()],
#' [lms_download()], and [lms_download_status()] raise it for a reply of their
#' own with another shape, such as `{}`. A process that does not answer in
#' HTTP gives an `httr2_failure` error. Use [lms_server_ready()] for the
#' stronger test: it
#' asks the host for a model list and reports `TRUE` only for a model list
#' that [list_models()] can read.
#'
#' [lms_chat_batch()] checks the server once before its first input, and
#' [lms_chat()] checks it again for each input. If that check finds the server
#' gone during the batch, the batch aborts with `rlmstudio_no_server`, and no
#' request goes out after that. The condition then carries a `results` field, a list as
#' long as `inputs`. Its elements before the lost input hold the values that
#' `format = "list"` returns for those inputs. The element of the lost input
#' and every element after it are `NULL`. The check before the first input
#' adds no `results` field. A connection that fails after the check passes,
#' such as a server that stops during a request, raises an `httr2_failure`
#' error instead. That error aborts the batch and carries no `results` field.
#'
#' [lms_embed()] checks the server before each request, and a request carries
#' at most `batch_size` inputs. If a check after the first request finds the
#' server gone, the call aborts with `rlmstudio_no_server`. Once a request has
#' succeeded, the condition carries a `results` field. With `simplify = TRUE`,
#' `results` is a matrix with `NA` in each row whose embedding did not arrive.
#' With `simplify = FALSE`, it is a list with one element per batch, with
#' `NULL` in the element of the request that ended the call and in every
#' element after it.
#'
#' @section API failure:
#' A condition of class `rlmstudio_api_error` is raised when a REST call
#' returns a response that the wrapper treats as a failure. The condition
#' carries a `status` field, which holds the HTTP response status as an
#' integer. It also carries a `code` field. The field holds the string at
#' `error.code` of the response body, such as `"model_not_found"`. It is
#' `NULL` when the body does not parse, when `error` is not a JSON object, or
#' when its `code` is not one string.
#'
#' [lms_chat_batch()] aborts on it when its `status` is 401, 403, or 404, and
#' when its `status` is 400 and its `code` is `"model_not_found"`. No request
#' goes out after that input. The condition then carries a
#' `results` field that follows the rule for a lost server in the "Server not
#' running" section: its elements before the failed input hold the values that
#' `format = "list"` returns for those inputs, and the element of the failed
#' input and every element after it are `NULL`. For any other status, the
#' element of the failed input holds the condition, or `NA` where the result
#' is text, and the batch warns once and goes on. See the details of
#' [lms_chat_batch()].
#'
#' [lms_embed()] follows the same rule for each request. A 401, 403, or 404
#' aborts the call, and once a request has succeeded the condition carries a
#' `results` field, a matrix or a list as the "Server not running" section
#' describes. Any other status fails the inputs of that request alone, and
#' the call warns once and goes on. If every request fails, the call aborts
#' with the first condition. See the details of [lms_embed()].
#'
#' @section Malformed response:
#' A condition of class `rlmstudio_bad_response` is raised when the server
#' answers with a status the wrapper accepts and a body the wrapper cannot
#' read. It is raised where a wrapper checks the body before it reshapes it,
#' rather than indexing straight into whatever arrived. Eleven functions raise
#' it for a body they cannot read: [lms_embed()], [lms_chat()],
#' [lms_chat_native()], [lms_chat_openresponses()], [lms_chat_openai()],
#' [list_models()], [list_instances()], [lms_load()], [lms_download()],
#' [lms_download_status()], and [lms_unload_all()]. [lms_chat()] raises it
#' through the chat function it calls. [lms_unload_all()] raises it through
#' [list_models()], and so does [lms_load()] unless `force = TRUE`.
#' [lms_chat_batch()] raises it only as `rlmstudio_model_mismatch`, which the
#' "Reply from another model" section of [lms_chat_openai()] describes.
#'
#' All eleven raise it for a status-200 body that does not parse as JSON, such
#' as an HTML page from a proxy, JSON text that stops part way, or an empty
#' body. In the functions that take `simplify`, the body is parsed before
#' `simplify` is read, so the condition is raised whatever `simplify` is. The
#' body is parsed by its content and not by its `Content-Type` header, so
#' valid JSON under `text/plain` is read as JSON. The body is read as JSON
#' text and nothing else. A body whose text is a URL or the path of a file
#' does not parse, and the package does not fetch the URL or read the file.
#' The message says that the body did not parse as JSON and that something
#' other than LM Studio may be answering on the host. It does not hold the
#' body text.
#'
#' The condition carries a `status` field, which holds the HTTP response
#' status as an integer. Today the status is always 200: each of these
#' functions reads the body only after a 200, and reports every other status
#' as an `rlmstudio_api_error` instead.
#'
#' @section Malformed model list:
#' [list_models()] also raises it for a status-200 model list with the wrong
#' shape. [lms_unload_all()] and [lms_load()] without `force = TRUE` raise it
#' through [list_models()]. [lms_chat_openai()] and [lms_chat_openresponses()]
#' apply these rules to the model list of their model lookup, as the "Reply
#' from another model" section of [lms_chat_openai()] describes. A model list
#' must follow four rules. Each field is
#' read by its exact name, so a field named `keyX` does not stand in for
#' `key`.
#'
#' 1. The body is a JSON object whose `models` field is an array. The array
#'    can be empty.
#' 2. Each entry of `models` is a JSON object. Its `type` and `key` are
#'    strings, and its `loaded_instances` is an array.
#' 3. The `size_bytes` of an entry is a number, or absent, or `null`. So is
#'    its `max_context_length`.
#' 4. Each entry of `loaded_instances` is a JSON object whose `id` is a string
#'    with a character that is not whitespace.
#'
#' The rules are checked before the `type` and `loaded` filters, so an entry
#' that the filters drop can still raise the condition. The message names the
#' field or entry that broke a rule. [lms_server_ready()] applies the same
#' rules and returns `FALSE` for a body that breaks one.
#'
#' [list_instances()] applies the four rules too, and two more. They cover
#' only an entry whose `type` is in its `type` argument and that has at least
#' one loaded instance. The `display_name` of such an entry is a string, or
#' absent, or `null`. The `config` of each of its instances is a JSON object,
#' or absent, or `null`. [list_models()] and [lms_server_ready()] do not apply
#' these two rules.
#'
#' @section Malformed load or download reply:
#' [lms_load()], [lms_download()], and [lms_download_status()] also raise it
#' for a status-200 reply of their own with the wrong shape. Each reply must
#' follow the rule of its function. Each field is read by its exact name. The
#' rules check the type of a field and not its value, with four exceptions.
#' The `status` of a load reply must be `"loaded"`. A download reply whose
#' `status` is `"already_downloaded"` needs no `job_id`. A download reply whose
#' `status` is `"failed"` always aborts. The `job_id` of any other download
#' reply must hold a character that is not whitespace.
#'
#' 1. A reply of [lms_load()] is a JSON object whose `status` is the string
#'    `"loaded"`. With `echo_load_config = TRUE`, its `load_config` is also a
#'    JSON object.
#' 2. A reply of [lms_download()] is a JSON object whose `status` is a string
#'    other than `"failed"`. If the status is not `"already_downloaded"`, its
#'    `job_id` is a string with a character that is not whitespace. For a
#'    `"failed"` status, the message says that LM Studio reports that the
#'    download failed. It names the reply's `job_id` if that is a string with
#'    a character that is not whitespace.
#' 3. A reply of [lms_download_status()] is a JSON object whose `job_id` and
#'    `status` are strings. Its `total_size_bytes`, `downloaded_bytes`, and
#'    `bytes_per_second` are each a number, or absent, or `null`.
#'
#' For the other faults, the message names the field that broke the rule, or
#' it says that the body is not a JSON object. It also says that something
#' other than LM Studio may be answering on the host.
#'
#' @section Malformed embeddings:
#' [lms_embed()] raises it on an embeddings block it cannot trust. The vectors
#' it returns are placed by the index that the response reports, so a block
#' with a missing, repeated, or out-of-range index would otherwise pair a
#' vector with the wrong text and give back a matrix that is silently wrong.
#'
#' [lms_embed()] reads each request on its own. A bad body, of either kind
#' that the "Malformed response" section and this section describe, fails the
#' inputs of that request alone, and the call warns once and
#' goes on. The call aborts with the condition only if every request fails,
#' and then with the condition of the first. With `simplify = TRUE`, it also
#' aborts with `rlmstudio_bad_response` for a request whose embeddings have
#' another number of dimensions than those of an earlier request. That
#' condition carries a `results` field, a matrix as the "Server not running"
#' section describes. See the details of [lms_embed()].
#'
#' The messages of [lms_embed()] name `simplify = FALSE`, which returns the
#' body unchanged, with one exception. A body that did not parse as JSON is
#' checked before that argument is read, so its message points at the host
#' instead.
#'
#' @section Malformed chat reply:
#' [lms_chat_native()] and [lms_chat_openresponses()] raise it with
#' `simplify = TRUE` when the reply holds no readable answer text. Both read
#' the answer from the items of type `"message"` in the `output` array. They
#' raise it when `output` is missing, empty, or not an array, or when an item
#' in it is not a JSON object. They also raise it when no item has the type
#' `"message"`, as in a reply that holds only reasoning or a tool call. The
#' text of a message must be one string. For [lms_chat_native()] that is the
#' `content` of the item. For [lms_chat_openresponses()] it is the `text` of
#' each part of type `"output_text"`. For [lms_chat_openresponses()] only, the
#' `content` of each message must be an array of JSON objects, and the
#' messages together must hold at least one `"output_text"` part.
#'
#' Apart from a body that does not parse as JSON, [lms_chat_openai()] raises
#' it in four cases, all only with `simplify = TRUE`. The first case is a response whose `choices` field is
#' missing, empty, or not an array, or whose first element is not a JSON
#' object with a `message` object in it, so there is no reply to read. This
#' case is raised with or without a `schema`, and with `logprobs = TRUE` as
#' well. The second case is a reply that does not parse. A `schema` was
#' given, `logprobs = FALSE`, and the reply content is not one string of valid
#' JSON. The third case is reply content that is not one string, such as
#' `null`, a missing `content` field, a number, or an array. A reply that
#' holds only a tool call has `null` content. This case is raised without a
#' `schema`, and with `logprobs = TRUE` with or without one. The fourth case
#' is a cut-off reply. A `schema` was given, `logprobs = FALSE`, and the
#' server reports the finish reason `"length"`. This case is raised also when
#' the reply content parses, because a reply that stops part way can parse to
#' a wrong value, such as the first digit of a longer number. In the second,
#' third, and fourth cases, if the server reports the finish reason
#' `"length"`, a length limit ended the reply. The limit is `max_tokens` or
#' the context length of the model. The message then says so and names both.
#'
#' With `simplify = TRUE`, [lms_chat_native()], [lms_chat_openresponses()],
#' and [lms_chat_openai()] also raise it for a body that is a bare JSON value,
#' such as `5`, `"s"`, or `true`. The message says that the response body is
#' not a JSON object. A body of `null` gets the message about its missing
#' `output` or `choices` field instead.
#' [lms_chat()] can raise the condition through all three chat functions.
#'
#' [lms_chat_batch()] does not abort on it, except on the subclass
#' `rlmstudio_model_mismatch`, as the "Reply from another model" section of
#' [lms_chat_openai()] says. The element of the failed input holds the
#' condition, or `NA` where the result is text, and the batch warns once and
#' goes on. See the details of [lms_chat_batch()].
#'
#' A condition from [lms_chat_openai()] about its reply also carries two more
#' fields. A condition from the model-list lookup does not, as the "Reply from
#' another model" section of [lms_chat_openai()] says. The `content` field
#' holds the reply content of the first choice, and the `finish_reason` field
#' holds the finish reason of the first choice.
#' Both are `NULL` for a response with no `choices`. In the third case,
#' `content` holds the value that was read, which is `NULL` for `null` or
#' missing content. For the second, third, and fourth cases, the message names the
#' `content` field, so you can read what the model wrote without a second
#' request. The other messages of the chat functions about the reply name
#' `simplify = FALSE`, which returns the body unchanged, with one exception. A body that did not parse as JSON is
#' checked before that argument is read, so its message points at the host
#' instead. For such a body, the `content` and `finish_reason` fields of a
#' condition from [lms_chat_openai()] are `NULL`. The messages of
#' `rlmstudio_model_mismatch` and of the model-list lookup do not name
#' `simplify = FALSE`, because the check runs with either setting of
#' `simplify`.
#'
#' @section Malformed logprobs:
#' With `simplify = TRUE` and `logprobs = TRUE`, [lms_chat_openresponses()]
#' also raises it for a `logprobs` value that breaks one of these rules. The
#' `logprobs` value of each `"output_text"` part is checked. A `logprobs`
#' value, `token`, `logprob`, or `top_logprobs` that is `null` or absent
#' passes its rule. A `null` step or candidate breaks rule 2 or rule 6.
#'
#' 1. The value is an array.
#' 2. Each step in the array is a JSON object.
#' 3. The `token` of a step is a string.
#' 4. The `logprob` of a step is a number.
#' 5. The `top_logprobs` of a step is an array.
#' 6. Each candidate in `top_logprobs` is a JSON object.
#' 7. The `token` and `logprob` of each candidate follow rules 3 and 4.
#'
#' The parts are checked in order, then the steps of a part, then the
#' candidates of a step, one at a time. Within a step, rules 3, 4, and 5 come
#' before the candidates. The message names the
#' first broken rule that this order reaches. These checks run only after the
#' text of every `"output_text"` part is read, so a reply that also has a bad
#' `text` in any part gets the text message.
#' Parts of other types, such as a refusal, are not checked, and with
#' `logprobs = FALSE` no part is checked. Fields are read by their exact
#' names, so a field whose name only starts with the one asked for, such as
#' `tokenX`, reads as absent and gives `NA` in the data frame.
#'
#' @section Cut-off reply:
#' A warning of class `rlmstudio_reply_cut_off` is given when a length limit
#' ended a reply that [lms_chat_openai()] returns as text. The server reports
#' this with the finish reason `"length"`. The limit is `max_tokens` or the
#' context length of the model, and the reply does not say which one. The
#' message names both. The warning is given with `simplify = TRUE` for reply
#' content that is one string, in three settings: no `schema`,
#' `logprobs = TRUE`, and a `schema` with `logprobs = TRUE`. The call returns
#' what the same reply returns without the cut-off. A `schema` reply with
#' `logprobs = FALSE` raises `rlmstudio_bad_response` instead, as the
#' "Malformed chat reply" section says. The warning and that abort read the
#' finish reason of the first choice, which is the choice that the call
#' reads. No other element of `choices` is read. With `simplify = FALSE`, the call
#' returns the body with every choice and no warning.
#'
#' [lms_chat()] gives the warning through [lms_chat_openai()] with
#' `api_type = "openai"`. [lms_chat_batch()] gives one warning of this class
#' for the whole batch in place of one for each input. It names the count and
#' the positions of the cut-off inputs, and each of those elements keeps its
#' reply. It comes after the warning about failed inputs. A batch that aborts
#' with a `results` field gives this warning before the abort. It names the
#' cut-off inputs whose replies the `results` field of the abort holds. The
#' native and OpenResponses routes give no such warning.
#'
#' The warning shows whatever `quiet` and the `rlmstudio.quiet` option say,
#' because it is the only sign that an answer is not complete.
#'
#' @section Reply from another model:
#' [lms_chat_openai()] and [lms_chat_openresponses()] read the `model` field
#' of each status-200 reply, with either setting of `simplify`. On LM Studio
#' 0.4.25+1 with one chat model loaded, both routes answered a model name that
#' the server could not find with status 200 and a reply from the loaded
#' model. With two chat models loaded, they answered with status 400 and the
#' `code` `"model_not_found"`, as the "API failure" section describes. The
#' `model` field names the loaded instance that answered. Its id can differ
#' from the key that the call asked for.
#'
#' If the `model` field equals the name that the call sent, the reply is
#' accepted. If it differs, the call sends one request for the model list to
#' `api/v1/models` on the same host, with the token of the call, and prints no
#' message. The reply is accepted if a model whose key equals the asked name
#' in any letter case has a loaded instance whose id is the `model` field.
#' Otherwise the call aborts with a condition of class
#' `rlmstudio_model_mismatch`. That condition is also an
#' `rlmstudio_bad_response`, and its `status` is 200. Its `model` field holds
#' the asked name, and its `reply_model` field holds the `model` field of the
#' reply. The message names both. A condition from [lms_chat_openai()] also
#' carries the `content` and `finish_reason` fields, both `NULL`.
#'
#' The check runs before the reply is read, so it also runs with
#' `logprobs = TRUE`, with a `schema` on [lms_chat_openai()], and for a reply
#' with no answer text. A reply is not checked if its body is not a JSON
#' object, if it has no `model` field, or if its `model` is not one string or
#' holds only whitespace. A body that is not a JSON object is returned with
#' `simplify = FALSE`, and with `simplify = TRUE` it raises the error that the
#' "Malformed chat reply" section describes. If the instance that answered is
#' unloaded before the model-list request, the call aborts, also when that
#' instance belongs to the asked model.
#'
#' If the model-list request fails, the call raises the condition of that
#' failure. The message opens with the label of the chat function, followed
#' by "because the model-list lookup failed". A status other than 200 raises
#' `rlmstudio_api_error`. A body that does not parse as JSON, or that breaks a
#' rule of a model list in the "Malformed model list" section, raises
#' `rlmstudio_bad_response`. A server that the port check before the request
#' cannot reach raises `rlmstudio_no_server`. A condition from the lookup does
#' not carry the `content` and `finish_reason` fields, also when
#' [lms_chat_openai()] raises it.
#'
#' [lms_chat()] runs the check through [lms_chat_openai()] and
#' [lms_chat_openresponses()]. [lms_chat_native()] does not check the reply.
#' On LM Studio 0.4.25+1, `/api/v1/chat` answered a name that it could not
#' find with status 404, which raises `rlmstudio_api_error`.
#'
#' [lms_chat_batch()] aborts at the first input that raises
#' `rlmstudio_model_mismatch`, on the `"openai"` and `"openresponses"` routes.
#' It also aborts at an `rlmstudio_api_error` with status 400 whose `code` is
#' `"model_not_found"`. No request goes out after that input. In both cases,
#' the condition carries a `results` field that follows the rule for a lost
#' server in the "Server not running" section.
#'
#' @name rlmstudio-conditions
#' @aliases rlmstudio_no_server rlmstudio_api_error rlmstudio_bad_response rlmstudio_reply_cut_off rlmstudio_model_mismatch
#'
#' @examples
#' \dontrun{
#' tryCatch(
#'   list_models(host = "http://localhost:9999"),
#'   rlmstudio_no_server = function(cnd) {
#'     message("The server is not running: ", conditionMessage(cnd))
#'   },
#'   rlmstudio_api_error = function(cnd) {
#'     message("The API call failed with status ", cnd$status)
#'   },
#'   rlmstudio_bad_response = function(cnd) {
#'     message("The response body could not be read: ", conditionMessage(cnd))
#'   }
#' )
#' }
NULL
