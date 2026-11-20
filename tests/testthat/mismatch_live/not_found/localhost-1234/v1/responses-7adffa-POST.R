structure(list(method = "POST", url = "http://localhost:1234/v1/responses", 
    status_code = 400L, headers = structure(list(`X-Powered-By` = "Express", 
        `Content-Type` = "application/json; charset=utf-8", `Content-Length` = "273", 
        ETag = "W/\"111-VjgAieGOnfbx9c8sXCVgp2pFYhI\"", Date = "Fri, 20 Nov 2026 18:56:30 GMT", 
        Connection = "keep-alive", `Keep-Alive` = "timeout=5"), class = "httr2_headers"), 
    body = charToRaw("{\n  \"error\": {\n    \"message\": \"Invalid model identifier \\\"not-a-model\\\". Please specify a valid downloaded model (e.g., liquid/lfm2-350m@8bit, liquid/lfm2-350m, lfm2-350m-mlx).\",\n    \"type\": \"invalid_request_error\",\n    \"param\": \"model\",\n    \"code\": \"model_not_found\"\n  }\n}"), 
    timing = c(redirect = 0, namelookup = 0, connect = 0, pretransfer = 4.4e-05, 
    starttransfer = 0.001465, total = 0.001495), cache = new.env(parent = emptyenv())), class = "httr2_response")
