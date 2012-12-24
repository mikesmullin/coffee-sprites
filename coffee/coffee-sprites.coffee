gd = require 'node-gd'
async = require 'async2'
fs = require 'fs'
path = require 'path'
instance = undefined

class CoffeeSprites
  constructor: (o) ->
    o = o or {}
    o.image_path = o.image_path or ''
    o.sprite_path = o.sprite_path or ''
    o.sprite_url = o.sprite_url or ''
    o.manifest_file = o.manifest_file or path.join o.sprite_path, 'sprite-manifest.json'
    @o = o
    @sprites = {}
    @flow = new async()
    @read_manifest()

  read_manifest: ->
    _this = @
    if fs.existsSync @o.manifest_file
      data = (JSON.parse(fs.readFileSync @o.manifest_file)) or {}
      for name of data.sprites
        @sprites[name] = new Sprite name, data.sprites[name].options
        for i, file of data.sprites[name].images
          ((file)->
            _this.flow.serial ->
              _this.sprites[name].add file, @
          )(file)
    return

  write_manifest: ->
    data =
      sprites: {}
    for name of @sprites
      data.sprites[name] =
        options: @sprites[name].o
        images: []
      for file of @sprites[name].images
        data.sprites[name].images.push file
    fs.writeFileSync @o.manifest_file, JSON.stringify data, null, 2
    return

  extend: (engine) -> # CoffeeStylesheets instance
    g=engine.o.globals

    g.sprite_map = (name, options) =>
      sprite = new Sprite name, options
      @sprites[name] = sprite

    generate_placeholder = (key, sprite, png) =>
      if typeof png isnt 'undefined'
        @flow.series -> sprite.add png, @
      "SPRITE_#{key}_PLACEHOLDER(#{sprite.name}, #{png or ''})"

    g.sprite = (sprite, png) ->
      generate_placeholder 'URL_AND_IMAGE_POSITION', sprite, png

    g.sprite_url = (sprite) ->
      generate_placeholder 'URL', sprite

    g.sprite_position = (sprite, png) ->
      generate_placeholder 'POSITION', sprite, png

    g.sprite_width = (sprite, png) ->
      generate_placeholder 'WIDTH', sprite, png

    g.sprite_height = (sprite, png) ->
      generate_placeholder 'HEIGHT', sprite, png

    # callback fired by engine.render()
    engine.on.end = (css, done) =>
      @flow.finally =>
        # replace placeholders in css
        css = css.replace /SPRITE_(.+?)_PLACEHOLDER\((.+?), (.*?)\)/g, (match, key, name, png) =>
          sprite = @sprites[name]
          image = sprite.images[png]
          switch key
            when 'POSITION'
              return image.coords()
            when 'URL'
              return sprite.digest_url()
            when 'URL_AND_IMAGE_POSITION'
              return "url(#{sprite.digest_url()}) #{image.coords()}"
            when 'WIDTH'
              return image.px image.width
            when 'HEIGHT'
              return image.px image.height

        # save final sprites to disk
        flow = new async()
        for name, sprite of @sprites
          ((sprite)->
            flow.series ->
              sprite.render @
              return
          )(sprite)
        flow.finally =>
          # return final css
          @write_manifest()
          done null, css
          return
        return
      return
    return

sprite_count = 0

class Sprite
  constructor: (name, o) ->
    if typeof name isnt 'string'
      o = name
      name = ''
    @name = name or 'sprite-'+(++sprite_count)
    o = o or {}
    o.repeat = o.repeat or 'no-repeat'
    @images = {}
    @x = 0
    @y = 0
    @width = 0
    @height = 0
    @png = undefined
    @digest = ''
    @o = o
    return

  add: (file, callback) ->
    # if existing image within sprite
    unless typeof @images[file] is 'undefined'
      @images[file] # cached
      callback null
    else # new image not in sprite
      # calculate
      image = @images[file] = new Image file, @x, @y, (err) =>
        return callback err if err
        # TODO: allow repeat to dictate how cursor is incremented here; or do it all-at-once during render
        @width = Math.max @width, image.width
        @y = @height += image.height + (@o.spacing or 0)

        # update sprite digest
        blob = ''
        for key of @o
          blob += ''+key+':'+@o[key]+'|'
        for key, image of @images
          blob += image+'|'
        @digest = require('crypto').createHash('md5').update(blob).digest('hex').substr(-10)
        callback null
    return

  render: (callback) ->
    # save sprite image
    sprite = @

    return callback "sprite map was created but no images added" if sprite.width < 1

    return callback "no change would occur" if fs.existsSync sprite.digest_file()

    # create new blank sprite canvas
    sprite.png = gd.createTrueColor sprite.width, sprite.height
    transparency = sprite.png.colorAllocateAlpha 0, 0, 0, 127
    sprite.png.fill 0, 0, transparency
    sprite.png.colorTransparent transparency
    sprite.png.alphaBlending 0
    sprite.png.saveAlpha 1

    # compile sprite in memory
    flow = new async()
    for key of sprite.images
      ((image) ->
        flow.series ->
          done = @
          image.open ->
            #console.log "rendering #{image.file} over #{sprite.name} at #{image.coords()} with #{sprite.o.repeat}..."
            # TODO: support smart rendering for more compact image placement
            switch sprite.o.repeat
              when 'no-repeat'
                image.png.copy sprite.png, image.x, image.y, 0, 0, image.width, image.height
              when 'repeat-x'
                for x in [0..sprite.width] by image.width
                  image.png.copy sprite.png, x, image.y, 0, 0, image.width, image.height
              when 'repeat-y'
                for y in [0..sprite.height] by image.height
                  image.png.copy sprite.png, image.x, y, 0, 0, image.width, image.height
            done()
            return
          return
        )(sprite.images[key])
    flow.finally ->
      # delete old sprites off disk
      pattern = sprite.digest_file().replace /-[\w\d+]+\.png$/, '-*.png'
      files = require('glob').sync pattern
      for file in files
        fs.unlinkSync file

      # override sprite png on disk
      sprite.png.savePng sprite.digest_file(), 0, ->
        console.log "Wrote #{sprite.digest_file().replace process.cwd() + '/', ''}."
        # TODO: add pngcrush here
        callback null, sprite.digest_file()
        return
      return
    return

  digest_file: ->
    instance.o.sprite_path + @name + '-' + @digest + '.png'

  digest_url: ->
    instance.o.sprite_url + @name + '-' + @digest + '.png'


class Image
  constructor: (@file, @x, @y, callback) ->
    @png = undefined
    @height = undefined
    @width = undefined
    @absfile = path.join instance.o.image_path, @file+'.png'
    @open (err) =>
      return callback err if err
      @height = @png.height
      @width  = @png.width
      callback null
    return

  toString: ->
    "Image#file=#{@file},x=#{@x},y=#{@y},width=#{@width},height=#{@height}"

  open: (callback) ->
    gd.openPng @absfile, (err, png) =>
      return callback err if err
      @png = png
      callback null

  px: (i) ->
    if i is 0 then 0 else i + 'px'

  coords: ->
    @px(@x * -1) + ' ' + @px(@y * -1)

module.exports = (options) ->
  instance = new CoffeeSprites options
  (engine) ->
    instance.extend engine
    instance
