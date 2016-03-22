import unittest, httpclient, strtabs, strutils

const baseUrl = "http://localhost:8080"

suite "basic functionality":
  test "simple text":
    let resp = getContent(baseUrl & "/benchmark/text")
    check resp == "Hello, World!"
  test "simple text content type":
    let resp = get(baseUrl & "/benchmark/text")
    check resp.headers["Content-Type"].startsWith("text/plain")