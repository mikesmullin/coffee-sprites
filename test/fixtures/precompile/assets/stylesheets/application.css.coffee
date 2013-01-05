module.exports = stylesheet = ->
  p ->
    font_weight 'bold'
    margin '1em 0'
    clear 'left'
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
    path: 'smb3'
    spacing: 12
  s '#wigi', ->
    background "url(#{sprite_url wigi, 'walk-1'}) no-repeat"
    height sprite_height wigi, 'fly-3'
    width sprite_width wigi, 'fly-3'
  for i, v of 'walk-1 walk-2 walk-3 run-1 run-2 run-3 fly-1 fly-2 fly-3 fall jump'.split ' '
    s '#wigi.smb3.wigi-'+i, ->
      background_position "#{sprite_position wigi, v} !important"
  world = sprite_map 'world',
    path: 'smb'
    spacing: 4
    'cloud-1-x-repeat': 'repeat-x'
    'brick-1-xy-repeat': 'repeat-x'
    'brick-2-xy-repeat': 'repeat-y'
    'brick-3-xy-repeat': 'repeat-y'
  for i, v of 'brick-3-xy bridge-1-x bridge-2-x bridge-3-x bush-1-l bush-1-m-x bush-1-r cloud-1-x lava-1-x mountain-1-l mountain-1-m mountain-1-r shroom-1-l shroom-1-m-x shroom-1-r tree-1-l tree-1-m-x tree-1-r'.split ' '
    s '.smb.world#world-'+i, ->
      background_position sprite_position world, v
  div '.x1', ->
    background "#{sprite world, 'cloud-1-x'} repeat-x"
    height sprite_height world, 'cloud-1-x'
    width '100%'
  div '.y2', ->
    float 'left'
    background "#{sprite world, 'brick-3-xy'} repeat-y"
    width sprite_width world, 'brick-3-xy'
    height '320px'
  div '.xy', ->
    brick = sprite_map 'brick-4-xy', path: 'smb'
    background "#{sprite brick, 'brick-4-xy'} repeat"
    width '320px'
    height '320px'
