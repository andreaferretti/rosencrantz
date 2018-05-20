import asynchttpserver, asyncdispatch, asyncnet, asyncfile, httpcore, os,
  mimetypes, strutils, tables
import ./core, ./handlers

proc sendChunk(req: ref Request, s: string): Future[void] {.async.} =
  var chunk = s.len.toHex
  chunk.add("\c\L")
  chunk.add(s)
  chunk.add("\c\L")
  await req[].client.send(chunk)

proc getContentType(fileName: string, mime: MimeDB): string {.inline.} =
  let (_, _, ext) = splitFile(fileName)
  if ext == "": return "text/plain"
  let extension = if ext[0] == '.': ext[1 .. ext.high] else: ext
  return mime.getMimetype(extension.toLowerAscii)


proc file*(path: string): Handler =
  let
    mime = newMimetypes()
    mimeType = getContentType(path, mime)

  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if fileExists(path):
      let f = openAsync(path)
      let content = await f.readAll
      close(f)
      var hs = {"Content-Type": mimeType}.newHttpHeaders
      # Should traverse in reverse order
      for h in ctx.headers:
        hs[h.k] = h.v
      await req[].respond(Http200, content, hs)
      return ctx
    else:
      return ctx.reject

  return h

proc fileAsync*(path: string, chunkSize = 4096): Handler =
  let
    mime = newMimetypes()
    mimeType = getContentType(path, mime)

  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if fileExists(path):
      let f = openAsync(path)
      var hs = {"Content-Type": mimeType}.newHttpHeaders
      # Should traverse in reverse order
      for h in ctx.headers:
        hs[h.k] = h.v
      let code = Http200
      if not ctx.log.isNil:
        debugEcho ctx.log[].format(req.reqMethod, req.url.path, req.headers.table, req.body, code, hs.table)
      var start = "HTTP/1.1 " & $code & "\c\L"
      await req[].client.send(start)
      await req[].sendHeaders(hs)
      await req[].client.send("Transfer-Encoding: Chunked\c\L\c\L")
      var done = false
      while not done:
        let chunk = await f.read(chunkSize)
        if chunk == "":
          done = true
        await req.sendChunk(chunk)
      close(f)
      return ctx
    else:
      return ctx.reject

  return h

proc dir*(path: string): Handler =
  let mime = newMimetypes()

  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    template p: auto = req.url.path

    let
      fileName = p[ctx.position .. p.high]
      completeFileName = path / fileName
    if fileExists(completeFileName):
      let
        mimeType = getContentType(completeFileName, mime)
        f = openAsync(completeFileName)
      let content = await f.readAll
      close(f)
      var hs = {"Content-Type": mimeType}.newHttpHeaders
      # Should traverse in reverse order
      for h in ctx.headers:
        hs[h.k] = h.v
      await req[].respond(Http200, content, hs)
      return ctx
    else:
      return ctx.reject

  return h