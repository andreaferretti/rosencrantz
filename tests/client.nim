import unittest, httpclient, strtabs, strutils

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

suite "handling headers":
  test "producing headers":
    let resp = get(baseUrl & "/emit-headers")
    check resp.body == "Hi there"
    check resp.hasStatus(200)
    check resp.hasContentType("text/html")
    check resp.headers["Date"] == "Today"