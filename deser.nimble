# Package

version       = "0.1.2"
author        = "gabbhack"
description   = "De/serialization library for Nim "
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]

# Dependencies

requires "nim >= 1.4.2, https://github.com/gabbhack/anycase-fork >= 0.2.0"

# Tasks

task test, "Run tests":
  exec "nim check src/deser"
  exec "testament all"

task docs, "Generate docs":
  rmDir "docs"
  exec "nimble doc2 --outdir:docs --project --index:on src/deser"
  exec "testament html"
  mvFile("testresults.html", "docs/testresults.html")
