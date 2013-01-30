cluster = require 'cluster'

defaultOptions =
  worker:
    count: 4
    ignoreSigint: true
    require: 'online'
    timeout: 2000

  recycle:
    timeout: 5000

  shutdown:
    timeout: 15000

  restart:
    delay: 2000

module.exports = (func) ->
  options = defaultOptions
  if cluster.isMaster
    timeouts = {}

    cluster.on 'disconnect', (worker) ->
      console.log "Worker #{worker.id} disconnect"

    cluster.on 'fork', (worker) ->
      console.log "Worker #{worker.id} forked with pid #{worker.process.pid}"
      timeouts[worker.id] = setTimeout (() -> failedToStart(worker)), options.worker.timeout

    cluster.on 'listening', (worker, address) ->
      console.log "Worker #{worker.id} listening : #{address.address}:#{address.port}"
      if worker.id of timeouts
        console.log "Clearing timeout for #{worker.id}"
        clearTimeout timeouts[worker.id]
        delete timeouts[worker.id]

    cluster.on 'exit', (worker, code, signal) ->
      console.log "Worker #{worker.id} exit: #{code} #{signal}. Suicide? #{worker.suicide}"
      if not worker.suicide
        console.log "Forking new worker..."
        cluster.fork()

      if Object.keys(cluster.workers).length == 0
        console.log "Graceful exit of all workers. Goodbye!"
        process.exit(0)

    cluster.on 'online', (worker) ->
      console.log "Worker #{worker.id} is online "
      if options.worker.require == 'online' and worker.id of timeouts
          console.log "Clearing timeout for #{worker.id}"
          clearTimeout timeouts[worker.id]
          delete timeouts[worker.id]

    failedToStart = (worker) ->
      console.log "Worker #{worker.id} failed to start. Retrying..."
      worker.destroy()
      setTimeout cluster.fork, options.restart.delay

    recycle = ->
      console.log "Recycle: Starting recycle - this may take some time."
      remaining = (worker for id, worker of cluster.workers)
      
      replace = ->
        worker = remaining.pop()
        if not worker?
          console.log "Recycle: Complete"
          return

        console.log "Recycle: Forking"
        cluster.fork()
        cluster.once options.worker.require, ->
          console.log "Recycle: New fork ready, shutting down worker"
          timeout = setTimeout (->
            console.log "Recycle: Took too long - terminating worker #{worker.id}"
            worker.destroy()
          ), options.recycle.timeout

          worker.disconnect()
          worker.on 'exit', ->
            console.log("Recycle: Worker #{worker.id} exited")
            clearTimeout(timeout)
            replace()

      replace()

    shutdown = ->
      console.log "Graceful termination"
      cluster.disconnect () ->
        console.log Object.keys(cluster.workers).length
        console.log "All workers disconnected."

      setTimeout (->
        console.log "Took too long to shutdown gracefully, terminating workers."
        for id, worker of cluster.workers
          console.log "Destroying worker #{id}"
          worker.destroy()
      ), options.shutdown.timeout

    process.on "SIGHUP", recycle
    process.on "SIGTERM", shutdown
    process.on "SIGINT", shutdown

    for i in [0...options.worker.count]
      worker = cluster.fork()

    console.log "Master ready #{process.pid}"
  else
    if options.worker.ignoreSigint
      process.on "SIGINT", () -> console.log "Worker pid #{process.pid} ignoring SIGINT"
    func()
