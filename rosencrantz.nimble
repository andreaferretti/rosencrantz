mode = ScriptMode.Verbose

packageName   = "rosencrantz"
version       = "0.1.4"
author        = "Andrea Ferretti"
description   = "Web server DSL"
license       = "Apache2"
skipDirs      = @["tests"]

requires "nim >= 0.13.0"

--forceBuild

proc configForTests() =
  --hints: off
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "."
  --run


task server, "run server":
  configForTests()
  setCommand "c", "tests/server"

task client, "run client":
  configForTests()
  setCommand "c", "tests/client"