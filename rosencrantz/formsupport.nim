import strtabs, tables, asynchttpserver, asyncdispatch
import rosencrantz/core, rosencrantz/handlers, rosencrantz/util

type
  UrlEncodable* = concept x
    var s: StringTableRef
    parseFromUrl(s, type(x)) is type(x)
  UrlMultiEncodable* = concept x
    var s: TableRef[string, seq[string]]
    parseFromUrl(s, type(x)) is type(x)

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

proc formBody*[A: UrlEncodable](p: proc(a: A): Handler): Handler =
  formBody(proc(s: StringTableRef): Handler =
    var a: A
    try:
      a = s.parseFromUrl(A)
    except:
      return reject()
    return p(a)
  )

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

proc formBody*[A: UrlMultiEncodable](p: proc(a: A): Handler): Handler =
  formBody(proc(s: TableRef[string, seq[string]]): Handler =
    var a: A
    try:
      a = s.parseFromUrl(A)
    except:
      return reject()
    return p(a)
  )