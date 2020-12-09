# Package

version       = "0.1.0"
author        = "gabbhack"
description   = "De/serialization library for Nim "
license       = "MIT"
srcDir        = "src"


# Dependencies

requires "nim >= 1.4.0", "https://github.com/gabbhack/anycase-fork == 0.2.0"

task test, "Run tests":
  exec "nim check src/deser"
  exec "testament all"
