{exec} = require 'child_process'
task "build", "build the module", ->
  exec "mkdir -p lib && ./node_modules/coffee-script/bin/coffee --compile --output lib/ src/", (err, stdout, stderr) ->
    throw err if err
    out = stdout + stderr

    if out? and out.length > 0
      console.log stdout + stderr
