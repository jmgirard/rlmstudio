# Authenticating to an LM Studio server

An LM Studio server can require an API token. Every function in this
package that calls the LM Studio REST API takes a `token` argument and
sends the value as a bearer token in the `Authorization` header. Create
and manage the token in the LM Studio app.

## Where the token comes from

A function reads three sources and uses the first one that holds a
value.

1.  The `token` argument of the function you call.

2.  The `rlmstudio.token` option, set with
    [`base::options()`](https://rdrr.io/r/base/options.html).

3.  The `RLMSTUDIO_API_TOKEN` environment variable.

When none of the three holds a value, the request carries no
`Authorization` header. A source that is `NULL` or an empty string
counts as unset. A `token` argument of any other shape, such as a vector
of two strings or a number, aborts rather than falling through to the
next source.

## Keeping the token out of your output

The header is set with
[`httr2::req_auth_bearer_token()`](https://httr2.r-lib.org/reference/req_auth_bearer_token.html),
which marks it as redacted. Printing a request shows `<REDACTED>` in
place of the value, and this package never puts the value into the
message of a failed call.

Two things this package does not control can still show the value. The
message of a failed call repeats the text the server sent, so a server
that echoes the token back puts it there. An R error also prints a
backtrace, which repeats your own calling line, so a token you write as
a literal appears in it. Read the token from an environment variable to
keep it out of both.

## When the server rejects the call

A response with HTTP status 401 or 403 aborts with a condition of class
`rlmstudio_api_error`, described in
[rlmstudio-conditions](https://jmgirard.github.io/rlmstudio/reference/rlmstudio-conditions.md).
If the request carried no token, the message tells you to set
`RLMSTUDIO_API_TOKEN` or to pass `token`. If the request carried a
token, the message tells you that the server rejected it.

## See also

[rlmstudio-conditions](https://jmgirard.github.io/rlmstudio/reference/rlmstudio-conditions.md)

## Examples

``` r
if (FALSE) { # \dontrun{
# Per call.
list_models(token = "your-token")

# For the session.
options(rlmstudio.token = "your-token")
list_models()

# For the machine, set RLMSTUDIO_API_TOKEN in your .Renviron file.
} # }
```
