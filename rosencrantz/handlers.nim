import asynchttpserver, asyncdispatch, httpcore, strutils
import rosencrantz/core

proc reject*(): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    return ctx.reject()

  return h

proc complete*(code: HttpCode, body: string, headers = newHttpHeaders()): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var hs = headers
    # Should traverse in reverse order
    for h in ctx.headers:
      hs[h.k] = h.v
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
    if path[pos] != '/':
      return ctx.reject()
    let nextSlash = path.find('/', pos + 1)
    let final = if nextSlash == -1: path.len else: nextSlash - 1
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
    if req.reqMethod.toUpper == verbName:
      return ctx
    else:
      return ctx.reject()

  return h

let
  get* = verb(HttpMethod.GET)
  post* = verb(HttpMethod.POST)
  put* = verb(HttpMethod.PUT)
  delete* = verb(HttpMethod.DELETE)
  head* = verb(HttpMethod.HEAD)
  patch* = verb(HttpMethod.PATCH)
  options* = verb(HttpMethod.OPTIONS)
  trace* = verb(HttpMethod.TRACE)
  connect* = verb(HttpMethod.CONNECT)

proc logging*(handler: Handler): auto =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let ret = handler(req, ctx)
    debugEcho "$3 $1 $2".format(req.reqMethod, req.url.path, req.hostname)
    return await ret

  return h

proc failWith*(code: HttpCode, s: string): auto =
  proc inner(handler: Handler): Handler =
    handler ~ complete(code, s)

  return inner