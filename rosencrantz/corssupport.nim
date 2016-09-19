import strutils, sequtils
import ./core, ./handlers, ./headersupport


proc accessControlAllowOrigin*(origin: string): auto =
  headers(("Access-Control-Allow-Origin", origin))

let accessControlAllowAllOrigins* = accessControlAllowOrigin("*")

proc accessControlExposeHeaders*(headers: openarray[string]): auto =
  headers(("Access-Control-Expose-Headers", headers.join(", ")))

proc accessControlMaxAge*(seconds: int): auto =
  headers(("Access-Control-Max-Age", $seconds))

proc accessControlAllowCredentials*(allow: bool): auto =
  headers(("Access-Control-Allow-Credentials", $allow))

proc accessControlAllowMethods*(methods: openarray[HttpMethod]): auto =
  headers(("Access-Control-Allow-Methods", methods.map(proc(m: auto): auto = $m).join(", ")))

proc accessControlAllowHeaders*(headers: openarray[string]): auto =
  headers(("Access-Control-Allow-Headers", headers.join(", ")))

proc accessControlAllow*(origin: string, methods: openarray[HttpMethod], headers: openarray[string]): auto =
  headers(
    ("Access-Control-Allow-Origin", origin),
    ("Access-Control-Allow-Methods", methods.map(proc(m: auto): auto = $m).join(", ")),
    ("Access-Control-Allow-Headers", headers.join(", "))
  )