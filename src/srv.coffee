cluster = require 'cluster'

defaultOptions =
  worker:
    count: 4
    ignoreSigint: true
    requireListen: false
    timeout: 2000

  recycle:
    timeout: 60000

  shutdown:
    timeout: 1000

  restart:
    delay: 2000

module.exports = (func) ->
  options = defaultOptions
  if cluster.isMaster
    timeouts = {}

    cluster.on 'disconnect', (worker) ->
      console.log "Worker #{worker.id} disconnect"

    cluster.on 'fork', (worker) ->
      console.log("Worker #{worker.id} forked")
      timeouts[worker.id] = setTimeout (() -> failedToStart(worker)), options.worker.timeout

    cluster.on 'listening', (worker, address) ->
      console.log "Worker #{worker.id} listening : #{address.address}:#{address.port}"
      if worker.id of timeouts
        console.log "Clearing timeout for #{worker.id}"
        clearTimeout timeouts[worker.id]
        delete timeouts[worker.id]

    cluster.on 'exit', (worker, code, signal) ->
      console.log "Worker #{worker.id} exit: #{code} #{signal}. Suicide? #{worker.suicide?}"

    cluster.on 'online', (worker) ->
      console.log "Worker #{worker.id} is online "
      if not options.worker.requireListen and worker.id of timeouts
          console.log "Clearing timeout for #{worker.id}"
          clearTimeout timeouts[worker.id]
          delete timeouts[worker.id]

    failedToStart = (worker) ->
      console.log "Worker #{worker.id} failed to start in a timely fashion. Retrying..."
      worker.destroy()
      setTimeout cluster.fork, options.restart.delay

    recycle = ->
      console.log "Recycling workers: NOT IMPLEMENTED!"

    shutdown = ->
      console.log "Graceful termination"
      cluster.disconnect () ->
        console.log "All workers terminated. Goodbye!"
        process.exit 0

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
      process.on "SIGINT", () -> console.log "Worker #{process.pid} ignoring SIGINT"
    func()
