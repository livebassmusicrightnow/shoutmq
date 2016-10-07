MQTTStream = require "./mqtt-stream"


class Relay
  logPrefix: "(ShoutMQ Relay)"

  log:        console.log
  error:      console.error
  server:     "localhost"
  port:       8001
  mount:      "stream"
  mqttServer: "localhost"
  mqttPort:   1883
  buffer:     192 * 1024 * 30 # 192Kbps * 30s

  constructor: (o) ->
    @[key] = value for key, value of o
    @log "creating"

    @mqttServer = new MQTTStream.Server
      log:    @log
      server: @mqttServer
      port:   @mqttPort
      topic:  @station
      highWaterMark: @buffer

    IceSource  = require "icecast-source"
    @iceSource = new IceSource
      host:  @server
      port:  8001
      mount: @mount
    , @openValves
    # web server ...

  openValves: =>
    @log "connected"
    @mqttServer.pipe @iceSource

  # metadata: () ->
  # title: () -> @metadata name: ...


module.exports = Client
