import unittest, httpclient

const baseUrl = "http://localhost:8080"

suite "basic functionality":
  test "simple text":
    let resp = getContent(baseUrl & "/benchmark/text")
    check resp == "Hello, World!"