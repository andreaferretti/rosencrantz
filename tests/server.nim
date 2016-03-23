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
  path("/benchmark/json/simple")[
    ok(Message(message: "Hello, World!"))
  ] ~
  pathChunk("/benchmark/json/nested")[
    intSegment(proc(n: int): auto =
      segment(proc(msg: string): auto =
        var messages = newJArray()
        for i in 1 .. n:
          messages.add(%{"id": %i, "message": %msg})
        ok(%{"count": %n, "messages": messages})
      )
    )
  ] ~
  pathChunk("/benchmark/cpu/isprime")[
    intSegment(proc(n: int): auto =
      var isPrime = true
      for i in 2 .. n.float.sqrt.int:
        if (n mod i) == 0:
          isPrime = false
          break
      if isPrime: ok("True") else: ok("False")
    )
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