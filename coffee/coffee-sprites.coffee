gd = require 'node-gd'
async = require 'async2'
fs = require 'fs'
path = require 'path'
instance = `undefined`
spawn = require('child_process').spawn
log = (i,m) -> l=instance.o.logger; (l.length is 2 and l i,m) or l m; return

class CoffeeSprites
  constructor: (o) ->
    instance = @
    o = o or {}
    o.image_path = o.image_path or ''
    o.sprite_path = o.sprite_path or ''
    o.sprite_url = o.sprite_url or ''
    o.logger = o.logger or console.log
    o.manifest_file = o.manifest_file or path.join o.sprite_path, 'sprite-manifest.json'
    @o = o
    @reset()

  reset: ->
    @sprites = {}
    @_read_manifest = false

  read_manifest: ->
    # read first time only
    # call reset() to permit reading again
    unless @_read_manifest
      @_read_manifest = true
      if fs.existsSync @o.manifest_file
        data = (JSON.parse(fs.readFileSync @o.manifest_file)) or {}
        for name, sprite of data.sprites
          @sprites[name] = new Sprite name, sprite.options
          for i, file of sprite.images
            abspath = path.join @o.image_path, (sprite.options.path or ''), file+'.png'
            if fs.existsSync abspath
              @sprites[name].add file
    return

  write_manifest: ->
    data =
      sprites: {}
    count = 0
    for name of @sprites
      data.sprites[name] =
        options: @sprites[name].o
        images: []
      for file of @sprites[name].images
        data.sprites[name].images.push file
        count++
    if count
      fs.writeFileSync @o.manifest_file, JSON.stringify data, null, 2
      log 'success', "wrote #{path.relative process.cwd(), @o.manifest_file}"
    return

  extend: (engine) -> # CoffeeStylesheets instance
    g=engine.o.globals

    generate_placeholder = (key, name, png) =>
      @read_manifest()
      if typeof png isnt 'undefined'
        @sprites[name].add png
      "SPRITE_#{key}_PLACEHOLDER(#{name}, #{png or ''})"

    # TODO: add validation to ensure these functions are never permitted
    #       to be called with invalid arguments
    g.sprite_map = (name, options) =>
      @read_manifest()
      if @sprites[name]
        # reuse existing instance by same name
        for k of options # merging new options over existing
          @sprites[name].o[k] = options[k]
      else
        # new sprite instance
        sprite = new Sprite name, options
        @sprites[name] = sprite
      return name

    g.sprite = (sprite, png) ->
      generate_placeholder 'URL_AND_IMAGE_POSITION', sprite, png

    g.sprite_url = (sprite, png) ->
      generate_placeholder 'URL', sprite, png

    g.sprite_position = (sprite, png) ->
      generate_placeholder 'POSITION', sprite, png

    g.sprite_width = (sprite, png) ->
      generate_placeholder 'WIDTH', sprite, png

    g.sprite_height = (sprite, png) ->
      generate_placeholder 'HEIGHT', sprite, png

    # coffeestylesheets done compiling
    engine.on.end = (css, cb) =>
      # save final sprites to disk
      flow = new async()
      for name, sprite of @sprites
        ((sprite)-> flow.series -> sprite.render @)(sprite)
      flow.finally (err, changes) =>
        return cb err if err
        # replace placeholders in css
        css = css.replace /SPRITE_(.+?)_PLACEHOLDER\((.+?), (.*?)\)/g, (match, key, name, png) =>
          sprite = @sprites[name]
          image = sprite.images[png]
          switch key
            when 'POSITION'
              return image.coords()
            when 'URL'
              return sprite.digest_url image.tileset()
            when 'URL_AND_IMAGE_POSITION'
              return "url(#{sprite.digest_url image.tileset()}) #{image.coords()}"
            when 'WIDTH'
              return image.px image.w
            when 'HEIGHT'
              return image.px image.h

        @write_manifest()
        instance.reset()

        # return final css
        cb null, css
        return
      return
    return

