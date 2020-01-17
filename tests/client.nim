import unittest, httpcore, strutils, times, json
import httpclient except get, post

const
  baseUrl = "http://localhost:8080"
  ct = "Content-Type"
  cl = "Content-Length"

proc request(url: string, httpMethod: HttpMethod, headers = newHttpHeaders(), body = ""): Response =
  var client = newHttpClient()
  client.headers = headers
  return client.request(url, httpMethod = httpMethod, body = body)

proc get(url: string, headers = newHttpHeaders()): Response =
  request(url, HttpGet, headers = headers)

proc post(url: string, headers = newHttpHeaders(), body = ""): Response =
  request(url, HttpPost, headers = headers, body = body)

proc post(url: string, multipart: MultipartData): Response =
  let client = newHttpClient()
  return httpclient.post(client, url, multipart = multipart)

proc put(url: string, headers = newHttpHeaders(), body = ""): Response =
  request(url, HttpPut, headers = headers, body = body)

proc hasContentType(resp: Response, t: string): bool =
  resp.headers[ct].startsWith(t)

proc hasCorrectContentLength(resp: Response): bool =
  parseInt(resp.headers[cl]) == resp.body.len

proc hasStatus(resp: Response, code: int): bool =
  resp.status.split(" ")[0].parseInt == code

proc isOkTextPlain(resp: Response): bool =
  resp.hasStatus(200) and resp.hasCorrectContentLength and
    resp.hasContentType("text/plain")

proc isOkJson(resp: Response): bool =
  resp.hasStatus(200) and resp.hasCorrectContentLength and
    resp.hasContentType("application/json")

suite "basic functionality":
  test "simple text":
    let resp = get(baseUrl & "/hello")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "nested route":
    let resp = get(baseUrl & "/nested/hello")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "nested route handlers":
    let resp = get(baseUrl & "/nested/hello-again")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "not found response":
    let resp = get(baseUrl & "/error/not-found")
    check resp.body == "Not found"
    check resp.hasStatus(404)
    check resp.hasCorrectContentLength
    check resp.hasContentType("text/plain")
  test "unauthorized response":
    let resp = get(baseUrl & "/error/unauthorized")
    check resp.body == "Authorization failed"
    check resp.hasStatus(401)
    check resp.hasCorrectContentLength
    check resp.hasContentType("text/plain")
  test "post request":
    let resp = post(baseUrl & "/hello-post")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "post body extraction":
    let resp = post(baseUrl & "/echo", body = "Hi there")
    check resp.body == "Hi there"
    check resp.isOkTextPlain
  test "put request":
    let resp = put(baseUrl & "/hello-put")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "put body extraction":
    let resp = put(baseUrl & "/echo", body = "Hi there")
    check resp.body == "Hi there"
    check resp.isOkTextPlain
  test "path end extraction":
    let resp = get(baseUrl & "/echo/hi-there")
    check resp.body == "/hi-there"
    check resp.isOkTextPlain
  test "segments extraction":
    let resp = get(baseUrl & "/repeat/hello/3")
    check resp.body == "hello,hello,hello"
    check resp.isOkTextPlain
  test "segment exact match":
    let resp = get(baseUrl & "/segment-text")
    check resp.body == "Matched /segment-text"
    check resp.isOkTextPlain
  test "segment exact match does not match trailing":
    let resp = get(baseUrl & "/segment-text2")
    check resp.body == "Not Found"
    check resp.hasStatus(404)
  test "segment exact match case insensitive":
    let resp = get(baseUrl & "/sEgMeNt-TeXt-cAse-iNseNsiTive")
    check resp.body == "Matched /segment-text-case-insensitive"
    check resp.isOkTextPlain
  test "pathEnd default":
    let resp = get(baseUrl & "/no-trailing-slash")
    check resp.body == "Matched /no-trailing-slash"
    check resp.isOkTextPlain
  test "pathEnd default does not match trailing slash":
    let resp = get(baseUrl & "/no-trailing-slash/")
    check resp.body == "Not Found"
    check resp.hasStatus(404)
  test "pathEnd specific":
    let resp = get(baseUrl & "/path-end-rest/of/path")
    check resp.body == "Matched /path-end-rest/of/path"
    check resp.isOkTextPlain
  test "pathEnd specific does not match with trailing":
    let resp = get(baseUrl & "/path-end-rest/of/path2")
    check resp.body == "Not Found"
    check resp.hasStatus(404)

