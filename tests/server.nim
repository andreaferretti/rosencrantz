import asynchttpserver, asyncdispatch, httpcore, json, math, strtabs, strutils,
  sequtils, tables, rosencrantz

type
  Message = object
    message: string
    count: int
  Messages = object
    message1: string
    message2: string
    message3: string

proc renderToJson(m: Message): JsonNode =
  %{"msg": %(m.message), "count": %(m.count)}

proc parseFromUrl(s: StringTableRef, m: typedesc[Message]): Message =
  Message(message: s["msg"], count: s["count"].parseInt)

proc parseFromUrl(s: TableRef[string, seq[string]], m: typedesc[Messages]): Messages =
  Messages(message1: s["msg"][0], message2: s["msg"][1], message3: s["msg"][2])

proc parseFromJson(j: JsonNode, m: typedesc[Message]): Message =
  let
    s = j["msg"].getStr
    c = j["count"].getNum.int
  return Message(message: s, count: c)

let handler = get[
  path("/hello")[
    logRequest("$1 $2\n$3")[
      ok("Hello, World!")
    ]
  ] ~
  path("/nested/hello")[
    logResponse("$1 $2 $5\n$6\n$7")[
      ok("Hello, World!")
    ]
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
        {"Content-Type": "text/plain"}.newHttpHeaders)
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
  path("/query-typeclass")[
    queryString(proc(m: Message): auto =
      ok(sequtils.repeat(m.message, m.count).join(","))
    )
  ] ~
  path("/query-multi")[
    queryString(proc(s: TableRef[string, seq[string]]): auto =
      ok(s["msg"].join(" "))
    )
  ] ~
  path("/query-multi-typeclass")[
    queryString(proc(m: Messages): auto =
      ok(m.message1 & " " & m.message2 & " " & m.message3)
    )
  ] ~
  pathChunk("/emit-headers")[
    headers(("Content-Type", "text/html"), ("Date", "Today"))[
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
    readAllHeaders(proc(hs: HttpHeaders): auto =
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
    readAllHeaders(proc(hs: HttpHeaders): auto =
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
  path("/custom-block-async")[
    scopeAsync do:
      let x = "Hello, World!"
      await sleepAsync(50)
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
      await req[].respond(Http200, x, {"Content-Type": "text/plain;charset=utf-8"}.newHttpHeaders)
      return ctx
  ] ~
  path("/cors/allow-origin")[
    accessControlAllowOrigin("http://localhost")[
      ok("Hi")
    ]
  ] ~
  path("/cors/allow-all-origins")[
    accessControlAllowAllOrigins[
      ok("Hi")
    ]
  ] ~
  path("/cors/expose-headers")[
    accessControlExposeHeaders(["X-PING", "X-CUSTOM"])[
      ok("Hi")
    ]
  ] ~
  path("/cors/max-age")[
    accessControlMaxAge(86400)[
      ok("Hi")
    ]
  ] ~
  path("/cors/allow-credentials")[
    accessControlAllowCredentials(true)[
      ok("Hi")
    ]
  ] ~
  path("/cors/allow-methods")[
    accessControlAllowMethods([rosencrantz.HttpMethod.GET, rosencrantz.HttpMethod.POST])[
      ok("Hi")
    ]
  ] ~
  path("/cors/allow-headers")[
    accessControlAllowHeaders(["X-PING", "Content-Type"])[
      ok("Hi")
    ]
  ] ~
  path("/cors/access-control")[
    accessControlAllow(
      origin = "*",
      methods = [rosencrantz.HttpMethod.GET, rosencrantz.HttpMethod.POST],
      headers = ["X-PING", "Content-Type"]
    )[
      ok("Hi")
    ]
  ] ~
  path("/cors/read-headers")[
    readAccessControl(proc(origin: string, m: rosencrantz.HttpMethod, headers: seq[string]): auto =
      ok(@[origin, $m, headers.join(",")].join(";"))
    )
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
  ] ~
  path("/read-form-typeclass")[
    formBody(proc(m: Message): auto =
      ok(m.message)
    )
  ] ~
  path("/read-multi-form")[
    formBody(proc(s: TableRef[string, seq[string]]): auto =
      ok(s["msg"][0] & " " & s["msg"][1])
    )
  ] ~
  path("/read-multi-form-typeclass")[
    formBody(proc(m: Messages): auto =
      ok(m.message1 & m.message2 & m.message3)
    )
  ] ~
  path("/multipart-form")[
    multipart(proc(s: MultiPart): auto =
      queryString(proc(params: StringTableRef): auto =
        if params["echo"] == "field":
          ok(s.fields["field"])
        elif params["echo"] == "file":
          ok(s.files["file"].content)
        elif params["echo"] == "filename":
          ok(s.files["file"].filename)
        elif params["echo"] == "content-type":
          ok(s.files["file"].contentType)
        else:
          reject()
      )
    )
  ]
] ~ put[
  path("/hello-put")[
    ok("Hello, World!")
  ] ~
  path("/echo")[
    body(proc(s: string): auto =
      ok(s)
    )
  ]
]

let server = newAsyncHttpServer()

waitFor server.serve(Port(8080), handler)