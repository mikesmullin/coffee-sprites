CoffeeSprites = require '../js/coffee-sprites'
CoffeeStylesheets = require 'coffee-stylesheets'
assert = require('chai').assert
path = require 'path'
fs = require 'fs'
exec = require('child_process').exec
fixtures_path = path.join __dirname, 'fixtures'
stylesheet = `undefined`
engine = `undefined`
infile = path.join fixtures_path, 'precompile', 'assets', 'stylesheets', 'application.css.coffee'
outfile = path.join fixtures_path, 'static', 'public', 'assets', 'application.css'

describe 'CoffeeSprites', ->
  beforeEach (done) ->
    engine = new CoffeeStylesheets format: true
    pngcrush = `undefined`
    exec "which pngcrush", (err, stdout) ->
      pngcrush = stdout.trim()
      engine.use new CoffeeSprites
        image_path: path.join fixtures_path, 'precompile', 'assets', 'sprites'
        sprite_path: path.join fixtures_path, 'static', 'public', 'assets'
        sprite_url:  './'
        pngcrush: pngcrush
      done()

  afterEach ->
    console.log "now do a visual check in Google Chrome to ensure sanity"
    exec "google-chrome #{__dirname}/fixtures/static/public/index.html"

  it 'compiles sprites with .css.coffee, outputting sprite PNGs to given path', (done) ->
    stylesheet = require infile
    css = engine.render stylesheet, (err, css) ->
      throw err if err
      fs.writeFileSync outfile, css
      assert.ok fs.existsSync
      done()
