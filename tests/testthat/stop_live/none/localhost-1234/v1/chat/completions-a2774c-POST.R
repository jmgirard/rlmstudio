structure(list(method = "POST", url = "http://localhost:1234/v1/chat/completions", 
    status_code = 400L, headers = structure(list(`X-Powered-By` = "Express", 
        `Content-Type` = "application/json; charset=utf-8", `Content-Length` = "225", 
        ETag = "W/\"e1-NnYf7+RE36GYMwc2dcGicaF+ns4\"", Date = "Mon, 19 Oct 2026 15:55:45 GMT", 
        Connection = "keep-alive", `Keep-Alive` = "timeout=5"), class = "httr2_headers"), 
    body = charToRaw("{\n    \"error\": {\n        \"message\": \"No models loaded. Please load a model in the developer page or use the 'lms load' command.\",\n        \"type\": \"invalid_request_error\",\n        \"param\": \"model\",\n        \"code\": null\n    }\n}"), 
    timing = c(redirect = 0, namelookup = 0, connect = 0, pretransfer = 5.5e-05, 
    starttransfer = 0.001741, total = 0.001772), cache = new.env(parent = emptyenv())), class = "httr2_response")
