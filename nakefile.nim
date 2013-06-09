import nake

task "build-client", "build the client":
  direShell "nimrod c asteroids"
task "build-server", "build the server":
  direShell "nimrod c server"

task "build-both", "build both!":
  runTask "build-server"
  runTask "build-client"

