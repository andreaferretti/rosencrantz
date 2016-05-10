import strtabs, asynchttpserver, asyncdispatch, times
import rosencrantz/core, rosencrantz/handlers

proc headers*(hs: varargs[StrPair]): Handler =
  let headerSeq = @hs

  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    return ctx.withHeaders(headerSeq)

  return h

proc contentType*(s: string): Handler = headers(("Content-Type", s))

proc readAllHeaders*(p: proc(headers: StringTableRef): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req.headers)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc readHeaders*(s1: string, p: proc(h1: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if req.headers.hasKey(s1):
      let handler = p(req.headers[s1])
      let newCtx = await handler(req, ctx)
      return newCtx
    else:
      return ctx.reject()

  return h

proc readHeaders*(s1, s2: string, p: proc(h1, h2: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if req.headers.hasKey(s1) and req.headers.hasKey(s2):
      let handler = p(req.headers[s1], req.headers[s2])
      let newCtx = await handler(req, ctx)
      return newCtx
    else:
      return ctx.reject()

  return h

proc readHeaders*(s1, s2, s3: string, p: proc(h1, h2, h3: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if req.headers.hasKey(s1) and req.headers.hasKey(s2) and req.headers.hasKey(s3):
      let handler = p(req.headers[s1], req.headers[s2], req.headers[s3])
      let newCtx = await handler(req, ctx)
      return newCtx
    else:
      return ctx.reject()

  return h

proc tryReadHeaders*(s1: string, p: proc(h1: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req.headers.getOrDefault(s1))
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc tryReadHeaders*(s1, s2: string, p: proc(h1, h2: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req.headers.getOrDefault(s1), req.headers.getOrDefault(s2))
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc tryReadHeaders*(s1, s2, s3: string, p: proc(h1, h2, h3: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req.headers.getOrDefault(s1), req.headers.getOrDefault(s2) ,req.headers.getOrDefault(s3))
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc checkHeaders*(hs: varargs[StrPair]): Handler =
  let headers = @hs

  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    for pair in headers:
      let (k, v) = pair
      if req.headers.getOrDefault(k) != v:
        return ctx.reject()
    return ctx

  return h

proc accept*(s: string): Handler = checkHeaders(("Accept", s))

proc addDate*(): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    # https://www.w3.org/Protocols/rfc2616/rfc2616-sec3.html
    let now = getTime().getGMTime().format("ddd, dd MMM yyyy HH:mm:ss 'GMT'")
    return ctx.withHeaders([("Date", now)])

  return h