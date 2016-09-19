import strutils, sequtils
import ./core, ./handlers, ./headersupport


proc allowOrigin*(origin: string): auto =
  headers(("Access-Control-Allow-Origin", origin))

let allowAllOrigins* = allowOrigin("*")

proc exposeHeaders*(headers: openarray[string]): auto =
  headers(("Access-Control-Expose-Headers", headers.join(", ")))

proc maxAge*(seconds: int): auto =
  headers(("Access-Control-Max-Age", $seconds))

proc allowCredentials*(allow: bool): auto =
  headers(("Access-Control-Allow-Credentials", $allow))

proc allowMethods*(methods: openarray[HttpMethod]): auto =
  headers(("Access-Control-Allow-Methods", methods.map(proc(m: auto): auto = $m).join(", ")))

proc allowHeaders*(headers: openarray[string]): auto =
  headers(("Access-Control-Allow-Headers", headers.join(", ")))

proc allow*(origin: string, methods: openarray[HttpMethod], headers: openarray[string]): auto =
  headers(
    ("Access-Control-Allow-Origin", origin),
    ("Access-Control-Allow-Methods", methods.map(proc(m: auto): auto = $m).join(", ")),
    ("Access-Control-Allow-Headers", headers.join(", "))
  )