$.fn.scrollWhenDragging = (scrollPredicate) ->
  'use strict'
  @each ->
    element = $(this)
    dragOrigin = undefined
    element.on('dragstart', ->
      if scrollPredicate()
        dragOrigin =
          top: element.scrollTop()
          left: element.scrollLeft()
      return
    ).on('drag', (e) ->
      if e.gesture and dragOrigin
        element.scrollTop dragOrigin.top - (e.gesture.deltaY)
        element.scrollLeft dragOrigin.left - (e.gesture.deltaX)
      return
    ).on 'dragend', ->
      dragOrigin = undefined
      return
    return

$.fn.domMapWidget = (activityLog, mapModel, touchEnabled, imageInsertController, dragContainer, resourceTranslator, centerSelectedNodeOnOrientationChange, options) ->
  'use strict'
  hotkeyEventHandlers =
    'return': 'addSiblingIdea'
    'shift+return': 'addSiblingIdeaBefore'
    'del backspace': 'removeSubIdea'
    'tab insert': 'addSubIdea'
    'left': 'selectNodeLeft'
    'up': 'selectNodeUp'
    'right': 'selectNodeRight'
    'shift+right': 'activateNodeRight'
    'shift+left': 'activateNodeLeft'
    'meta+right ctrl+right meta+left ctrl+left': 'flip'
    'shift+up': 'activateNodeUp'
    'shift+down': 'activateNodeDown'
    'down': 'selectNodeDown'
    'space f2': 'editNode'
    'f': 'toggleCollapse'
    'c meta+x ctrl+x': 'cut'
    'p meta+v ctrl+v': 'paste'
    'y meta+c ctrl+c': 'copy'
    'u meta+z ctrl+z': 'undo'
    'shift+tab': 'insertIntermediate'
    'Esc 0 meta+0 ctrl+0': 'resetView'
    'r meta+shift+z ctrl+shift+z meta+y ctrl+y': 'redo'
    'meta+plus ctrl+plus z': 'scaleUp'
    'meta+minus ctrl+minus shift+z': 'scaleDown'
    'meta+up ctrl+up': 'moveUp'
    'meta+down ctrl+down': 'moveDown'
    'ctrl+shift+v meta+shift+v': 'pasteStyle'
    'Esc': 'cancelCurrentAction'
  charEventHandlers =
    '[': 'activateChildren'
    '{': 'activateNodeAndChildren'
    '=': 'activateSiblingNodes'
    '.': 'activateSelectedNode'
    '/': 'toggleCollapse'
    'a': 'openAttachment'
    'i': 'editIcon'
  actOnKeys = true
  self = this
  mapModel.addEventListener 'inputEnabledChanged', (canInput, holdFocus) ->
    actOnKeys = canInput
    if canInput and !holdFocus
      self.focus()
    return
  @each ->
    element = $(this)
    stage = $('<div>').css(position: 'relative').attr('data-mapjs-role', 'stage').appendTo(element).data(
      'offsetX': element.innerWidth() / 2
      'offsetY': element.innerHeight() / 2
      'width': element.innerWidth() - 20
      'height': element.innerHeight() - 20
      'scale': 1).updateStage()
    previousPinchScale = false
    element.css('overflow', 'auto').attr 'tabindex', 1
    if mapModel.isEditingEnabled()
      (dragContainer or element).simpleDraggableContainer()
    if !touchEnabled
      element.scrollWhenDragging mapModel.getInputEnabled
      #no need to do this for touch, this is native
      element.on 'mousedown', (e) ->
        if e.target != element[0]
          element.css 'overflow', 'hidden'
        return
      $('.chemistry').on 'mouseup', ->
        if element.css('overflow') != 'auto'
          element.css 'overflow', 'auto'
        return
      element.imageDropWidget imageInsertController
    else
      element.on('doubletap', (event) ->
        if mapModel.requestContextMenu(event.gesture.center.pageX, event.gesture.center.pageY)
          event.preventDefault()
          event.gesture.preventDefault()
          return false
        return
      ).on('pinch', (event) ->
        if !event or !event.gesture or !event.gesture.scale
          return
        event.preventDefault()
        event.gesture.preventDefault()
        scale = event.gesture.scale
        if previousPinchScale
          scale = scale / previousPinchScale
        if Math.abs(scale - 1) < 0.05
          return
        previousPinchScale = event.gesture.scale
        mapModel.scale 'touch', scale,
          x: event.gesture.center.pageX - stage.data('offsetX')
          y: event.gesture.center.pageY - stage.data('offsetY')
        return
      ).on 'gestureend', ->
        previousPinchScale = false
        return
    MAPJS.DOMRender.viewController mapModel, stage, touchEnabled, imageInsertController, resourceTranslator, options
    _.each hotkeyEventHandlers, (mappedFunction, keysPressed) ->
      element.keydown keysPressed, (event) ->
        if actOnKeys
          event.stopImmediatePropagation()
          event.preventDefault()
          mapModel[mappedFunction] 'keyboard'
        return
      return
    $(window).on 'orientationchange', ->
      if centerSelectedNodeOnOrientationChange
        mapModel.centerOnNode mapModel.getSelectedNodeId()
      else
        mapModel.resetView()
      return
    $('#container').on('keydown', (e) ->
      functions =
        'U+003D': 'scaleUp'
        'U+002D': 'scaleDown'
        61: 'scaleUp'
        173: 'scaleDown'
      mappedFunction = undefined
      if e and !e.altKey and (e.ctrlKey or e.metaKey)
        if e.originalEvent and e.originalEvent.keyIdentifier
          mappedFunction = functions[e.originalEvent.keyIdentifier]
        else if e.key == 'MozPrintableKey'
          mappedFunction = functions[e.which]
        if mappedFunction
          if actOnKeys
            e.preventDefault()
            mapModel[mappedFunction] 'keyboard'
      return
    ).mousewheel (e) ->
      top = element.scrollTop()
      bottom = element.scrollBottom()
      dY = e.originalEvent.deltaY
      if dY > 0
        if e.ctrlKey
          chemist.mapModel.scaleDown()
        else
          element.scrollBottom(bottom + dY)
      else if dY < 0
        if e.ctrlKey
          chemist.mapModel.scaleUp()
        else
          element.scrollTop(top + dY)
      dX = e.originalEvent.deltaX
      right = element.scrollRight()
      left = element.scrollLeft()
      if dX > 0
        element.scrollRight(right + dX)
      else if dX < 0
        element.scrollLeft(left + dX)
      if scroll < 0 and element.scrollLeft() == 0
        e.preventDefault()
      if scroll > 0 and element[0].scrollWidth - element.width() - element.scrollLeft() == 0
        e.preventDefault()
      return
    element.on 'keypress', (evt) ->
      # 1console.log evt.keyCode
      if !actOnKeys
        return
      if /INPUT|TEXTAREA/.test(evt and evt.target and evt.target.tagName)
        return
      unicode = evt.charCode or evt.keyCode
      actualkey = String.fromCharCode(unicode)
      mappedFunction = charEventHandlers[actualkey]
      if mappedFunction
        evt.preventDefault()
        mapModel[mappedFunction] 'keyboard'
      else if Number(actualkey) <= 9 and Number(actualkey) >= 1
        evt.preventDefault()
        mapModel.activateLevel 'keyboard', Number(actualkey) + 1
      return
    return