suite "handling headers":
  test "producing headers":
    let resp = get(baseUrl & "/emit-headers")
    check resp.body == "Hi there"
    check resp.hasStatus(200)
    check resp.hasContentType("text/html")
    check seq[string](resp.headers["date"]) == @["Today"]
  test "content negotiation":
    let
      headers1 = newHttpHeaders({"Accept": "text/html"})
      resp1 = get(baseUrl & "/content-negotiation", headers = headers1)
    check resp1.body == "<html>hi</html>"
    check resp1.hasStatus(200)
    check resp1.hasContentType("text/html")
    let
      headers2 = newHttpHeaders({"Accept": "text/plain"})
      resp2 = get(baseUrl & "/content-negotiation", headers = headers2)
    check resp2.body == "hi"
    check resp2.hasStatus(200)
    check resp2.hasContentType("text/plain")
  test "read all headers":
    let
      headers = newHttpHeaders({"First": "Hello", "Second": "World!"})
      resp = get(baseUrl & "/read-all-headers", headers = headers)
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "read some headers":
    let
      headers = newHttpHeaders({"First": "Hello", "Second": "World!"})
      resp = get(baseUrl & "/read-headers", headers = headers)
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "sending less headers than expected should not match":
    let
      headers = newHttpHeaders({"First": "Hello"})
      resp = get(baseUrl & "/read-headers", headers = headers)
    check resp.hasStatus(404)
  test "try read some headers":
    let
      headers = newHttpHeaders({"First": "Hello", "Second": "World!"})
      resp = get(baseUrl & "/try-read-headers", headers = headers)
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "checking headers":
    let
      headers = newHttpHeaders({"First": "Hello", "Second": "World!"})
      resp = get(baseUrl & "/check-headers", headers = headers)
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "failing to match headers":
    let
      headers = newHttpHeaders({"First": "Hi", "Second": "World!"})
      resp = get(baseUrl & "/check-headers", headers = headers)
    check resp.hasStatus(404)
  test "date header":
    let resp = get(baseUrl & "/date")
    let date = parse(resp.headers["Date"], "ddd, dd MMM yyyy HH:mm:ss 'GMT'")
    let now = getTime().utc()
    check resp.isOkTextPlain
    check now.yearday == date.yearday

suite "handling failures":
  test "missing page":
    let resp = get(baseUrl & "/missing")
    check resp.body == "Not Found"
    check resp.hasStatus(404)
  test "server error":
    let resp = get(baseUrl & "/crash")
    check resp.body == "Server Error"
    check resp.hasStatus(500)
  test "custom failure":
    let resp = get(baseUrl & "/custom-failure")
    check resp.body == "Unauthorized"
    check resp.hasStatus(401)
  test "crash containment":
    let resp = get(baseUrl & "/custom-crash")
    check resp.body == "Sorry :-("
    check resp.hasStatus(500)

suite "writing custom handlers":
  test "scope template":
    let resp = get(baseUrl & "/custom-block")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "scope async template":
    let resp = get(baseUrl & "/custom-block-async")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "request extractor":
    let resp = get(baseUrl & "/custom-handler")
    check resp.body == "/custom-handler"
    check resp.isOkTextPlain
  test "handler macros":
    let resp = get(baseUrl & "/handler-macro")
    check resp.body == "/handler-macro"
    check resp.isOkTextPlain

