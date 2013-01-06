module.exports = stylesheet = ->
  world = sprite_map 'world'
    'brick-1-xy-repeat': 'repeat-x'
    'brick-2-xy-repeat': 'repeat-y'
  div '.x2', ->
    background "#{sprite world, 'brick-1-xy'} repeat-x"
    height sprite_height world, 'brick-1-xy'
    width '100%'
  div '.y1', ->
    float 'left'
    background "#{sprite world, 'brick-2-xy'} repeat-y"
    width sprite_width world, 'brick-2-xy'
    height '320px'
