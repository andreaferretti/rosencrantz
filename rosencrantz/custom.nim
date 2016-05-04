import asyncHttpServer, asyncDispatch, macros
import rosencrantz/core

proc getRequest*(p: proc(req: ref Request): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req)
    return (await handler(req, ctx))

  return h

proc before*(p: proc(): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let h1 = p()
    return await h1(req, ctx)

  return h

template scope*(body: untyped): untyped =
  proc inner: auto {.gensym.} = body

  before(inner)

macro makeHandler*(body: untyped): untyped =
  template inner(body: untyped): untyped  {.dirty.} =
    proc innerProc(): auto =
      proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
        body

      return h

    innerProc()

  getAst(inner(body[6]))