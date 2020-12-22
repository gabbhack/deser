# Package

version       = "0.1.4"
author        = "gabbhack"
description   = "De/serialization library for Nim "
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]

# Dependencies

requires "nim >= 1.4.2, https://github.com/gabbhack/anycase-fork >= 0.2.0"

# Tasks
import strformat, strutils, sequtils

proc recursiveListFiles(dir: string, l: var seq[string]) =
  for i in listDirs(dir):
    recursiveListFiles(i, l)

  for i in listFiles(dir):
    if i.endsWith(".nim"):
      l.add(i)

proc recursiveListFiles(dir: string): seq[string] =
  recursiveListFiles(dir, result)

task pretty, "Pretty source code":
  for i in concat(recursiveListFiles(srcDir), recursiveListFiles("tests")):
    echo fmt"Pretty {i}"
    exec fmt"nimpretty {i} --indent:2"

task test, "Run tests":
  exec "nimble install deser_json -y"
  exec "testament all"

task docs, "Generate docs":
  rmDir "docs"
  exec "nimble doc2 --outdir:docs --project --git.url:https://github.com/gabbhack/deser --git.commit:master --index:on src/deser"
  exec "testament html"
  mvFile("testresults.html", "docs/testresults.html")
