import asynchttpserver, asyncdispatch, asyncfile, strtabs, os
import rosencrantz/core, rosencrantz/handlers


proc file*(path: string): Handler =
  proc h(req: ref Request, ctx: Context): Future[Context] {.async.} =
    if fileExists(path):
      let f = openAsync(path)
      let content = await f.readAll
      close(f)
      var hs = {"Content-Type": "text/plain"}.newStringTable
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
      let f = openAsync(completeFileName)
      let content = await f.readAll
      close(f)
      var hs = {"Content-Type": "text/plain"}.newStringTable
      # Should traverse in reverse order
      for h in ctx.headers:
        hs[h.k] = h.v
      await req[].respond(Http200, content, hs)
      return ctx
    else:
      return ctx.reject

  return h