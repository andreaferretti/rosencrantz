import asynchttpserver, asyncdispatch, httpcore, strutils, tables
import ./core

proc reject*(): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    return ctx.reject()

  return h

proc accept*(): Handler =
  ## Helper proc for when you need to return a Handler, but already
  ## know that you are not reject()-ing the request
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    return ctx

  return h

proc acceptOrReject*(b: bool) : Handler =
  ## Helper proc for creating a Handler that will accept or reject
  ## based on a single boolean
  if b:
    return accept()
  else:
    return reject()

proc complete*(code: HttpCode, body: string, headers = newHttpHeaders()): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var hs = headers
    # Should traverse in reverse order
    for h in ctx.headers:
      hs[h.k] = h.v
    if not ctx.log.isNil:
      debugEcho ctx.log[].format(req.reqMethod, req.url.path, req.headers.table, req.body, code, headers.table, body)
    await req[].respond(code, body, hs)
    return ctx

  return h

proc ok*(s: string): Handler =
  complete(Http200, s, {"Content-Type": "text/plain;charset=utf-8"}.newHttpHeaders)

proc notFound*(s: string = "Not Found"): Handler =
  complete(Http404, s, {"Content-Type": "text/plain;charset=utf-8"}.newHttpHeaders)

proc path*(s: string): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if req.url.path == s:
      return ctx
    else:
      return ctx.reject()

  return h

proc pathChunk*(s: string): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let n = s.len
    if req.url.path.substr(ctx.position, ctx.position + n - 1) == s:
      return ctx.addPosition(n)
    else:
      return ctx.reject()

  return h

proc pathEnd*(p: proc(s: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    template path: auto = req.url.path

    let s = path[ctx.position .. path.high]
    let handler = p(s)
    let newCtx = await handler(req, ctx.withPosition(path.high))
    return newCtx

  return h

proc segment*(p: proc(s: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    template path: auto = req.url.path

    let pos = ctx.position
    if pos >= path.len or path[pos] != '/':
      return ctx.reject()
    let nextSlash = path.find('/', pos + 1)
    let final = if nextSlash == -1: path.len - 1 else: nextSlash - 1
    let s = path[(pos + 1) .. final]
    let handler = p(s)
    let newCtx = await handler(req, ctx.addPosition(final - pos + 1))
    return newCtx

  return h

proc intSegment*(p: proc(n: int): Handler): Handler =
  proc inner(s: string): Handler =
    var n: int
    try:
      n = s.parseInt
    except OverflowError, ValueError:
      return reject()

    return p(n)

  return segment(inner)

proc body*(p: proc(s: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req.body)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc verb*(m: HttpMethod): Handler =
  let verbName = $m

  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    # TODO: remove the call to `$` when switching to httpcore.HttpMethod
    if $(req.reqMethod) == verbName:
      return ctx
    else:
      return ctx.reject()

  return h

let
  get* = verb(HttpGet)
  post* = verb(HttpPost)
  put* = verb(HttpPut)
  delete* = verb(HttpDelete)
  head* = verb(HttpHead)
  patch* = verb(HttpPatch)
  options* = verb(HttpOptions)
  trace* = verb(HttpTrace)
  connect* = verb(HttpConnect)

proc logResponse*(s: string): Handler =
  let x = new(string)
  x[] = s
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    return ctx.withLogging(x)

  return h

proc logRequest*(s: string): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    debugEcho s.format(req.reqMethod, req.url.path, req.headers.table, req.body)
    return ctx

  return h

proc failWith*(code: HttpCode, s: string): auto =
  proc inner(handler: Handler): Handler =
    handler ~ complete(code, s)

  return inner
