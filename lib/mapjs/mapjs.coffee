#window.$ = window.jQuery = require('../../js/jquery-2.0.2')
window.$ = window.jQuery = require('atom-space-pen-views').$
window._ = require('../../js/underscore-1.4.4')
window.Hammer = require '../../js/hammer.min'
require '../../js/jquery.hammer.min'
require '../../js/jquery.hotkeys'
require '../../js/color-0.4.1.min'
require '../../js/jquery.mousewheel-3.1.3'

module.exports =
  MAPJS = window.MAPJS = MAPJS or {}

require './observable'
require './url-helper'
require './content'
require './layout'
require './clipboard'
require './map-model'
require './map-toolbar-widget'
require './link-edit-widget'
require './image-drop-widget'
require './hammer-draggable'
require './dom-map-view'
require './dom-map-widget'
require './init'
