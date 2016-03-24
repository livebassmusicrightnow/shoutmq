http    = require "http"
stream  = require "stream"
express = require "express"
Icy     = require "icy"


NO_METADATA = new Buffer [0]

Icy.Writer::_inject = (write) ->
  if @disableMetadata
    @_passthrough Infinity
    return

  buffer = if @_queue.length
    @_queue.shift()
  else
    NO_METADATA
  write buffer

  # passthrough "metaint" bytes before injecting the next metabyte
  @_passthrough @metaint, @_inject


class Server extends stream.PassThrough
  logPrefix: "(EvenNicercast Server)"

  log:     console.log
  error:   console.error
  name:    "EvenNicercast"
  port:    8000
  metaint: 8192
  address: "127.0.0.1"
  buffer:  192 * 1024 * 30 # 192Kbps * 30s

  constructor: (o) ->
    @[key] = value for key, value of o
    @log "creating"
    super highWaterMark: @buffer

    @app = express()
    @app.disable "x-powered-by"
    @setupRoutes()

  setupRoutes: ->
    @app.get "/",           @playlistEndpoint
    @app.get "/listen.m3u", @playlistEndpoint
    # audio endpoint
    @app.get "/listen",     @listener

  playlistEndpoint: (req, res) =>
    @log "serving playlist"
    # stream playlist (points to other endpoint)
    res.status 200
    res.set "Content-Type", "audio/x-mpegurl"
    res.send "http://#{@address}:#{@port}/listen"

  listener: (req, res, next) =>
    @log "listening"

    acceptsMetadata = req.headers["icy-metadata"] is 1

    # generate response header
    headers =
      "Content-Type": "audio/mpeg"
      "Connection":   "close"
    if acceptsMetadata
      @log "client accepts metadata"
      headers["icy-metaint"] = @metaint
    res.writeHead 200, headers

    # setup metadata transport
    prevMetadata = 0
    queueMetadata = (metadata = @metadata or @name) =>
      return unless acceptsMetadata and prevMetadata isnt metadata
      @log "queueing metadata"
      icyWriter.queueMetadata metadata
      prevMetadata = metadata

    @log "laying pipe"
    icyWriter = new Icy.Writer @metaint
    icyWriter.disableMetadata = true unless acceptsMetadata
    queueMetadata()
    icyWriter.pipe res, end: false
    @pipe icyWriter, end: false
    @on "data", queueMetadata

    req.connection.on "close", =>
      @log "closing connection, unpiping"
      @removeListener "data", queueMetadata
      @unpipe icyWriter

  setMetadata: (@metadata) -> @queueMetadata()

  start: (port = @port, callback = ->) ->
    @log "starting server on :#{port}"
    await @server = (http.createServer @app).listen port, defer()
    @port = @server.address().port
    callback @port

  stop: ->
    @log "stopping"
    try
      @server.close()
    catch err
      @error err


class EncodingServer extends stream.PassThrough
  logPrefix: "(EvenNicercast EncodingServer)"

  log:   console.log
  error: console.error
  port:  8000

  # 16-bit signed samples
  SAMPLE_SIZE: 16
  CHANNELS:    2
  SAMPLE_RATE: 44100

  constructor: (o) ->
    @[key] = value for key, value of o
    @log "creating"
    super()

    # If we"re getting raw PCM data as expected, calculate the number of bytes
    # that need to be read for `1 Second` of audio data.
    BLOCK_ALIGN:      SAMPLE_SIZE / 8 * CHANNELS
    BYTES_PER_SECOND: SAMPLE_RATE * BLOCK_ALIGN

    # setup encoder
    Lame     = require "lame"
    @encoder = new Lame.Encoder
      channels:   @CHANNELS
      bitDepth:   @SAMPLE_SIZE
      sampleRate: @SAMPLE_RATE

    @server = new Server
      log:   @log
      error: @error
      port:  @port

    @pipe @encoder
    @encoder.pipe @server

  setMetadata: -> @server.setMetadata()
  start: -> @server.start()
  stop: -> @server.stop()


EvenNicercast =
  # Source:         Source
  Server:         Server
  EncodingServer: EncodingServer

module.exports = EvenNicercast
