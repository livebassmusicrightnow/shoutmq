MQTTStream = require "./mqtt-stream"


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


module.exports = Server
