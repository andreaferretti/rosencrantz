import asynchttpserver, asyncdispatch, asyncnet, strtabs, strutils

proc readBody*(req: ref Request): Future[void] {.async.} =
  var length = 0
  if req.headers.hasKey("Content-Length"):
    length = req.headers["Content-Length"].parseInt
  req.body = await req.client.recv(length)