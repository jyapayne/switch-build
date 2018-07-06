# Package

version       = "0.1.2"
author        = "Joey Payne"
description   = "Nintendo Switch library libnx for Nim."
license       = "The Unlicense"

srcDir = "src"

bin = @["switch_build"]

# Deps
requires "nim >= 0.18.1"

task test, "Run tests":
  exec "nim c -r tests/test.nim"
