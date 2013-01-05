# CoffeeSprites

**CoffeeSprites** is a plugin for Node.js [CoffeeStylesheets](https://github.com/mikesmullin/coffee-stylesheets)
which allows you to use functions like `sprite_position()`, `sprite_height()`, `image_width()`, `sprite_map()`, etc.
within your `*.css.coffee` markup to automatically fetch images and generate css sprites at render time.

If you come from the Ruby on Rails community, you will immediately recognize conventions from Spriting
with [Compass](http://compass-style.org/help/tutorials/spriting/)/SASS, originally [Lemonade](http://www.hagenburger.net/BLOG/Lemonade-CSS-Sprites-for-Sass-Compass.html).

## Installation on Debian/Ubuntu

```bash
sudo apt-get install libgd2-xpm-dev # libgd; the node-gd dependency
sudo apt-get install pngcrush # optional; helps compress PNG
npm install coffee-sprites
```

## Use

```coffeescript
CoffeeStylesheets = require 'coffee-stylesheets'
engine = new CoffeeStylesheets format: true

CoffeeSprites = require __dirname + 'coffee-sprites'
engine.use new CoffeeSprites
  image_path:  __dirname + '/precompile/assets/sprites/'
  sprite_path: __dirname + '/static/public/assets/'
  sprite_url:  '/assets/'

  stylesheet = ->
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
  fs.writeFileSync __dirname + '/static/public/assets/application.css', css
```

Will output CSS like this:

```css
#wigi {
  background: url(./wigi-2e192be7fd.png) no-repeat;
  height: 112px;
  width: 96px;
}
#wigi.wigi-0 {
  background-position: 0 -122px;
}
#wigi.wigi-1 {
  background-position: 0 -244px;
}
#wigi.wigi-2 {
  background-position: 0 -366px;
}
#wigi.wigi-3 {
  background-position: 0 -484px;
}
#wigi.wigi-4 {
  background-position: 0 -606px;
}
#wigi.wigi-5 {
  background-position: 0 -728px;
}
#wigi.wigi-6 {
  background-position: 0 -850px;
}
#wigi.wigi-7 {
  background-position: 0 -968px;
}
#wigi.wigi-8 {
  background-position: 0 0;
}
#wigi.wigi-9 {
  background-position: 0 -1086px;
}
#wigi.wigi-10 {
  background-position: 0 -1208px;
}
```

And the sprite image(s) will turn out like this:

 * [test/fixtures/static/public/assets/wigi-2e192be7fd.png](https://github.com/mikesmullin/coffee-sprites/blob/stable/test/fixtures/static/public/assets/wigi-2e192be7fd.png)

For the very latest and most comprehensive example, see [test/fixtures/precompile/assets/stylesheets/application.css.coffee](https://github.com/mikesmullin/coffee-sprites/blob/stable/test/fixtures/precompile/assets/stylesheets/application.css.coffee).

## Test

```bash
npm test # build coffee, run mocha unit test, run chrome browser integration test
```
