import unittest, httpclient, strtabs, strutils

const
  baseUrl = "http://localhost:8080"
  ct = "Content-Type"
  cl = "Content-Length"

proc hasContentType(resp: Response, t: string): bool =
  resp.headers[ct].startsWith(t)

proc hasCorrectContentLength(resp: Response): bool =
  parseInt(resp.headers[cl]) == resp.body.len

proc isStatus(resp: Response, code: int): bool =
  resp.status.split(" ")[0].parseInt == code

proc isOkTextPlain(resp: Response): bool =
  resp.isStatus(200) and resp.hasCorrectContentLength and
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
    check resp.isStatus(404)
    check resp.hasCorrectContentLength
    check resp.hasContentType("text/plain")
  test "unauthorized response":
    let resp = get(baseUrl & "/error/unauthorized")
    check resp.body == "Authorization failed"
    check resp.isStatus(401)
    check resp.hasCorrectContentLength
    check resp.hasContentType("text/plain")