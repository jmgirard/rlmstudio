#' Error conditions raised by rlmstudio
#'
#' The functions in this package that talk to the LM Studio REST API raise two
#' condition classes of their own. Both are raised through [cli::cli_abort()],
#' so each one is an R error that you can catch by class with
#' [base::tryCatch()].
#'
#' @section Server not running:
#' Functions that call the LM Studio REST API first open a TCP connection to
#' the hostname and port named in `host`. A condition of class
#' `rlmstudio_no_server` is raised when that connection is refused. Start the
#' server with [lms_server_start()], or give `host` the address that your
#' server listens on.
#'
#' The check reads the port and nothing else. Any process holding that port
#' accepts the connection, so the condition is not raised even though no LM
#' Studio server is there. The call then fails later, as an
#' `rlmstudio_api_error` or as a raw parse error, rather than as
#' `rlmstudio_no_server`. Use [lms_server_ready()] for the stronger test: it
#' asks the host for a model list and reports `TRUE` only for an answer that
#' an LM Studio server would give.
#'
#' @section API failure:
#' A condition of class `rlmstudio_api_error` is raised when a REST call
#' returns a response that the wrapper treats as a failure. The condition
#' carries a `status` field, which holds the HTTP response status as an
#' integer.
#'
#' @name rlmstudio-conditions
#' @aliases rlmstudio_no_server rlmstudio_api_error
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
#'   }
#' )
#' }
NULL
