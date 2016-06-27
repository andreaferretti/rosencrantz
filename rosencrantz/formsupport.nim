import strtabs, strutils, parseutils, tables, asynchttpserver, asyncdispatch, cgi
import ./core, ./handlers

type
  MultiPartFile* = object
    filename*, contentType*, content*: string
  MultiPart* = object
    fields*: StringTableRef
    files*: TableRef[string, MultiPartFile]

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
      result[k].add(v)
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

const sep = "\c\L"

template doSkip(s, token, start: expr): expr =
  let x = s.skip(token, start)
  doAssert x != 0
  x

template doSkipIgnoreCase(s, token, start: expr): expr =
  let x = s.skipIgnoreCase(token, start)
  doAssert x != 0
  x

proc parseChunk(chunk: var string, accum: var MultiPart) {.inline.} =
  var
    k, name, filename, contentType: string
    j = chunk.skipWhiteSpace(0)
    lineEnd = chunk.find(sep, j)
  j += chunk.doSkipIgnoreCase("Content-Disposition:", j)
  j += chunk.skipWhiteSpace(j)
  j += chunk.doSkip("form-data;", j)
  while j < lineEnd:
    j += chunk.skipWhile({' '}, j)
    j += chunk.parseUntil(k, '=', j)
    if k == "name":
      j += 1
      j += chunk.doSkip("\"", j)
      j += chunk.parseUntil(name, '"', j)
      j += 1
      j += chunk.skip(";", j)
    elif k == "filename":
      j += 1
      j += chunk.doSkip("\"", j)
      j += chunk.parseUntil(filename, '"', j)
      j += 1
      j += chunk.skip(";", j)
  doAssert name != ""
  j += chunk.doSkip(sep, j)
  # if filename found, parse next line for Content-Type
  if filename != nil:
    lineEnd = chunk.find(sep, j)
    j += chunk.doSkipIgnoreCase("Content-Type:", j)
    j += chunk.skipWhiteSpace(j)
    j += chunk.parseUntil(contentType, sep[0], j)
    j += chunk.doSkip(sep & sep, j)
    accum.files[name] = MultiPartFile(
      filename: filename,
      contentType: contentType,
      content: chunk[j .. chunk.high - sep.len]
    )
  else:
    j += chunk.doSkip(sep, j)
    accum.fields[name] = chunk[j .. chunk.high - sep.len]


proc multipart*(p: proc(s: MultiPart): Handler): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    var accum = MultiPart(
      fields: {:}.newStringTable,
      files: newTable[string, MultiPartFile]()
    )
    let
      contentType: string = req.headers["Content-Type"]
      skip = "multipart/form-data; boundary=".len
      boundary = "--" & contentType[skip .. contentType.high]
    template c: string = req.body

    var i = 0
    while i < c.len - 1:
      var chunk: string
      i += c.doSkip(boundary, i)
      i += c.parseUntil(chunk, boundary, i)

      if chunk != ("--" & sep):
        parseChunk(chunk, accum)
    let handler = p(accum)
    let newCtx = await handler(req, ctx)
    return newCtx

  return h