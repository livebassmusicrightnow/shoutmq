stream = require "stream"
MQTT   = require "mqtt"


class MQTTServer
  logPrefix: "(MQTTServer)"

  log:   console.log
  error: console.error
  port:  1883

  ascoltatore:
    type:           "redis"
    db:             12
    port:           6379
    return_buffers: true
    host:           "localhost"

  constructor: (o) ->
    @[key] = value for key, value of o
    @log "creating"

    Mosca = require "mosca"
    Redis = require "redis"
    @ascoltatore.redis = Redis
    @moscaSettings or=
      port:        @port
      backend:     @ascoltatore
      persistence: factory: Mosca.persistence.Redis

    @server = new Mosca.Server @moscaSettings
    @bindEvents()

  bindEvents: ->
    @server.on "ready", =>
      @log "ready for connections on :#{@port}"
      @readyHandler()

    @server.on "clientConnected", @clientHandler
    @server.on "published", @publishHandler

  clientHandler: (client) => @log "connected client #{client.id}"
  publishHandler: (packet, client) => @log "received packet from client #{client?.id}" # packet.payload


class Server extends stream.PassThrough
  logPrefix: "(MQTTStream Server)"

  log:           console.log
  error:         console.error
  port:          8000
  sourcePort:    1883
  highWaterMark: 16384
  qos:           1

  constructor: (o) ->
    @[key] = value for key, value of o
    @log "creating"
    super highWaterMark: @highWaterMark

    if @server then @connectMqtt()
    else
      @mqttServer or= new MQTTServer
        readyHandler: @connectMqtt
        port:         @sourcePort
        log:          @log

  connectMqtt: =>
    @server or= "#{@mqttServer.ascoltatore.host}"
    @server   = "mqtt://#{@server}" unless /mqtt:/.exec @server
    @log "connecting to #{@server}"
    @mqttClient = MQTT.connect @server
    @mqttClient.on "connect", @subscribe
    @mqttClient.on "error", (args...) => @error args...

  subscribe: =>
    @log "connected"
    @log "subscribing to #{@topic}"
    await @mqttClient.subscribe @topic, {qos: @qos}, defer err, grantedlist
    throw new Error err if err
    @log "subscription granted to #{granted.topic} with QOS #{granted.qos}" for granted in grantedlist
    @mqttClient.on "message", @fill

  fill: (topic, message, packet) =>
    # @log "received message"
    @log "received NULL, ending stream" unless message
    success = @write message
    unless success then @error "buffer full"


class Client extends stream.Writable
  logPrefix: "(MQTTStream Client)"

  log:   console.log
  error: console.error
  port:  1883
  qos:   1

  constructor: (o) ->
    throw new Error "server parameter required" unless o.server
    @[key] = value for key, value of o
    @log "creating"
    super highWaterMark: @highWaterMark
    @connectMqtt()

  connectMqtt: ->
    server = "mqtt://#{@server}:#{@port}"
    @log "connecting to MQTT server #{server}"
    @mqttClient = MQTT.connect server
    @mqttClient.on "connect", @openValves
    @mqttClient.on "error", (args...) => @error args...

  openValves: =>
    @log "connected"
    @log "laying pipe to #{@topic}"

  _write: (chunk, encoding, callback) =>
    @log "received NULL, ending stream" unless chunk
    @mqttClient.publish @topic, chunk, qos: @qos
    callback()



MQTTStream =
  Server: Server
  Client: Client

module.exports = MQTTStream
