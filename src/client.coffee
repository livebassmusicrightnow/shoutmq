net        = require "net"
MQTTStream = require "./mqtt-stream"


class Client
  logPrefix: "(ShoutMQ Client)"

  log:        console.log
  error:      console.error
  port:       8001
  mqttPort:   1883
  buffer:     192 * 1024 * 30 # 192Kbps * 30s

  constructor: (o) ->
    @[key] = value for key, value of o
    @log "creating"

    # create shoutcast listener
    @mqttClient = new MQTTStream.Client
      log:    @log
      server: @mqttServer
      port:   @mqttPort
      topic:  @station
      qos:    2
      highWaterMark: @buffer

    @mqttClient.on "end", => @log "mqttClient end"
    @server = net.createServer @sourceHandler
    @server.listen @port, @listener

  listener: (err) =>
    throw new Error err if err
    @log "listening"

  sourceHandler: (source) =>
    @log "connected source"
    source.on "end", =>
      @log "disconnected source"
    source.on "data", (data) =>
      # @log "received data"
      # @log data
    return if @_piped

    source.on "end", =>
      @log "unpiping to mqtt"
      source.unpipe @mqttClient
      @_piped = false
    source.write "HTTP/1.0 200 OK\r\n\r\n"
    @log "piping to mqtt"
    source.pipe @mqttClient, end: false
    @_piped = true


module.exports = Client
