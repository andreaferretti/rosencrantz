import asyncHttpServer, asyncDispatch
import rosencrantz/core

# macro scope*(body: untyped): untyped =
#  if kind(body) != nnkDo: body
#  else: newBlockStmt(body[6])

template scope*(body: untyped): untyped =
  proc inner: auto {.gensym.} = body
  inner()

proc getRequest*(p: proc(req: ref Request): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req)
    return (await handler(req, ctx))

  return h

template handle*(body: untyped): untyped =
  scope do:
    proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
      body

    return h