class Image
  constructor: (@sprite, @file) ->
    @absfile = path.join instance.o.image_path, @file+'.png'
    @src = `undefined`
    @x = 0
    @y = 0
    @w = 0
    @h = 0

  toString: ->
    "Image#file=#{@file},x=#{@x},y=#{@y},width=#{@w},height=#{@h}"

  read: (cb) ->
    gd.openPng @absfile, (err, src) =>
      return cb err if err
      @src = src
      @w = src.width
      @h = src.height
      cb null, @

  basename: ->
    path.basename @absfile, '.png'

  repeat: ->
    switch repeat = @sprite.o[@basename()+'-repeat'] or 'no-repeat'
      when 'no-repeat', 'repeat-x', 'repeat-y'
        # valid
      else
        throw err "WARN: #{repeat} is an invalid repeat value"
    repeat

  tileset: ->
    if (repeat = @repeat()) is 'no-repeat' and @sprite.o.layout is 'smart' then 'smart' else repeat

  px: (i) ->
    if i is 0 then 0 else i + 'px'

  coords: ->
    @px(@x * -1) + ' ' + @px(@y * -1)

sprite_count = 0

class Sprite
  constructor: (name, o) ->
    if typeof name isnt 'string'
      o = name
      name = ''
    @name = name or 'sprite-'+(++sprite_count)
    o = o or {}
    o.layout = o.layout or 'smart'
    @images = {}
    @tilesets = {}
    @tileset_types = ['smart', 'no-repeat', 'repeat-x','repeat-y'] # in order
    @digest = ''
    @o = o
    return

  add: (file) ->
    if typeof @images[file] is 'undefined' # cache
      @images[file] = new Image @, path.join(@o.path or '', file)
      k = @images[file].tileset()
      if typeof @tilesets[k] is 'undefined'
        @tilesets[k] =
          images: []
          digest: ''
          digest_file: ''
          src: `undefined`
          w: 0
          h: 0
      @tilesets[k].images.push @images[file] # group images into tilesets by repeat type
    return @images[file]

  render: (cb) ->
    sprite = @
    count = 0; count++ for k of sprite.images
    return cb null, "sprite map \"#{sprite.name}\" has no images." if count < 1

    # read image w, h dimensions
    read = =>
      flow = async.new()
      for type, tileset of sprite.tilesets
        for k, image of tileset.images
          ((image)-> flow.series -> image.read @)(image)
      flow.finally (err) ->
        return cb err if err
        position_and_pack()

    # calculate x, y positions, and md5 digests
    # grouped by tileset
    position_and_pack = =>
      sprite.o.spacing = sprite.o.spacing or 0
      changes = true
      for type, tileset of sprite.tilesets
        if type is 'smart' # means 2d binary packing algorithm
          for k, image of tileset.images
            image._w = image.w
            image.w += sprite.o.spacing
            image._h = image.h
            image.h += sprite.o.spacing
          sort = # sort tileset images
            w: (a, b) -> b.w - a.w
            h: (a, b) -> b.h - a.h
            max: (a, b) -> Math.max(b.w, b.h) - Math.max(a.w, a.h)
            min: (a, b) -> Math.min(b.w, b.h) - Math.min(a.w, a.h)
            maxside: (a, b) -> # by multiple criteria
              c = ["max", "min", "h", "w"]
              n = 0
              while n < c.length
                diff = sort[c[n]](a, b)
                return diff unless diff is 0
                n++
              0
          tileset.images.sort sort.maxside
          GrowingPacker = require '../vendor/packer.growing.js'
          packer = new GrowingPacker()
          packer.fit tileset.images
          tileset.w = packer.root.w
          tileset.h = packer.root.h
          for k, image of tileset.images when image.fit
            image.x = image.fit.x
            image.y = image.fit.y
            image.w = image._w
            image.h = image._h
        else if type is 'repeat-y'
          for k, image of tileset.images
            tileset.h = Math.max tileset.h, image.h
            image.x = tileset.w
            tileset.w += image.w + sprite.o.spacing
        else if type is 'repeat-x' or type is 'no-repeat'
          for k, image of tileset.images
            tileset.w = Math.max tileset.w, image.w
            image.y = tileset.h
            tileset.h += image.h + sprite.o.spacing
        tileset.digest = sprite.calc_digest type
        changes &= not fs.existsSync tileset.digest_file = sprite.digest_file type

      return cb null, "no changes in sprite(s)." unless changes
      render_to_disk()

    # create up to four new blank sprite canvases
    # one for each tileset
    render_to_disk = ->
      flow = new async
      for k, type of sprite.tileset_types when tileset = sprite.tilesets[type]
        ((type, tileset) -> flow.serial ->
          next = @
          tileset.src = gd.createTrueColor tileset.w, tileset.h
          transparency = tileset.src.colorAllocateAlpha 0, 0, 0, 127
          tileset.src.fill 0, 0, transparency
          tileset.src.colorTransparent transparency
          tileset.src.alphaBlending 0
          tileset.src.saveAlpha 1
          count = 0

          # compile sprite tileset in memory
          for k, image of tileset.images
            count++
            switch type
              when 'no-repeat', 'smart'
                #console.log "#{image.basename()} over #{type} at #{image.x}, #{image.y} dim #{image.w} x #{image.h}"
                image.src.copy tileset.src, image.x, image.y, 0, 0, image.w, image.h
              when 'repeat-x'
                # stretch it across width of image
                #console.log "#{image.basename()} over #{type} at #{x}, #{image.y} dim #{image.w} x #{image.h}"
                for x in [0...tileset.w] by image.w
                  image.src.copy tileset.src, x, image.y, 0, 0, image.w, image.h
              when 'repeat-y'
                #console.log "#{image.basename()} over #{type} at #{image.x}, #{y} dim #{image.w} x #{image.h}"
                # stretch it across height of image
                for y in [0...tileset.h] by image.h
                  image.src.copy tileset.src, image.x, y, 0, 0, image.w, image.h

          # delete old sprites off disk
          pattern = tileset.digest_file.replace /-[\w\d+]+\.png$/, '-*.png'
          files = require('glob').sync pattern
          for file in files
            fs.unlinkSync file

          # override sprite png on disk
          outfile = 
            if instance.o.pngcrush
              tileset.digest_file+'.tmp'
            else
              tileset.digest_file

          outfile = tileset.digest_file+(if instance.o.pngcrush then '.tmp' else '')
          log 'pending', "writing #{count} images to #{path.relative process.cwd(), tileset.digest_file}..."
          tileset.src.savePng outfile, 0, =>
            # optimize png
            if instance.o.pngcrush
              log 'pending', "pngcrush #{path.relative process.cwd(), tileset.digest_file}..."
              p = spawn instance.o.pngcrush, ['-rem', 'alla', '-reduce', '-brute', outfile, tileset.digest_file]
              stdout = ''
              p.stdout.on 'data', (data) ->
                stdout = data
              p.stderr.on 'data', (err) ->
                return next err if err
              p.on 'exit', (code) ->
                fs.unlinkSync outfile if fs.existsSync outfile
                return next "pngcrush exited with code #{code}. #{stdout}" if code isnt 0
                return next null, true
            else
              return next null, true

        )(type, tileset)
      flow.finally (err) ->
        return cb err if err
        cb null
      return

    read()
    return

  calc_digest: (type) ->
    # convert to array
    b = o: [], i: []
    for k of @o
      b.o.push k+':'+@o[k]
    for k, image of @tilesets[type].images
      b.i.push image.basename()
    # sort and concatenate
    b = b.o.sort().join('|')+'|'+b.i.sort().join('|')
    # calculate digest hash
    require('crypto').createHash('md5').update(b).digest('hex').substr(-10)

  suffix: (s) -> { 'smart': '', 'no-repeat': '', 'repeat-x': '-x', 'repeat-y': '-y' }[s]

  digest_file: (type) ->
    path.join instance.o.sprite_path, "#{@name}#{@suffix type}-#{@tilesets[type].digest}.png"

  digest_url: (type) ->
    path.join instance.o.sprite_url, "#{@name}#{@suffix type}-#{@tilesets[type].digest}.png"

module.exports = (options) ->
  new CoffeeSprites options
  (engine) ->
    instance.extend engine
    instance