suite "json support":
  test "producing json":
    let resp = get(baseUrl & "/write-json")
    check resp.body.parseJson["msg"].getStr == "hi there"
    check resp.isOkJson
  test "producing pretty json":
    let resp = get(baseUrl & "/write-json-pretty")
    check resp.body.parseJson["msg"].getStr == "hi there"
    check resp.isOkJson
    check resp.body.find('\n') != -1
  test "producing non-pretty json":
    let resp = get(baseUrl & "/write-json-non-pretty")
    check resp.body.parseJson["msg"].getStr == "hi there"
    check resp.isOkJson
    check resp.body.find('\n') == -1
  test "reading json":
    let resp = post(baseUrl & "/read-json", body = $(%{"msg": %"hi there", "count": %5}))
    check resp.body == "hi there"
    check resp.isOkTextPlain
  test "producing json via typeclasses":
    let resp = get(baseUrl & "/write-json-typeclass")
    check resp.body.parseJson["msg"].getStr == "hi there"
    check resp.isOkJson
  test "reading json via typeclasses":
    let resp = post(baseUrl & "/read-json-typeclass", body = $(%{"msg": %"hi there", "count": %5}))
    check resp.body == "hi there"
    check resp.isOkTextPlain

suite "form and querystring support":
  test "reading form as x-www-form-urlencoded":
    let resp = post(baseUrl & "/read-form", body = "msg=hi there&count=5")
    check resp.body == "hi there"
    check resp.isOkTextPlain
  test "reading form as x-www-form-urlencoded with multiple params":
    let resp = post(baseUrl & "/read-multi-form", body = "msg=Hello&foo=bar&msg=World")
    check resp.body == "Hello World"
    check resp.isOkTextPlain
  test "reading form via typeclasses":
    let resp = post(baseUrl & "/read-form-typeclass", body = "msg=hi there&count=5")
    check resp.body == "hi there"
    check resp.isOkTextPlain
  test "reading form as x-www-form-urlencoded with multiple params via typeclasses":
    let resp = post(baseUrl & "/read-multi-form-typeclass", body = "msg=Hello&msg=, &msg=World")
    check resp.body == "Hello, World"
    check resp.isOkTextPlain
  test "querystring extraction":
    let resp = get(baseUrl & "/query-echo?hello")
    check resp.body == "hello"
    check resp.isOkTextPlain
  test "querystring parameters extraction":
    let resp = get(baseUrl & "/query-repeat?msg=hello&count=3")
    check resp.body == "hello,hello,hello"
    check resp.isOkTextPlain
  test "querystring parameters extraction via typeclasses":
    let resp = get(baseUrl & "/query-typeclass?msg=hello&count=3")
    check resp.body == "hello,hello,hello"
    check resp.isOkTextPlain
  test "querystring parameters with spaces extraction":
    let resp = get(baseUrl & "/query-repeat?msg=hello%20world&count=3")
    check resp.body == "hello world,hello world,hello world"
    check resp.isOkTextPlain
  test "querystring multiple parameters extraction":
    let resp = get(baseUrl & "/query-multi?msg=Hello&msg=World")
    check resp.body == "Hello World"
    check resp.isOkTextPlain
  test "querystring multiple parameters extraction via typeclasses":
    let resp = get(baseUrl & "/query-multi-typeclass?msg=Hello&msg=my&msg=World")
    check resp.body == "Hello my World"
    check resp.isOkTextPlain
  test "querystring multiple parameters extraction with comma":
    let resp = get(baseUrl & "/query-multi?msg=Hello%2C&msg=World")
    check resp.body == "Hello, World"
    check resp.isOkTextPlain
  test "multipart forms: extracting key/value pairs":
    var mp = newMultipartData()
    mp["field"] = "hi there"
    mp["file"] = ("text.txt", "text/plain", "Hello, world!")
    let resp = post(baseUrl & "/multipart-form?echo=field", multipart = mp)
    check resp.body == "hi there"
    check resp.isOkTextPlain
  test "multipart forms: file content":
    var mp = newMultipartData()
    mp["field"] = "hi there"
    mp["file"] = ("text.txt", "text/plain", "Hello, world!")
    let resp = post(baseUrl & "/multipart-form?echo=file", multipart = mp)
    check resp.body == "Hello, world!"
    check resp.isOkTextPlain
  test "multipart forms: file content type":
    var mp = newMultipartData()
    mp["field"] = "hi there"
    mp["file"] = ("text.txt", "text/plain", "Hello, world!")
    let resp = post(baseUrl & "/multipart-form?echo=content-type", multipart = mp)
    check resp.body == "text/plain"
    check resp.isOkTextPlain
  test "multipart forms: file name":
    var mp = newMultipartData()
    mp["field"] = "hi there"
    mp["file"] = ("text.txt", "text/plain", "Hello, world!")
    let resp = post(baseUrl & "/multipart-form?echo=filename", multipart = mp)
    check resp.body == "text.txt"
    check resp.isOkTextPlain

