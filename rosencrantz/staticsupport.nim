import asynchttpserver, asyncdispatch, asyncfile, strtabs, os, mimetypes
import rosencrantz/core, rosencrantz/handlers

let mime = newMimetypes()


proc file*(path: string): Handler =
  let
    (_, _, ext) = splitFile(path)
    mimeType = mime.getMimetype(ext)

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
        (_, _, ext) = splitFile(completeFileName)
        mimeType = mime.getMimetype(ext)
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