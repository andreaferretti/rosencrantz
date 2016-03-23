import asynchttpserver, asyncdispatch, json, math, strtabs, strutils, sequtils,
  rosencrantz

type Message = object
  message: string

proc renderToJson(m: Message): JsonNode =
  %{"message": %(m.message)}

proc parseFromJson(j: JsonNode, m: typedesc[Message]): Message =
  let s = j["message"].getStr
  return Message(message: s)

let handler = get[
  path("/hello")[
    ok("Hello, World!")
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
  ]
] ~ post[
  path("/hello-post")[
    ok("Hello, World!")
  ] ~
  path("/echo")[
    body(proc(s: string): auto =
      ok(s)
    )
  ]
] ~ put[
  path("/hello-put")[
    ok("Hello, World!")
  ]
]

let server = newAsyncHttpServer()

waitFor server.serve(Port(8080), handler)