suite "static file support":
  test "serving a single file":
    let resp = get(baseUrl & "/serve-file")
    check resp.body.contains("Apache License")
    check resp.isOkTextPlain
  test "serving a directory":
    let resp = get(baseUrl & "/serve-dir/LICENSE")
    check resp.body.contains("Apache License")
    check resp.isOkTextPlain
  test "error on a missing file":
    let resp = get(baseUrl & "/serve-missing-file")
    check resp.body == "Not Found"
    check resp.hasStatus(404)
  test "error on a missing file in a directory":
    let resp = get(baseUrl & "/serve-dir/LICENS")
    check resp.body == "Not Found"
    check resp.hasStatus(404)
  test "mimetype on a single file":
    let resp = get(baseUrl & "/serve-image")
    check resp.hasStatus(200)
    check resp.hasContentType("image/jpeg")
  test "mimetype on a directory":
    let resp = get(baseUrl & "/serve-dir/shakespeare.jpg")
    check resp.hasStatus(200)
    check resp.hasContentType("image/jpeg")

suite "cors support":
  test "access control allow origin":
    let resp = get(baseUrl & "/cors/allow-origin")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Allow-Origin"]) == @["http://localhost"]
  test "access control allow all origins":
    let resp = get(baseUrl & "/cors/allow-all-origins")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Allow-Origin"]) == @["*"]
  test "access control expose headers":
    let resp = get(baseUrl & "/cors/expose-headers")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Expose-Headers"]) == @["X-PING, X-CUSTOM"]
  test "access control max age":
    let resp = get(baseUrl & "/cors/max-age")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Max-Age"]) == @["86400"]
  test "access control allow credentials":
    let resp = get(baseUrl & "/cors/allow-credentials")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Allow-Credentials"]) == @["true"]
  test "access control allow methods":
    let resp = get(baseUrl & "/cors/allow-methods")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Allow-Methods"]) == @["GET, POST"]
  test "access control allow headers":
    let resp = get(baseUrl & "/cors/allow-headers")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Allow-Headers"]) == @["X-PING, Content-Type"]
  test "access control combined":
    let resp = get(baseUrl & "/cors/access-control")
    check resp.isOkTextPlain
    check seq[string](resp.headers["Access-Control-Allow-Origin"]) == @["*"]
    check seq[string](resp.headers["Access-Control-Allow-Methods"]) == @["GET, POST"]
    check seq[string](resp.headers["Access-Control-Allow-Headers"]) == @["X-PING, Content-Type"]
  test "access control read headers":
    let
      headers = newHttpHeaders({
        "Origin": "http://localhost",
        "Access-Control-Allow-Method": "GET",
        "Access-Control-Allow-Headers": "X-PING"
      })
      resp = get(baseUrl & "/cors/read-headers", headers = headers)
    check resp.isOkTextPlain
    check resp.body == "http://localhost;GET;X-PING"
  test "access control read some headers":
    let
      headers = newHttpHeaders({
        "Origin": "http://localhost",
        "Access-Control-Allow-Method": "GET"
      })
      resp = get(baseUrl & "/cors/read-headers", headers = headers)
    check resp.isOkTextPlain
    check resp.body == "http://localhost;GET;"
  test "access control read headers wrong method":
    let
      headers = newHttpHeaders({
        "Origin": "http://localhost",
        "Access-Control-Allow-Method": "BET"
      })
      resp = get(baseUrl & "/cors/read-headers", headers = headers)
    check resp.hasStatus(404)