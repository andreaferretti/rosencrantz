mode = ScriptMode.Verbose

packageName   = "rosencrantz"
version       = "0.4.3"
author        = "Andrea Ferretti"
description   = "Web server DSL"
license       = "Apache2"
skipDirs      = @["tests", "htmldocs"]
skipFiles     = @["test.sh"]

requires "nim >= 0.19.0"

--forceBuild

proc configForTests() =
  --hints: off
  --linedir: on
  --stacktrace: on
  --linetrace: on
  --debuginfo
  --path: "."


task server, "compile server":
  configForTests()
  switch("out", "tests/rosencrantz")
  setCommand "c", "tests/server.nim"

task client, "run client":
  configForTests()
  --run
  setCommand "c", "tests/client.nim"

task gendoc, "generate documentation":
  --docSeeSrcUrl: https://github.com/andreaferretti/rosencrantz/blob/master
  --project
  setCommand "doc", "rosencrantz"

task todo, "run todo example":
  --path: "."
  --run
  setCommand "c", "tests/todo.nim"

task tests, "run tests":
  exec "./test.sh"

task test, "run tests":
  setCommand "tests"