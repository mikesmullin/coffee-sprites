CoffeeSprites = require '../js/coffee-sprites'
CoffeeStylesheets = require 'coffee-stylesheets'
assert = require('chai').assert
path = require 'path'
fs = require 'fs'
exec = require('child_process').exec
fixtures_path = path.join __dirname, 'fixtures'
stylesheet = `undefined`
engine = `undefined`
inpath = path.join fixtures_path, 'precompile', 'assets', 'stylesheets'
outpath = path.join fixtures_path, 'static', 'public', 'assets'

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

  render_to_disk = (stylesheet, file, cb) ->
    css = engine.render stylesheet, (err, css) ->
      throw err if err
      outfile = path.join outpath, file
      fs.writeFileSync outfile, css
      assert.ok fs.existsSync outfile
      cb()

  after ->
    console.log "now do a visual check in Google Chrome to ensure sanity"
    exec "google-chrome #{__dirname}/fixtures/static/public/index.html"

  it 'compiles sprites with .css.coffee, outputting sprite PNGs to given path', (done) ->
    stylesheet = require path.join inpath, 'application.css.coffee'
    render_to_disk stylesheet, 'application.css', done

  it 'compiles sprites across .css.coffee files, outputting to same PNGs', (done) ->
    stylesheet = require path.join inpath, 'other.css.coffee'
    render_to_disk stylesheet, 'other.css', ->
      # as long as you re-save the files before it
      # note: this only has to happen the first time
      # once the manifest.json has all the images defined
      # then a change in any .css file will generate all
      # sprite images between all files
      stylesheet = require path.join inpath, 'application.css.coffee'
      render_to_disk stylesheet, 'application.css', done

