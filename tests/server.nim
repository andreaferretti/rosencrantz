import asynchttpserver, asyncdispatch, json, math, strtabs, strutils, sequtils,
  rosencrantz

type Message = object
  message: string
  count: int

proc renderToJson(m: Message): JsonNode =
  %{"msg": %(m.message), "count": %(m.count)}

proc parseFromJson(j: JsonNode, m: typedesc[Message]): Message =
  let
    s = j["msg"].getStr
    c = j["count"].getNum.int
  return Message(message: s, count: c)

let handler = get[
  path("/hello")[
    logging(
      ok("Hello, World!")
    )
  ] ~
  path("/nested/hello")[
    ok("Hello, World!")
  ] ~
  pathChunk("/nested")[
    pathChunk("/hello-again")[
      ok("Hello, World!")
    ]
  ] ~
  pathChunk("/error")[
    pathChunk("/not-found")[
      notFound("Not found")
    ] ~
    pathChunk("/unauthorized")[
      complete(Http401, "Authorization failed",
        {"Content-Type": "text/plain"}.newStringTable)
    ]
  ] ~
  pathChunk("/echo")[
    pathEnd(proc(rest: string): auto = ok(rest))
  ] ~
  pathChunk("/repeat")[
    segment(proc(msg: string): auto =
      intSegment(proc(n: int): auto =
        ok(sequtils.repeat(msg, n).join(","))
      )
    )
  ] ~
  path("/query-echo")[
    queryString(proc(s: string): auto =
      ok(s)
    )
  ] ~
  path("/query-repeat")[
    queryString(proc(s: StringTableRef): auto =
      let
        msg = s["msg"]
        count = s["count"].parseInt
      ok(sequtils.repeat(msg, count).join(","))
    )
  ] ~
  pathChunk("/emit-headers")[
    headers(("Content-Type", "text/html"), ("Date", "Today")) [
      ok("Hi there")
    ]
  ] ~
  path("/content-negotiation")[
    accept("text/html")[
      contentType("text/html")[
        ok("<html>hi</html>")
      ]
    ] ~
    accept("text/plain")[
      contentType("text/plain")[
        ok("hi")
      ]
    ]
  ] ~
  path("/read-all-headers")[
    readAllHeaders(proc(hs: StringTableRef): auto =
      ok(hs["First"] & ", " & hs["Second"])
    )
  ] ~
  path("/read-headers")[
    readHeaders("First", "Second", proc(first, second: string): auto =
      ok(first & ", " & second)
    )
  ] ~
  path("/try-read-headers")[
    tryReadHeaders("First", "Second", "Third", proc(first, second, third: string): auto =
      ok(first & ", " & second & third)
    )
  ] ~
  path("/check-headers")[
    checkHeaders(("First", "Hello"), ("Second", "World!"))[
      ok("Hello, World!")
    ]
  ] ~
  path("/date")[
    addDate()[
      ok("Hello, World!")
    ]
  ] ~
  path("/crash")[
    readAllHeaders(proc(hs: StringTableRef): auto =
      ok(hs["Missing"])
    )
  ] ~
  path("/custom-failure")[
    failWith(Http401, "Unauthorized")(
      checkHeaders(("First", "Hello"))[
        ok("Hello, World!")
      ]
    )
  ] ~
  path("/write-json")[
    ok(%{"msg": %"hi there", "count": %5})
  ] ~
  path("/write-json-typeclass")[
    ok(Message(message: "hi there", count: 5))
  ] ~
  path("/serve-file")[
    file("LICENSE")
  ] ~
  path("/serve-missing-file")[
    file("LICENS")
  ] ~
  path("/serve-image")[
    file("shakespeare.jpg")
  ] ~
  pathChunk("/serve-dir")[
    dir(".")
  ] ~
  path("/custom-block")[
    scope do:
      let x = "Hello, World!"
      return ok(x)
  ] ~
  path("/custom-handler")[
    getRequest(proc(req: ref Request): auto =
      let x = req.url.path
      return ok(x)
    )
  ] ~
  path("/handler-macro")[
    makeHandler do:
      let x = req.url.path
      await req[].respond(Http200, x, {"Content-Type": "text/plain;charset=utf-8"}.newStringTable)
      return ctx
  ]
] ~ post[
  path("/hello-post")[
    ok("Hello, World!")
  ] ~
  path("/echo")[
    body(proc(s: string): auto =
      ok(s)
    )
  ] ~
  path("/read-json")[
    jsonBody(proc(j: JsonNode): auto =
      ok(j["msg"].getStr)
    )
  ] ~
  path("/read-json-typeclass")[
    jsonBody(proc(m: Message): auto =
      ok(m.message)
    )
  ] ~
  path("/read-form")[
    formBody(proc(s: StringTableRef): auto =
      ok(s["msg"])
    )
  ]
] ~ put[
  path("/hello-put")[
    ok("Hello, World!")
  ]
]

let server = newAsyncHttpServer()

waitFor server.serve(Port(8080), handler)