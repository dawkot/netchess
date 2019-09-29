# Package

version       = "0.1.0"
author        = "Anonymous"
description   = "A new awesome nimble package"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.0.0"
requires "karax 1.1.0"
requires "ws 0.2.3"
requires "jswebsockets 0.1.3"

# Tasks

task buildServer, "":
  exec "nim c src/server"

task runServer, "":
  exec "nim c -r src/server"

task buildClient, "":
  exec "karun src/clientbrowser"

task runClient, "":
  exec "karun -r src/clientbrowser"