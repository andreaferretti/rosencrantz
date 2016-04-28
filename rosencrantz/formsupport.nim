import strtabs, tables, asynchttpserver, asyncdispatch
import rosencrantz/core, rosencrantz/util


proc formBody*(p: proc(s: StringTableRef): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var s: StringTableRef
    try:
      s = req.body.parseUrlEncoded
    except:
      return ctx.reject()
    let handler = p(s)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc formBody*(p: proc(s: TableRef[string, seq[string]]): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var s: TableRef[string, seq[string]]
    try:
      s = req.body.parseUrlEncodedMulti
    except:
      return ctx.reject()
    let handler = p(s)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h