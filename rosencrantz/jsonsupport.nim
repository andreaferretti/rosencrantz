import json, asynchttpserver, asyncdispatch, httpcore
import ./core, ./handlers

type
  JsonReadable* = concept x
    var j: JsonNode
    parseFromJson(j, type(x)) is type(x)
  JsonWritable* = concept x
    renderToJson(x) is JsonNode

proc ok*(j: JsonNode, pretty=false): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var headers = {"Content-Type": "application/json"}.newHttpHeaders
    # Should traverse in reverse order
    for h in ctx.headers:
      headers[h.k] = h.v
    let body = if pretty: pretty(j) else: $j
    await req[].respond(Http200, body, headers)
    return ctx

  return h

proc ok*[A: JsonWritable](a: A, pretty=false): Handler =
  ok(a.renderToJson, pretty)

proc jsonBody*(p: proc(j: JsonNode): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var j: JsonNode
    try:
      j = req.body.parseJson
    except JsonParsingError:
      return ctx.reject()
    let handler = p(j)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc jsonBody*[A: JsonReadable](p: proc(a: A): Handler): Handler =
  jsonBody(proc(j: JsonNode): Handler =
    var a: A
    try:
      a = j.parseFromJson(A)
    except:
      return reject()
    return p(a)
  )