CoffeeSprites = require '../js/coffee-sprites'
assert = require('chai').assert

describe 'CoffeeSprites', ->
  it 'works', (done) ->
    require('./fixtures/precompile/assets/stylesheets/application.css') ->
      require('child_process').exec "google-chrome #{__dirname}/fixtures/static/public/index.html"
      done()
