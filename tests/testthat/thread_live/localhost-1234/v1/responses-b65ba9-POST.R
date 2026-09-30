structure(list(method = "POST", url = "http://localhost:1234/v1/responses", 
    status_code = 400L, headers = structure(list(`X-Powered-By` = "Express", 
        `Content-Type` = "application/json; charset=utf-8", `Content-Length` = "287", 
        ETag = "W/\"11f-m1xb7zwew1MtfaEuti5gcuKF1oE\"", Date = "Wed, 30 Sep 2026 00:27:44 GMT", 
        Connection = "keep-alive", `Keep-Alive` = "timeout=5"), class = "httr2_headers"), 
    body = charToRaw("{\n  \"error\": {\n    \"message\": \"Prediction history node with id 'not_a_stored_reply' not found while attempting to build chat history chain that includes this node.\",\n    \"type\": \"invalid_request_error\",\n    \"param\": \"previous_response_id\",\n    \"code\": \"previous_response_not_found\"\n  }\n}"), 
    timing = c(redirect = 0, namelookup = 0, connect = 0, pretransfer = 4.5e-05, 
    starttransfer = 0.000744, total = 0.000765), cache = new.env(parent = emptyenv())), class = "httr2_response")
