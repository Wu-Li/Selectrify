#window.$ = window.jQuery = require('../lib/jquery-2.0.2')
window.$ = window.jQuery = require('atom-space-pen-views').$
window._ = require('../lib/underscore-1.4.4')
window.Hammer = require '../lib/hammer.min'
require '../lib/jquery.hammer.min'
require '../lib/jquery.hotkeys'
require '../lib/color-0.4.1.min'
require '../lib/jquery.mousewheel-3.1.3'

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
