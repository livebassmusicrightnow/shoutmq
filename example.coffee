ShoutMQ = require "./shoutmq"

now   = -> (new Date Date.now()).toLocaleTimeString()
log   = (msg) -> console.log   "[#{now()}] [INFO]  #{@logPrefix} #{msg}"
error = (msg) -> console.error "[#{now()}] [ERROR] #{@logPrefix} #{msg}"

new ShoutMQ.Server
  station:    "KDNB"
  mqttServer: "arangodb-smartos"
  log:        log
  error:      error

new ShoutMQ.Client
  station:    "KDNB"
  mqttServer: "arangodb-smartos"
  log:        log
  error:      error
