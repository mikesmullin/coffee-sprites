// Generated by CoffeeScript 1.4.0
var CoffeeSprites, Image, Sprite, async, fs, gd, instance, log, path, spawn, sprite_count;

gd = require('node-gd');

async = require('async2');

fs = require('fs');

path = require('path');

instance = undefined;

spawn = require('child_process').spawn;

log = function(i, m) {
  var l;
  l = instance.o.logger;
  (l.length === 2 && l(i, m)) || l(m);
};

CoffeeSprites = (function() {

  function CoffeeSprites(o) {
    instance = this;
    o = o || {};
    o.image_path = o.image_path || '';
    o.sprite_path = o.sprite_path || '';
    o.sprite_url = o.sprite_url || '';
    o.logger = o.logger || console.log;
    o.manifest_file = o.manifest_file || path.join(o.sprite_path, 'sprite-manifest.json');
    this.o = o;
    this.reset();
  }

  CoffeeSprites.prototype.reset = function() {
    this.sprites = {};
    return this._read_manifest = false;
  };

  CoffeeSprites.prototype.read_manifest = function() {
    var abspath, data, file, i, name, sprite, _ref, _ref1;
    if (!this._read_manifest) {
      this._read_manifest = true;
      if (fs.existsSync(this.o.manifest_file)) {
        data = (JSON.parse(fs.readFileSync(this.o.manifest_file))) || {};
        _ref = data.sprites;
        for (name in _ref) {
          sprite = _ref[name];
          this.sprites[name] = new Sprite(name, sprite.options);
          _ref1 = sprite.images;
          for (i in _ref1) {
            file = _ref1[i];
            abspath = path.join(this.o.image_path, sprite.options.path || '', file + '.png');
            if (fs.existsSync(abspath)) {
              this.sprites[name].add(file);
            }
          }
        }
      }
    }
  };

  CoffeeSprites.prototype.write_manifest = function() {
    var count, data, file, name;
    data = {
      sprites: {}
    };
    count = 0;
    for (name in this.sprites) {
      data.sprites[name] = {
        options: this.sprites[name].o,
        images: []
      };
      for (file in this.sprites[name].images) {
        data.sprites[name].images.push(file);
        count++;
      }
    }
    if (count) {
      fs.writeFileSync(this.o.manifest_file, JSON.stringify(data, null, 2));
      log('success', "wrote " + (path.relative(process.cwd(), this.o.manifest_file)));
    }
  };

  CoffeeSprites.prototype.extend = function(engine) {
    var g, generate_placeholder,
      _this = this;
    g = engine.o.globals;
    generate_placeholder = function(key, name, png) {
      _this.read_manifest();
      if (typeof png !== 'undefined') {
        _this.sprites[name].add(png);
      }
      return "SPRITE_" + key + "_PLACEHOLDER(" + name + ", " + (png || '') + ")";
    };
    g.sprite_map = function(name, options) {
      var k, sprite;
      _this.read_manifest();
      if (_this.sprites[name]) {
        for (k in options) {
          _this.sprites[name].o[k] = options[k];
        }
      } else {
        sprite = new Sprite(name, options);
        _this.sprites[name] = sprite;
      }
      return name;
    };
    g.sprite = function(sprite, png) {
      return generate_placeholder('URL_AND_IMAGE_POSITION', sprite, png);
    };
    g.sprite_url = function(sprite, png) {
      return generate_placeholder('URL', sprite, png);
    };
    g.sprite_position = function(sprite, png) {
      return generate_placeholder('POSITION', sprite, png);
    };
    g.sprite_width = function(sprite, png) {
      return generate_placeholder('WIDTH', sprite, png);
    };
    g.sprite_height = function(sprite, png) {
      return generate_placeholder('HEIGHT', sprite, png);
    };
    engine.on.end = function(css, cb) {
      var flow, name, sprite, _fn, _ref;
      flow = new async();
      _ref = _this.sprites;
      _fn = function(sprite) {
        return flow.series(function() {
          return sprite.render(this);
        });
      };
      for (name in _ref) {
        sprite = _ref[name];
        _fn(sprite);
      }
      flow["finally"](function(err, changes) {
        if (err) {
          return cb(err);
        }
        css = css.replace(/SPRITE_(.+?)_PLACEHOLDER\((.+?), (.*?)\)/g, function(match, key, name, png) {
          var image;
          sprite = _this.sprites[name];
          image = sprite.images[png];
          switch (key) {
            case 'POSITION':
              return image.coords();
            case 'URL':
              return sprite.digest_url(image.tileset());
            case 'URL_AND_IMAGE_POSITION':
              return "url(" + (sprite.digest_url(image.tileset())) + ") " + (image.coords());
            case 'WIDTH':
              return image.px(image.w);
            case 'HEIGHT':
              return image.px(image.h);
          }
        });
        _this.write_manifest();
        instance.reset();
        cb(null, css);
      });
    };
  };

  return CoffeeSprites;

})();

