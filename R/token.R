#' Authenticating to an LM Studio server
#'
#' An LM Studio server can require an API token. Every function in this package
#' that calls the LM Studio REST API takes a `token` argument and sends the
#' value as a bearer token in the `Authorization` header. Create and manage the
#' token in the LM Studio app.
#'
#' @section Where the token comes from:
#' A function reads three sources and uses the first one that holds a value.
#'
#' 1. The `token` argument of the function you call.
#' 2. The `rlmstudio.token` option, set with [base::options()].
#' 3. The `RLMSTUDIO_API_TOKEN` environment variable.
#'
#' When none of the three holds a value, the request carries no `Authorization`
#' header. A source that is `NULL` or an empty string counts as unset.
#'
#' @section Keeping the token out of your output:
#' The header is set with [httr2::req_auth_bearer_token()], which marks it as
#' redacted. Printing a request shows `<REDACTED>` in place of the value, and
#' the abort message of a failed call never carries the value.
#'
#' @section When the server rejects the call:
#' A response with HTTP status 401 or 403 aborts with a condition of class
#' `rlmstudio_api_error`, described in [rlmstudio-conditions]. If the request
#' carried no token, the message tells you to set `RLMSTUDIO_API_TOKEN` or to
#' pass `token`. If the request carried a token, the message tells you that the
#' server rejected it.
#'
#' @name rlmstudio_token
#' @aliases RLMSTUDIO_API_TOKEN rlmstudio.token
#'
#' @seealso [rlmstudio-conditions]
#'
#' @examples
#' \dontrun{
#' # Per call.
#' list_models(token = "your-token")
#'
#' # For the session.
#' options(rlmstudio.token = "your-token")
#' list_models()
#'
#' # For the machine, set RLMSTUDIO_API_TOKEN in your .Renviron file.
#' }
NULL
