net        = require "net"
MQTTStream = require "./mqtt-stream"

# first make a mqtt server and client
# then layer shoutcast protocol over server to client
# pipe a file from server to client over mqtt
# then add function to inject metadata from external source


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


class Server
  logPrefix: "(ShoutMQ Server)"

  log:        console.log
  error:      console.error
  port:       8000
  host:       "localhost"
  mqttPort:   1883
  buffer:     192 * 1024 * 30 # 192Kbps * 30s
  metaint:    16000

  constructor: (o) ->
    @[key] = value for key, value of o
    @log "creating"

    @mqttServer = new MQTTStream.Server
      log:    @log
      error:  @error
      server: @mqttServer
      port:   @port
      topic:  @station
      qos:    2
      highWaterMark: @buffer

    EvenNicercast = require "./even-nicercast"
    @server = new EvenNicercast.Server
      log:     @log
      address: @host
      port:    @port
      metaint: @metaint
    @server.start()
    # web server ...
    @openValves()

  openValves: =>
    @log "connected"
    # put Icy.Reader inbetween to strip and push metadata to Icy.Writer
    # if @passMetaData then @icyReader.pipe @server; @mqttServer.pipe @icyReader
    @mqttServer.pipe @server, end: false

  listener: (err) =>
    throw err if err
    @log "serving shoutcast on :#{@port}"

  # metadata: () ->
  # title: () -> @metadata name: ...


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



ShoutMQ =
  Relay:  Relay
  Server: Server
  Client: Client

module.exports = ShoutMQ
