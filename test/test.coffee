#Canvas = require("canvas")
#Image = Canvas.Image
#fs = require("fs")
#img = new Image
#img.onerror = (err) ->
#  throw err
#
#img.onload = ->
#  w = img.width / 2
#  h = img.height / 2
#  canvas = new Canvas(w, h)
#  ctx = canvas.getContext("2d")
#  ctx.drawImage img, 0, 0, w, h, 0, 0, w, h
#  out = fs.createWriteStream(__dirname + "/crop.png")
#  stream = canvas.createPNGStream()
#  #stream.pipe out
#  stream.on 'data', (c) ->
#    out.write c
#  stream.on 'end', ->
#    console.log "file written"
#
#img.src = __dirname + "/fixtures/precompile/assets/sprites/fall.png"

require('./fixtures/precompile/assets/stylesheets/application.css') ->
  require('child_process').exec "google-chrome #{__dirname}/fixtures/static/public/index.html"
  console.log "done"
