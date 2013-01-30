cluster = require 'cluster'
winston = require 'winston'
_ = require 'underscore'

defaultOptions =
  worker:
    count: 4
    ignoreSigint: true
    require: 'online'
    timeout: 2000

  recycle:
    timeout: 15000

  shutdown:
    timeout: 15000

  restart:
    delay: 5000

  logger: null # use default logger

module.exports = (options, func) ->
  if not func?
    func = options
    options = {}

  _.defaults options, defaultOptions
  _.defaults options.worker, defaultOptions.worker
  _.defaults options.recycle, defaultOptions.recycle
  _.defaults options.shutdown, defaultOptions.shutdown

  logger = options.logger ? winston.loggers.get('srv')

  if cluster.isMaster
    logger.on 'error', (err) -> console.error(err)
    timeouts = {}

    cluster.on 'disconnect', (worker) ->
      logger.info "Worker #{worker.id} disconnect"

    cluster.on 'fork', (worker) ->
      logger.info "Worker #{worker.id} forked with pid #{worker.process.pid}"
      timeouts[worker.id] = setTimeout (() -> failedToStart(worker)), options.worker.timeout

    cluster.on 'listening', (worker, address) ->
      logger.info "Worker #{worker.id} listening : #{address.address}:#{address.port}"
      if worker.id of timeouts
        logger.debug "Clearing timeout for #{worker.id}"
        clearTimeout timeouts[worker.id]
        delete timeouts[worker.id]

    cluster.on 'exit', (worker, code, signal) ->
      logger.info "Worker #{worker.id} exit: #{code} #{signal}. Suicide? #{worker.suicide}"
      if not worker.suicide
        logger.warn "Worker #{worker.id} crashed! Forking new worker..."
        cluster.fork()

      if Object.keys(cluster.workers).length == 0
        logger.info "Graceful exit of all workers. Goodbye!"
        process.exit(0)

    cluster.on 'online', (worker) ->
      logger.info "Worker #{worker.id} is online "
      if options.worker.require == 'online' and worker.id of timeouts
          logger.debug "Clearing timeout for #{worker.id}"
          clearTimeout timeouts[worker.id]
          delete timeouts[worker.id]

    failedToStart = (worker) ->
      logger.warn "Worker #{worker.id} failed to start. Retrying..."
      worker.destroy()
      setTimeout cluster.fork, options.restart.delay

    recycle = ->
      logger.info "Recycle: Starting recycle - this may take some time."
      remaining = (worker for id, worker of cluster.workers)
      
      replace = ->
        worker = remaining.pop()
        if not worker?
          logger.info "Recycle: Complete"
          return

        logger.info "Recycle: Forking"
        cluster.fork()
        cluster.once options.worker.require, ->
          logger.info "Recycle: New fork ready, shutting down worker"
          timeout = setTimeout (->
            logger.warn "Recycle: Took too long - destroying worker #{worker.id}"
            worker.destroy()
          ), options.recycle.timeout

          worker.disconnect()
          worker.on 'exit', ->
            logger.info "Recycle: Worker #{worker.id} exited"
            clearTimeout(timeout)
            replace()

      replace()

    shutdown = ->
      logger.info "Graceful termination"
      cluster.disconnect () ->
        logger.info "All workers disconnected."

      setTimeout (->
        logger.warn "Took too long to shutdown gracefully, terminating workers."
        for id, worker of cluster.workers
          logger.warn "Destroying worker #{id}"
          worker.destroy()
      ), options.shutdown.timeout

    process.on "SIGHUP", () ->
      logger.warn "MasterRecieved SIGHUP"
      recycle
    process.on "SIGTERM", shutdown
    process.on "SIGINT", shutdown

    for i in [0...options.worker.count]
      worker = cluster.fork()

    logger.info "Master ready #{process.pid}"
  else
    if options.worker.ignoreSigint
      process.on "SIGINT", () -> logger.warn "Worker pid #{process.pid} ignoring SIGINT"
    func()
