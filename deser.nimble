# Package

version       = "0.3.2"
author        = "gabbhack"
description   = "De/serialization library for Nim"
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.6.0"

# Tasks
import std/[os, strformat]

task test, "Run tests":
  exec "testament all"

task docs, "Generate docs":
  rmDir "docs"
  exec "nimble doc2 --outdir:docs --project --git.url:https://github.com/gabbhack/deser --git.commit:master --index:on src/deser"
