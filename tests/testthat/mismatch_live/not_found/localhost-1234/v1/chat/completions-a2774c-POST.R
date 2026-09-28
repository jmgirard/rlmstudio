structure(list(method = "POST", url = "http://localhost:1234/v1/chat/completions", 
    status_code = 400L, headers = structure(list(`X-Powered-By` = "Express", 
        `Content-Type` = "application/json; charset=utf-8", `Content-Length` = "302", 
        ETag = "W/\"12e-3jVw65MtzW519nGYZJbcfgKo6Js\"", Date = "Mon, 28 Sep 2026 21:17:13 GMT", 
        Connection = "keep-alive", `Keep-Alive` = "timeout=5"), class = "httr2_headers"), 
    body = charToRaw("{\n    \"error\": {\n        \"message\": \"Invalid model identifier \\\"not-a-model\\\". Please specify a valid downloaded model (e.g., google/gemma-4-e4b@4bit, google/gemma-4-e4b, gemma-4-e4b-it-mlx).\",\n        \"type\": \"invalid_request_error\",\n        \"param\": \"model\",\n        \"code\": \"model_not_found\"\n    }\n}"), 
    timing = c(redirect = 0, namelookup = 0, connect = 0, pretransfer = 5.1e-05, 
    starttransfer = 0.001068, total = 0.001097), cache = new.env(parent = emptyenv())), class = "httr2_response")