Image = (function() {

  function Image(sprite, file) {
    this.sprite = sprite;
    this.file = file;
    this.absfile = path.join(instance.o.image_path, this.file + '.png');
    this.src = undefined;
    this.x = 0;
    this.y = 0;
    this.w = 0;
    this.h = 0;
  }

  Image.prototype.toString = function() {
    return "Image#file=" + this.file + ",x=" + this.x + ",y=" + this.y + ",width=" + this.w + ",height=" + this.h;
  };

  Image.prototype.read = function(cb) {
    var _this = this;
    return gd.openPng(this.absfile, function(err, src) {
      if (err) {
        return cb(err);
      }
      _this.src = src;
      _this.w = src.width;
      _this.h = src.height;
      return cb(null, _this);
    });
  };

  Image.prototype.basename = function() {
    return path.basename(this.absfile, '.png');
  };

  Image.prototype.repeat = function() {
    var repeat;
    switch (repeat = this.sprite.o[this.basename() + '-repeat'] || 'no-repeat') {
      case 'no-repeat':
      case 'repeat-x':
      case 'repeat-y':
        break;
      default:
        throw err("WARN: " + repeat + " is an invalid repeat value");
    }
    return repeat;
  };

  Image.prototype.tileset = function() {
    var repeat;
    if ((repeat = this.repeat()) === 'no-repeat' && this.sprite.o.layout === 'smart') {
      return 'smart';
    } else {
      return repeat;
    }
  };

  Image.prototype.px = function(i) {
    if (i === 0) {
      return 0;
    } else {
      return i + 'px';
    }
  };

  Image.prototype.coords = function() {
    return this.px(this.x * -1) + ' ' + this.px(this.y * -1);
  };

  return Image;

})();

sprite_count = 0;

