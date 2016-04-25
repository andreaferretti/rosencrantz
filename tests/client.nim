import unittest, httpclient, strtabs, strutils, times, json

const
  baseUrl = "http://localhost:8080"
  ct = "Content-Type"
  cl = "Content-Length"

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
    let resp = request(baseUrl & "/hello-put", httpMethod = httpPUT)
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "path end extraction":
    let resp = get(baseUrl & "/echo/hi-there")
    check resp.body == "/hi-there"
    check resp.isOkTextPlain
  test "segments extraction":
    let resp = get(baseUrl & "/repeat/hello/3")
    check resp.body == "hello,hello,hello"
    check resp.isOkTextPlain
  test "querystring extraction":
    let resp = get(baseUrl & "/query-echo?hello")
    check resp.body == "hello"
    check resp.isOkTextPlain
  test "querystring parameters extraction":
    let resp = get(baseUrl & "/query-repeat?msg=hello&count=3")
    check resp.body == "hello,hello,hello"
    check resp.isOkTextPlain

suite "handling headers":
  test "producing headers":
    let resp = get(baseUrl & "/emit-headers")
    check resp.body == "Hi there"
    check resp.hasStatus(200)
    check resp.hasContentType("text/html")
    check resp.headers["Date"] == "Today"
  test "content negotiation":
    let resp1 = get(baseUrl & "/content-negotiation", "Accept: text/html\n")
    check resp1.body == "<html>hi</html>"
    check resp1.hasStatus(200)
    check resp1.hasContentType("text/html")
    let resp2 = get(baseUrl & "/content-negotiation", "Accept: text/plain\n")
    check resp2.body == "hi"
    check resp2.hasStatus(200)
    check resp2.hasContentType("text/plain")
  test "read all headers":
    let resp = get(baseUrl & "/read-all-headers", "First: Hello\nSecond: World!\n")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "read some headers":
    let resp = get(baseUrl & "/read-headers", "First: Hello\nSecond: World!\n")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "sending less headers than expected should not match":
    let resp = get(baseUrl & "/read-headers", "First: Hello\n")
    check resp.hasStatus(404)
  test "try read some headers":
    let resp = get(baseUrl & "/try-read-headers", "First: Hello\nSecond: World!\n")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "checking headers":
    let resp = get(baseUrl & "/check-headers", "First: Hello\nSecond: World!\n")
    check resp.body == "Hello, World!"
    check resp.isOkTextPlain
  test "failing to match headers":
    let resp = get(baseUrl & "/check-headers", "First: Hi\nSecond: World!\n")
    check resp.hasStatus(404)
  test "date header":
    let resp = get(baseUrl & "/date")
    let date = parse(resp.headers["Date"], "ddd, dd MMM yyyy HH:mm:ss 'GMT'")
    let now = getTime().getGMTime()
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

suite "writing custom handlers":
  test "scope template":
    let resp = get(baseUrl & "/custom-block")
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

suite "form support":
  test "reading form as x-www-form-urlencoded":
    let resp = post(baseUrl & "/read-form", body = "msg=hi there&count=5")
    check resp.body == "hi there"
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