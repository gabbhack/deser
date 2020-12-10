# Package

version       = "0.1.0"
author        = "gabbhack"
description   = "De/serialization library for Nim "
license       = "MIT"
srcDir        = "src"
skipDirs      = @["tests", "htmldocs"]


# Dependencies

requires "nim >= 1.4.2", "https://github.com/gabbhack/anycase-fork == 0.2.0"

task test, "Run tests":
  exec "nim check src/deser"
  exec "testament all"

task docs, "Generate docs":
  rmDir "htmldocs"
  exec "nimble doc2 --outdir:htmldocs --project --index:on src/deser"
  exec "nim rst2html -o:htmldocs/index.html README.rst"
  exec "testament html"
  mvFile("testresults.html", "htmldocs/testresults.html")
