structure(list(method = "POST", url = "http://localhost:1234/v1/embeddings", 
    status_code = 400L, headers = structure(list(`X-Powered-By` = "Express", 
        `Content-Type` = "application/json; charset=utf-8", `Content-Length` = "102", 
        ETag = "W/\"66-yJl+yciSCcENIIRqEMohcGID4b4\"", Date = "Fri, 20 Nov 2026 18:56:39 GMT", 
        Connection = "keep-alive", `Keep-Alive` = "timeout=5"), class = "httr2_headers"), 
    body = charToRaw("{\"error\":\"No models loaded. Please load a model in the developer page or use the 'lms load' command.\"}"), 
    timing = c(redirect = 0, namelookup = 0, connect = 0, pretransfer = 3.1e-05, 
    starttransfer = 0.000755, total = 0.000784), cache = new.env(parent = emptyenv())), class = "httr2_response")
