import asynchttpserver, asyncdispatch, asyncfile, strtabs, os, mimetypes
import rosencrantz/core, rosencrantz/handlers

let mime = newMimetypes()

proc getContentType(fileName: string): string {.inline.} =
  let (_, _, ext) = splitFile(fileName)
  let extension = if ext[0] == '.': ext[1 .. ext.high] else: ext
  return mime.getMimetype(extension)


proc file*(path: string): Handler =
  let mimeType = getContentType(path)

  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if fileExists(path):
      let f = openAsync(path)
      let content = await f.readAll
      close(f)
      var hs = {"Content-Type": mimeType}.newStringTable
      # Should traverse in reverse order
      for h in ctx.headers:
        hs[h.k] = h.v
      await req[].respond(Http200, content, hs)
      return ctx
    else:
      return ctx.reject

  return h

proc dir*(path: string): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    template p: auto = req.url.path

    let
      fileName = p[ctx.position .. p.high]
      completeFileName = path / fileName
    if fileExists(completeFileName):
      let
        mimeType = getContentType(completeFileName)
        f = openAsync(completeFileName)
      let content = await f.readAll
      close(f)
      var hs = {"Content-Type": mimeType}.newStringTable
      # Should traverse in reverse order
      for h in ctx.headers:
        hs[h.k] = h.v
      await req[].respond(Http200, content, hs)
      return ctx
    else:
      return ctx.reject

  return h