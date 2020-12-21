import strformat

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

task pretty, "Pretty source code":
  echo "Pretty src\\deser"
  exec "nimpretty src/deser --indent:2"
  for i in listFiles("src/deser"):
    echo fmt"Pretty {i}"
    exec fmt"nimpretty {i} --indent:2"

task test, "Run tests":
  exec "nim check src/deser"
  exec "nimble install deser_json -y"
  exec "testament all"

task docs, "Generate docs":
  rmDir "docs"
  exec "nimble doc2 --outdir:docs --project --git.url:https://github.com/gabbhack/deser --git.commit:master --index:on src/deser"
  exec "testament html"
  mvFile("testresults.html", "docs/testresults.html")