Sprite = (function() {

  function Sprite(name, o) {
    if (typeof name !== 'string') {
      o = name;
      name = '';
    }
    this.name = name || 'sprite-' + (++sprite_count);
    o = o || {};
    o.layout = o.layout || 'smart';
    this.images = {};
    this.tilesets = {};
    this.tileset_types = ['smart', 'no-repeat', 'repeat-x', 'repeat-y'];
    this.digest = '';
    this.o = o;
    return;
  }

  Sprite.prototype.add = function(file) {
    var k;
    if (typeof this.images[file] === 'undefined') {
      this.images[file] = new Image(this, path.join(this.o.path || '', file));
      k = this.images[file].tileset();
      if (typeof this.tilesets[k] === 'undefined') {
        this.tilesets[k] = {
          images: [],
          digest: '',
          digest_file: '',
          src: undefined,
          w: 0,
          h: 0
        };
      }
      this.tilesets[k].images.push(this.images[file]);
    }
    return this.images[file];
  };

  Sprite.prototype.render = function(cb) {
    var count, k, position_and_pack, read, render_to_disk, sprite,
      _this = this;
    sprite = this;
    count = 0;
    for (k in sprite.images) {
      count++;
    }
    if (count < 1) {
      return cb(null, "sprite map \"" + sprite.name + "\" has no images.");
    }
    read = function() {
      var flow, image, tileset, type, _fn, _ref, _ref1;
      flow = async["new"]();
      _ref = sprite.tilesets;
      for (type in _ref) {
        tileset = _ref[type];
        _ref1 = tileset.images;
        _fn = function(image) {
          return flow.series(function() {
            return image.read(this);
          });
        };
        for (k in _ref1) {
          image = _ref1[k];
          _fn(image);
        }
      }
      return flow["finally"](function(err) {
        if (err) {
          return cb(err);
        }
        return position_and_pack();
      });
    };
    position_and_pack = function() {
      var GrowingPacker, changes, image, packer, sort, tileset, type, _ref, _ref1, _ref2, _ref3, _ref4;
      sprite.o.spacing = sprite.o.spacing || 0;
      changes = true;
      _ref = sprite.tilesets;
      for (type in _ref) {
        tileset = _ref[type];
        if (type === 'smart') {
          _ref1 = tileset.images;
          for (k in _ref1) {
            image = _ref1[k];
            image._w = image.w;
            image.w += sprite.o.spacing;
            image._h = image.h;
            image.h += sprite.o.spacing;
          }
          sort = {
            w: function(a, b) {
              return b.w - a.w;
            },
            h: function(a, b) {
              return b.h - a.h;
            },
            max: function(a, b) {
              return Math.max(b.w, b.h) - Math.max(a.w, a.h);
            },
            min: function(a, b) {
              return Math.min(b.w, b.h) - Math.min(a.w, a.h);
            },
            maxside: function(a, b) {
              var c, diff, n;
              c = ["max", "min", "h", "w"];
              n = 0;
              while (n < c.length) {
                diff = sort[c[n]](a, b);
                if (diff !== 0) {
                  return diff;
                }
                n++;
              }
              return 0;
            }
          };
          tileset.images.sort(sort.maxside);
          GrowingPacker = require('../vendor/packer.growing.js');
          packer = new GrowingPacker();
          packer.fit(tileset.images);
          tileset.w = packer.root.w;
          tileset.h = packer.root.h;
          _ref2 = tileset.images;
          for (k in _ref2) {
            image = _ref2[k];
            if (!image.fit) {
              continue;
            }
            image.x = image.fit.x;
            image.y = image.fit.y;
            image.w = image._w;
            image.h = image._h;
          }
        } else if (type === 'repeat-y') {
          _ref3 = tileset.images;
          for (k in _ref3) {
            image = _ref3[k];
            tileset.h = Math.max(tileset.h, image.h);
            image.x = tileset.w;
            tileset.w += image.w + sprite.o.spacing;
          }
        } else if (type === 'repeat-x' || type === 'no-repeat') {
          _ref4 = tileset.images;
          for (k in _ref4) {
            image = _ref4[k];
            tileset.w = Math.max(tileset.w, image.w);
            image.y = tileset.h;
            tileset.h += image.h + sprite.o.spacing;
          }
        }
        tileset.digest = sprite.calc_digest(type);
        changes &= !fs.existsSync(tileset.digest_file = sprite.digest_file(type));
      }
      if (!changes) {
        return cb(null, "no changes in sprite(s).");
      }
      return render_to_disk();
    };
    render_to_disk = function() {
      var flow, tileset, type, _ref;
      flow = new async;
      _ref = sprite.tileset_types;
      for (k in _ref) {
        type = _ref[k];
        if (tileset = sprite.tilesets[type]) {
          (function(type, tileset) {
            return flow.serial(function() {
              var file, files, image, next, outfile, pattern, transparency, x, y, _i, _j, _k, _len, _ref1, _ref2, _ref3, _ref4, _ref5,
                _this = this;
              next = this;
              tileset.src = gd.createTrueColor(tileset.w, tileset.h);
              transparency = tileset.src.colorAllocateAlpha(0, 0, 0, 127);
              tileset.src.fill(0, 0, transparency);
              tileset.src.colorTransparent(transparency);
              tileset.src.alphaBlending(0);
              tileset.src.saveAlpha(1);
              count = 0;
              _ref1 = tileset.images;
              for (k in _ref1) {
                image = _ref1[k];
                count++;
                switch (type) {
                  case 'no-repeat':
                  case 'smart':
                    image.src.copy(tileset.src, image.x, image.y, 0, 0, image.w, image.h);
                    break;
                  case 'repeat-x':
                    for (x = _i = 0, _ref2 = tileset.w, _ref3 = image.w; 0 <= _ref2 ? _i < _ref2 : _i > _ref2; x = _i += _ref3) {
                      image.src.copy(tileset.src, x, image.y, 0, 0, image.w, image.h);
                    }
                    break;
                  case 'repeat-y':
                    for (y = _j = 0, _ref4 = tileset.h, _ref5 = image.h; 0 <= _ref4 ? _j < _ref4 : _j > _ref4; y = _j += _ref5) {
                      image.src.copy(tileset.src, image.x, y, 0, 0, image.w, image.h);
                    }
                }
              }
              pattern = tileset.digest_file.replace(/-[\w\d+]+\.png$/, '-*.png');
              files = require('glob').sync(pattern);
              for (_k = 0, _len = files.length; _k < _len; _k++) {
                file = files[_k];
                fs.unlinkSync(file);
              }
              outfile = instance.o.pngcrush ? tileset.digest_file + '.tmp' : tileset.digest_file;
              outfile = tileset.digest_file + (instance.o.pngcrush ? '.tmp' : '');
              log('pending', "writing " + count + " images to " + (path.relative(process.cwd(), tileset.digest_file)) + "...");
              return tileset.src.savePng(outfile, 0, function() {
                var p, stdout;
                if (instance.o.pngcrush) {
                  log('pending', "pngcrush " + (path.relative(process.cwd(), tileset.digest_file)) + "...");
                  p = spawn(instance.o.pngcrush, ['-rem', 'alla', '-reduce', '-brute', outfile, tileset.digest_file]);
                  stdout = '';
                  p.stdout.on('data', function(data) {
                    return stdout = data;
                  });
                  p.stderr.on('data', function(err) {
                    if (err) {
                      return next(err);
                    }
                  });
                  return p.on('exit', function(code) {
                    if (fs.existsSync(outfile)) {
                      fs.unlinkSync(outfile);
                    }
                    if (code !== 0) {
                      return next("pngcrush exited with code " + code + ". " + stdout);
                    }
                    return next(null, true);
                  });
                } else {
                  return next(null, true);
                }
              });
            });
          })(type, tileset);
        }
      }
      flow["finally"](function(err) {
        if (err) {
          return cb(err);
        }
        return cb(null);
      });
    };
    read();
  };

  Sprite.prototype.calc_digest = function(type) {
    var b, image, k, _ref;
    b = {
      o: [],
      i: []
    };
    for (k in this.o) {
      b.o.push(k + ':' + this.o[k]);
    }
    _ref = this.tilesets[type].images;
    for (k in _ref) {
      image = _ref[k];
      b.i.push(image.basename());
    }
    b = b.o.sort().join('|') + '|' + b.i.sort().join('|');
    return require('crypto').createHash('md5').update(b).digest('hex').substr(-10);
  };

  Sprite.prototype.suffix = function(s) {
    return {
      'smart': '',
      'no-repeat': '',
      'repeat-x': '-x',
      'repeat-y': '-y'
    }[s];
  };

  Sprite.prototype.digest_file = function(type) {
    return path.join(instance.o.sprite_path, "" + this.name + (this.suffix(type)) + "-" + this.tilesets[type].digest + ".png");
  };

  Sprite.prototype.digest_url = function(type) {
    return path.join(instance.o.sprite_url, "" + this.name + (this.suffix(type)) + "-" + this.tilesets[type].digest + ".png");
  };

  return Sprite;

})();

module.exports = function(options) {
  new CoffeeSprites(options);
  return function(engine) {
    instance.extend(engine);
    return instance;
  };
};
