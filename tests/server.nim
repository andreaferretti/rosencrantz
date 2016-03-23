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
  ]
] ~ post[
  path("/benchmark/post/form")[
    formBody(proc(s: auto): auto =
      let
        msg = s["message"]
        n = s["n"].parseInt
        resp = sequtils.repeat(msg, n).join(",")
      ok(resp)
    )
  ]
]

let server = newAsyncHttpServer()

waitFor server.serve(Port(8080), handler)