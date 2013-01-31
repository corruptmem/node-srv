**srv** is a node.js module that lets you run multiple instances of your node.js server application: each in a different process, but all sharing the same listening ports (if any). 

What is 'srv'?
--------------
srv is a very thin layer ontop of the node 0.8 [cluster API](http://nodejs.org/api/cluster.html) that:
* Implements zero-downtime restarts
* Implements graceful restarts and shutdowns (i.e. without kicking out any connected users)
* Handles process crashes by starting a replacement worker
* Lets you manage it (restart, graceful shutdown) via UNIX signals

Unlike other similar modules ([forever](https://github.com/nodejitsu/forever), [always](https://github.com/edwardhotchkiss/always) and [naught](https://github.com/indabamusic/naught)), srv:
* Does not require a seperate command line tool: management is done using UNIX signals and process monitoring
* Does not require a global package install
* Won't daemonise your process - I think this is best done using another process monitor, usually built into the system (see below). 
* Won't write PIDs 
* Won't handle log files for you
* Does not implement a complicated event system and instead tries to built ontop of what node and UNIX provide
* Requires integration at development time
* Is less general purpose
* **Is basically untested. Use at your own risk.**


Installation
------------

    $ npm install srv

*You do not need to download the source code on this page unless you want to change it.*

Usage 
-----

require('srv') will return a function, this function can be called two ways:

* **srv(options object, callback function)**
* **srv(callback function)**

When called, this function will fork the process into the specified number of child processes, using the standard [cluster API](http://nodejs.org/api/cluster.html) and execute your callback in each of them.

For example, in coffeescript:

```coffeescript

srv = require 'srv'
cluster = require 'cluster'

srv ->
  console.log "Hello from #{process.pid}"

  cluster.worker.on 'disconnect', ->
    console.log "Goodbye from #{process.pid}"
```

Besides log statements, this will output something like the following:

    Hello from 33724
    Hello from 33723
    Hello from 33725
    Hello from 33726

When you press CTRL+C, it will output the following then terminate:

    Goodbye from 33726
    Goodbye from 33723
    Goodbye from 33725
    Goodbye from 33724


Options
-------
TBC

Signals and events
------------------
TBC

Process monitoring 
------------------
As I mentioned above, srv is not a generic process monitor. It will not handle starting your service in the first place, nor does it provide you with any administrative interface to see if it's running or stop it, other than terminating itself gracefully when told to by SIGTERM. 

On Linux, would recommend against traditional init, and instead suggest:
* [upstart](http://upstart.ubuntu.com/cookbook/) on Ubuntu and others. *Note: As I use Ubuntu, I will be providing an example Upstart script shortly!*
* [systemd](http://www.freedesktop.org/wiki/Software/systemd) on Fedora, Arch and others

On Windows, I would suggest launching the node process with [the Non-Sucking Service Manager](http://nssm.cc/).

I presume nobody hosts anything on a Mac. :)

All of these solutions work best if you have a process that doesn't daemonize itself, which is what "inspired" me to write srv.

Reliability
-----------
srv is not a special piece of well segregated, battle hardened code that is specifically engineered to never allow a worker failure to disrupt the service.
It is meant to help you start a generally reliable set of clustered processes. I do not, however, expect that it will be hard to find ways to
take the master process down from inside the worker processes, but hopefully that won't be something you can do unless you mean to do it.

If you want real reliability, I would suggest multiple entirely seperate node processes (not clustered), managed by your system's process monitor,
and load balanced by something such as HAProxy or nginx, with each part of the stack running under a seperate user so that failures can't propagate as easily, 
and heartbeating used throughout. If you are really bothered about reliability, you will need multiple machines anyway. 

What srv is meant to be is a 95% solution. It should be fine for any non-essential service, where you can configure your process monitor just to restart it if it crashes. 
It should go some way toward ironing out latency spikes and would be a good second reliability defence at any rate.

Contributing
------------
TBC
