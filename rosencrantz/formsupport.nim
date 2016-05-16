import strtabs, strutils, parseutils, tables, asynchttpserver, asyncdispatch, cgi
import rosencrantz/util, rosencrantz/core, rosencrantz/handlers

proc parseUrlEncoded(body: string): StringTableRef {.inline.} =
  result = {:}.newStringTable
  var i = 0
  let c = body.decodeUrl
  while i < c.len - 1:
    var k, v: string
    i += c.parseUntil(k, '=', i)
    i += 1
    i += c.parseUntil(v, '&', i)
    i += 1
    result[k] = v

proc parseUrlEncodedMulti(body: string): TableRef[string, seq[string]] {.inline.} =
  new result
  result[] = initTable[string, seq[string]]()
  template add(k, v: string) =
    if result.hasKey(k):
      result.mget(k).add(v)
    else:
      result[k] = @[v]

  var i = 0
  let c = body.decodeUrl
  while i < c.len - 1:
    var k, v: string
    i += c.parseUntil(k, '=', i)
    i += 1
    i += c.parseUntil(v, '&', i)
    i += 1
    add(k, v)

type
  UrlDecodable* = concept x
    var s: StringTableRef
    parseFromUrl(s, type(x)) is type(x)
  UrlMultiDecodable* = concept x
    var s: TableRef[string, seq[string]]
    parseFromUrl(s, type(x)) is type(x)

proc queryString*(p: proc(s: string): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    let handler = p(req.url.query)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc queryString*(p: proc(s: StringTableRef): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var s: StringTableRef
    try:
      s = req.url.query.parseUrlEncoded
    except:
      return ctx.reject()
    let handler = p(s)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc queryString*[A: UrlDecodable](p: proc(a: A): Handler): Handler =
  queryString(proc(s: StringTableRef): Handler =
    var a: A
    try:
      a = s.parseFromUrl(A)
    except:
      return reject()
    return p(a)
  )

proc queryString*(p: proc(s: TableRef[string, seq[string]]): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var s: TableRef[string, seq[string]]
    try:
      s = req.url.query.parseUrlEncodedMulti
    except:
      return ctx.reject()
    let handler = p(s)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc queryString*[A: UrlMultiDecodable](p: proc(a: A): Handler): Handler =
  queryString(proc(s: TableRef[string, seq[string]]): Handler =
    var a: A
    try:
      a = s.parseFromUrl(A)
    except:
      return reject()
    return p(a)
  )

proc formBody*(p: proc(s: StringTableRef): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var s: StringTableRef
    if req.body == "":
      await readBody(req)
    try:
      s = req.body.parseUrlEncoded
    except:
      return ctx.reject()
    let handler = p(s)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc formBody*[A: UrlDecodable](p: proc(a: A): Handler): Handler =
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
    if req.body == "":
      await readBody(req)
    try:
      s = req.body.parseUrlEncodedMulti
    except:
      return ctx.reject()
    let handler = p(s)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h

proc formBody*[A: UrlMultiDecodable](p: proc(a: A): Handler): Handler =
  formBody(proc(s: TableRef[string, seq[string]]): Handler =
    var a: A
    try:
      a = s.parseFromUrl(A)
    except:
      return reject()
    return p(a)
  )