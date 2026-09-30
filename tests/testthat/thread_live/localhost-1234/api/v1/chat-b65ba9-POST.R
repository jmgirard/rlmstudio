structure(list(method = "POST", url = "http://localhost:1234/api/v1/chat", 
    status_code = 400L, headers = structure(list(`X-Powered-By` = "Express", 
        `Content-Type` = "application/json; charset=utf-8", `Content-Length` = "354", 
        ETag = "W/\"162-xGVG/sP7kyMLonkOR5ucd2nKgeo\"", Date = "Wed, 30 Sep 2026 14:07:51 GMT", 
        Connection = "keep-alive", `Keep-Alive` = "timeout=5"), class = "httr2_headers"), 
    body = charToRaw("{\n  \"error\": {\n    \"message\": \"Could not find stored response for previous_response_id 'resp_not_a_stored_reply'. Please ensure the ID is correct. Current previous response auto-deletion policy: Responses older than 30 days are automatically deleted.\",\n    \"type\": \"invalid_request\",\n    \"param\": \"previous_response_id\",\n    \"code\": \"invalid_value\"\n  }\n}"), 
    timing = c(redirect = 0, namelookup = 0, connect = 0, pretransfer = 4.8e-05, 
    starttransfer = 0.000988, total = 0.00102), cache = new.env(parent = emptyenv())), class = "httr2_response")
