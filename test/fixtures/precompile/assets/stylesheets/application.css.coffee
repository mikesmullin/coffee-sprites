module.exports = (done) ->
  path = require 'path'
  fs = require 'fs'
  fixtures_path = path.resolve __dirname, '../../..'

  CoffeeStylesheets = require 'coffee-stylesheets'
  engine = new CoffeeStylesheets format: true

  CoffeeSprites = require __dirname + '/../../../../../js/coffee-sprites'
  engine.use new CoffeeSprites
    image_path: fixtures_path + '/precompile/assets/sprites/'
    sprite_path: fixtures_path + '/static/public/assets/'
    sprite_url:  './'

  stylesheet = ->
    s '*', ->
      margin 0
      padding 0
      font_size '1em'
    s 'html, body', ->
      height '100%'
    body ->
      background '#eee'
      color '#333'
      margin '20px'
    wigi = sprite_map 'wigi',
      spacing: 10
    s '#wigi', ->
      background "url(#{sprite_url wigi}) no-repeat"
      height sprite_height wigi, 'fly-3'
      width sprite_width wigi, 'fly-3'
    for i, v of 'walk-1 walk-2 walk-3 run-1 run-2 run-3 fly-1 fly-2 fly-3 fall jump'.split ' '
      s '#wigi.wigi-'+i, ->
        background_position sprite_position wigi, v

  css = engine.render stylesheet, (err, css) ->
    fs.writeFileSync fixtures_path + '/static/public/assets/application.css', css
    done()
