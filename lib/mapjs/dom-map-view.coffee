MAPJS.DOMRender =
  svgPixel: 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"></svg>'
  nodeCacheMark: (idea, levelOverride) ->
    'use strict'
    {
      title: idea.title
      icon: idea.attr and idea.attr.icon and _.pick(idea.attr.icon, 'width', 'height', 'position')
      collapsed: idea.attr and idea.attr.collapsed
      level: idea.level or levelOverride
    }
  dummyTextBox: $('<div>').addClass('mapjs-node').css(
    position: 'absolute'
    visibility: 'hidden')
  dimensionProvider: (idea, level) ->
    textBox = $(document).nodeWithId(idea.id)
    translateToPixel = ->
      MAPJS.DOMRender.svgPixel
    result = undefined
    if textBox and textBox.length > 0
      if _.isEqual(textBox.data('nodeCacheMark'), MAPJS.DOMRender.nodeCacheMark(idea, level))
        return _.pick(textBox.data(), 'width', 'height')
    lines = Math.ceil(idea.title.length / 100)
    result =
      width: Math.min(idea.title.length * 8 + 12,812)
      height: lines * 21 - 7
    result
  layoutCalculator: (contentAggregate) ->
    MAPJS.calculateLayout contentAggregate, MAPJS.DOMRender.dimensionProvider
  fixedLayout: false

MAPJS.createSVG = (tag) ->
  $ document.createElementNS('http://www.w3.org/2000/svg', tag or 'svg')

$.fn.getBox = ->
  domShape = this and @[0]
  if !domShape
    return false
  {
    top: domShape.offsetTop
    left: domShape.offsetLeft
    width: domShape.offsetWidth
    height: domShape.offsetHeight
  }

$.fn.getDataBox = ->
  domShapeData = @data()
  if domShapeData and domShapeData.width and domShapeData.height
    return {
      top: domShapeData.y
      left: domShapeData.x
      width: domShapeData.width
      height: domShapeData.height
    }
  @getBox()

$.fn.animateConnectorToPosition = (animationOptions, tolerance) ->
  element = $(this)
  shapeFrom = element.data('nodeFrom')
  shapeTo = element.data('nodeTo')
  fromBox = shapeFrom and shapeFrom.getDataBox()
  toBox = shapeTo and shapeTo.getDataBox()
  oldBox =
    from: shapeFrom and shapeFrom.getBox()
    to: shapeTo and shapeTo.getBox()
  tolerance = tolerance or 1
  if fromBox and toBox and oldBox and oldBox.from.width == fromBox.width and oldBox.to.width == toBox.width and oldBox.from.height == fromBox.height and oldBox.to.height == toBox.height and Math.abs(oldBox.from.top - (oldBox.to.top) - (fromBox.top - (toBox.top))) < tolerance and Math.abs(oldBox.from.left - (oldBox.to.left) - (fromBox.left - (toBox.left))) < tolerance
    element.animate {
      left: Math.round(Math.min(fromBox.left, toBox.left))
      top: Math.round(Math.min(fromBox.top, toBox.top))
    }, animationOptions
    return true
  false

$.fn.queueFadeOut = (options) ->
  'use strict'
  element = this
  element.fadeOut _.extend({ complete: ->
    if element.is(':focus')
      element.parents('[tabindex]').focus()
    element.remove()
    return
 }, options)

$.fn.queueFadeIn = (options) ->
  element = this
  element.css('opacity', 0).animate { 'opacity': 1 }, _.extend({ complete: ->
    element.css 'opacity', ''
    return
  }, options)

$.fn.updateStage = ->
  'use strict'
  data = @data()
  size =
    'min-width': Math.round(data.width - (data.offsetX))
    'min-height': Math.round(data.height - (data.offsetY))
    'width': Math.round(data.width - (data.offsetX))
    'height': Math.round(data.height - (data.offsetY))
    'transform-origin': 'top left'
    'transform': 'translate3d(' + Math.round(data.offsetX * 0.5) + 'px, ' + Math.round(data.offsetY * 0.5) + 'px, 0)'
    # 'transform': 'translate3d(' + Math.round(data.offsetX) + 'px, ' + Math.round(data.offsetY) + 'px, 0)'
  if data.scale and data.scale != 1
    size.transform = 'scale(' + data.scale + ') translate(' + Math.round(data.offsetX) + 'px, ' + Math.round(data.offsetY) + 'px)'
  @css size
  this

MAPJS.DOMRender.curvedPath = (parent, child) ->

  horizontalConnector = (parentX, parentY, parentWidth, parentHeight, childX, childY, childWidth, childHeight) ->
    childHorizontalOffset = if parentX < childX then 0.1 else 0.9
    parentHorizontalOffset = 1 - childHorizontalOffset
    {
      from:
        x: parentX + parentHorizontalOffset * parentWidth
        y: parentY + 0.5 * parentHeight
      to:
        x: childX + childHorizontalOffset * childWidth
        y: childY + 0.5 * childHeight
      controlPointOffset: 0
    }

  calculateConnector = (parent, child) ->
    tolerance = 10
    childHorizontalOffset = undefined
    childMid = child.top + child.height * 0.5
    parentMid = parent.top + parent.height * 0.5
    if Math.abs(parentMid - childMid) + tolerance < Math.max(child.height, parent.height * 0.75)
      return horizontalConnector(parent.left, parent.top, parent.width, parent.height, child.left, child.top, child.width, child.height)
    childHorizontalOffset = if parent.left < child.left then 0 else 1
    {
      from:
        x: parent.left + 0.5 * parent.width
        y: parent.top + 0.5 * parent.height
      to:
        x: child.left + childHorizontalOffset * child.width
        y: child.top + 0.5 * child.height
      controlPointOffset: 0.75
    }

  position =
    left: Math.min(parent.left, child.left)
    top: Math.min(parent.top, child.top)
  calculatedConnector = undefined
  offset = undefined
  maxOffset = undefined
  position.width = Math.max(parent.left + parent.width, child.left + child.width, position.left + 1) - (position.left)
  position.height = Math.max(parent.top + parent.height, child.top + child.height, position.top + 1) - (position.top)
  calculatedConnector = calculateConnector(parent, child)
  offset = calculatedConnector.controlPointOffset * (calculatedConnector.from.y - (calculatedConnector.to.y))
  maxOffset = Math.min(child.height, parent.height) * 1.5
  offset = Math.max(-maxOffset, Math.min(maxOffset, offset))
  {
    'd': 'M' + Math.round(calculatedConnector.from.x - (position.left)) + ',' + Math.round(calculatedConnector.from.y - (position.top)) + 'Q' + Math.round(calculatedConnector.from.x - (position.left)) + ',' + Math.round(calculatedConnector.to.y - offset - (position.top)) + ' ' + Math.round(calculatedConnector.to.x - (position.left)) + ',' + Math.round(calculatedConnector.to.y - (position.top))
    'position': position
  }

MAPJS.DOMRender.straightPath = (parent, child) ->

  calculateConnector = (parent, child) ->
    parentPoints = [
      {
        x: parent.left + 0.5 * parent.width
        y: parent.top
      }
      {
        x: parent.left + parent.width
        y: parent.top + 0.5 * parent.height
      }
      {
        x: parent.left + 0.5 * parent.width
        y: parent.top + parent.height
      }
      {
        x: parent.left
        y: parent.top + 0.5 * parent.height
      }
    ]
    childPoints = [
      {
        x: child.left + 0.5 * child.width
        y: child.top
      }
      {
        x: child.left + child.width
        y: child.top + 0.5 * child.height
      }
      {
        x: child.left + 0.5 * child.width
        y: child.top + child.height
      }
      {
        x: child.left
        y: child.top + 0.5 * child.height
      }
    ]
    i = undefined
    j = undefined
    min = Infinity
    bestParent = undefined
    bestChild = undefined
    dx = undefined
    dy = undefined
    current = undefined
    i = 0
    while i < parentPoints.length
            j = 0
      while j < childPoints.length
        dx = parentPoints[i].x - (childPoints[j].x)
        dy = parentPoints[i].y - (childPoints[j].y)
        current = dx * dx + dy * dy
        if current < min
          bestParent = i
          bestChild = j
          min = current
        j += 1
      i += 1
    {
      from: parentPoints[bestParent]
      to: childPoints[bestChild]
    }

  position =
    left: Math.min(parent.left, child.left)
    top: Math.min(parent.top, child.top)
  conn = calculateConnector(parent, child)
  position.width = Math.max(parent.left + parent.width, child.left + child.width, position.left + 1) - (position.left)
  position.height = Math.max(parent.top + parent.height, child.top + child.height, position.top + 1) - (position.top)
  {
    'd': 'M' + Math.round(conn.from.x - (position.left)) + ',' + Math.round(conn.from.y - (position.top)) + 'L' + Math.round(conn.to.x - (position.left)) + ',' + Math.round(conn.to.y - (position.top))
    'conn': conn
    'position': position
  }

MAPJS.DOMRender.nodeConnectorPath = MAPJS.DOMRender.curvedPath
MAPJS.DOMRender.linkConnectorPath = MAPJS.DOMRender.straightPath

$.fn.updateConnector = (canUseData) ->
  $.each this, ->
    element = $(this)
    shapeFrom = element.data('nodeFrom')
    shapeTo = element.data('nodeTo')
    connection = undefined
    pathElement = undefined
    fromBox = undefined
    toBox = undefined
    changeCheck = undefined
    if !shapeFrom or !shapeTo or shapeFrom.length == 0 or shapeTo.length == 0
      element.hide()
      return
    if canUseData
      fromBox = shapeFrom.getDataBox()
      toBox = shapeTo.getDataBox()
    else
      fromBox = shapeFrom.getBox()
      toBox = shapeTo.getBox()
    changeCheck =
      from: fromBox
      to: toBox
    if _.isEqual(changeCheck, element.data('changeCheck'))
      return
    element.data 'changeCheck', changeCheck
    connection = MAPJS.DOMRender.nodeConnectorPath(fromBox, toBox)
    pathElement = element.find('path')
    element.css connection.position
    if pathElement.length == 0
      pathElement = MAPJS.createSVG('path').attr('class', 'mapjs-connector').appendTo(element)
    pathElement.attr 'd', connection.d
    return

$.fn.updateLink = ->
  $.each this, ->
    element = $(this)
    shapeFrom = element.data('nodeFrom')
    shapeTo = element.data('nodeTo')
    connection = undefined
    pathElement = element.find('path.mapjs-link')
    hitElement = element.find('path.mapjs-link-hit')
    arrowElement = element.find('path.mapjs-arrow')
    n = Math.tan(Math.PI / 9)
    dashes =
      dashed: '8, 8'
      solid: ''
    attrs = _.pick(element.data(), 'lineStyle', 'arrow', 'color')
    fromBox = undefined
    toBox = undefined
    changeCheck = undefined
    a1x = undefined
    a1y = undefined
    a2x = undefined
    a2y = undefined
    len = undefined
    iy = undefined
    m = undefined
    dx = undefined
    dy = undefined
    if !shapeFrom or !shapeTo or shapeFrom.length == 0 or shapeTo.length == 0
      element.hide()
      return
    fromBox = shapeFrom.getBox()
    toBox = shapeTo.getBox()
    changeCheck =
      from: fromBox
      to: toBox
      attrs: attrs
    if _.isEqual(changeCheck, element.data('changeCheck'))
      return
    element.data 'changeCheck', changeCheck
    connection = MAPJS.DOMRender.linkConnectorPath(fromBox, toBox)
    element.css connection.position
    if pathElement.length == 0
      pathElement = MAPJS.createSVG('path').attr('class', 'mapjs-link').appendTo(element)
    pathElement.attr(
      'd': connection.d
      'stroke-dasharray': dashes[attrs.lineStyle]).css 'stroke', attrs.color
    if hitElement.length == 0
      hitElement = MAPJS.createSVG('path').attr('class', 'mapjs-link-hit').appendTo(element)
    hitElement.attr 'd': connection.d
    if attrs.arrow
      if arrowElement.length == 0
        arrowElement = MAPJS.createSVG('path').attr('class', 'mapjs-arrow').appendTo(element)
      len = 14
      dx = connection.conn.to.x - (connection.conn.from.x)
      dy = connection.conn.to.y - (connection.conn.from.y)
      if dx == 0
        iy = if dy < 0 then -1 else 1
        a1x = connection.conn.to.x + len * Math.sin(n) * iy
        a2x = connection.conn.to.x - (len * Math.sin(n) * iy)
        a1y = connection.conn.to.y - (len * Math.cos(n) * iy)
        a2y = connection.conn.to.y - (len * Math.cos(n) * iy)
      else
        m = dy / dx
        if connection.conn.from.x < connection.conn.to.x
          len = -len
        a1x = connection.conn.to.x + (1 - (m * n)) * len / Math.sqrt((1 + m * m) * (1 + n * n))
        a1y = connection.conn.to.y + (m + n) * len / Math.sqrt((1 + m * m) * (1 + n * n))
        a2x = connection.conn.to.x + (1 + m * n) * len / Math.sqrt((1 + m * m) * (1 + n * n))
        a2y = connection.conn.to.y + (m - n) * len / Math.sqrt((1 + m * m) * (1 + n * n))
      arrowElement.attr('d', 'M' + Math.round(a1x - (connection.position.left)) + ',' + Math.round(a1y - (connection.position.top)) + 'L' + Math.round(connection.conn.to.x - (connection.position.left)) + ',' + Math.round(connection.conn.to.y - (connection.position.top)) + 'L' + Math.round(a2x - (connection.position.left)) + ',' + Math.round(a2y - (connection.position.top)) + 'Z').css('fill', attrs.color).show()
    else
      arrowElement.hide()
    return

$.fn.addNodeCacheMark = (idea) ->
  @data 'nodeCacheMark', MAPJS.DOMRender.nodeCacheMark(idea)
  return

$.fn.updateNodeContent = (nodeContent, resourceTranslator) ->
  MAX_URL_LENGTH = 25
  self = $(this)

  textSpan = ->
    span = self.find('[data-mapjs-role=title]')
    if span.length == 0
      span = $('<span>').attr('data-mapjs-role', 'title').attr('nodeId',nodeContent.id).appendTo(self)
    span

  applyLinkUrl = (title) ->
    url = MAPJS.URLHelper.getLink(title)
    element = self.find('a.mapjs-hyperlink')
    if !url
      element.hide()
      return
    if element.length == 0
      element = $('<a target="_blank" class="mapjs-hyperlink"></a>').appendTo(self)
    element.attr('href', url).show()
    return

  applyLabel = (label) ->
    element = self.find('.mapjs-label')
    if !label and label != 0
      element.hide()
      return
    if element.length == 0
      element = $('<span class="mapjs-label"></span>').appendTo(self)
    element.text(label).show()
    return

  applyAttachment = ->
    attachment = nodeContent.attr and nodeContent.attr.attachment
    element = self.find('a.mapjs-attachment')
    if !attachment
      element.hide()
      return
    if element.length == 0
      element = $('<a href="#" class="mapjs-attachment"></a>').appendTo(self).click(->
        self.trigger 'attachment-click'
        return
      )
    element.show()
    return

  updateText = (title) ->
    text = MAPJS.URLHelper.stripLink(title) or (if title.length < MAX_URL_LENGTH then title else title.substring(0, MAX_URL_LENGTH) + '...')
    nodeTextPadding = MAPJS.DOMRender.nodeTextPadding or 11
    element = textSpan()
    domElement = element[0]
    height = undefined
    element.text text.trim()
    self.data 'title', title
    # element.css
    #   'max-width': ''
    #   'min-width': ''
    # if domElement.scrollWidth - nodeTextPadding > domElement.offsetWidth
    #   element.css 'max-width', domElement.scrollWidth + 'px'
    # else
    #   height = domElement.offsetHeight
    #   element.css 'min-width', element.css('max-width')
    #   if domElement.offsetHeight == height
    #     element.css 'min-width', ''
    return

  setCollapseClass = ->
    if nodeContent.attr and nodeContent.attr.collapsed
      self.addClass 'collapsed'
    else
      self.removeClass 'collapsed'
    return

  foregroundClass = (backgroundColor) ->
    luminosity = Color(backgroundColor).mix(Color('#EEEEEE')).luminosity()
    if luminosity < 0.5
      return 'mapjs-node-dark'
    else if luminosity < 0.9
      return 'mapjs-node-light'
    'mapjs-node-white'

  setColors = ->
    fromStyle = nodeContent.style and nodeContent.style.background
    if fromStyle == 'false' or fromStyle == 'transparent'
      fromStyle = false
    self.removeClass 'mapjs-node-dark mapjs-node-white mapjs-node-light'
    if fromStyle
      self.css 'background-color', fromStyle
      self.addClass foregroundClass(fromStyle)
    else
      self.css 'background-color', ''
    return

  setClasses = () ->
    classes = []
    classes = nodeContent.attr and nodeContent.attr.classes
    if nodeContent.title in ['undefined','null']
      classes = classes.concat ['constant','language']
    if classes and classes.length > 0
      for c in classes
        self.addClass c
    return

  setIcon = (icon) ->
    textBox = textSpan()
    textHeight = undefined
    textWidth = undefined
    maxTextWidth = undefined
    padding = undefined
    selfProps =
      'min-height': ''
      'min-width': ''
      'background-image': ''
      'background-repeat': ''
      'background-size': ''
      'background-position': ''
    textProps =
      'margin-top': ''
      'margin-left': ''
    self.css padding: ''
    if icon
      padding = parseInt(self.css('padding-left'), 10)
      textHeight = textBox.outerHeight()
      textWidth = textBox.outerWidth()
      maxTextWidth = parseInt(textBox.css('max-width'), 10)
      _.extend selfProps,
        'background-image': 'url("' + (if resourceTranslator then resourceTranslator(icon.url) else icon.url) + '")'
        'background-repeat': 'no-repeat'
        'background-size': icon.width + 'px ' + icon.height + 'px'
        'background-position': 'center center'
      if icon.position == 'top' or icon.position == 'bottom'
        if icon.position == 'top'
          selfProps['background-position'] = 'center ' + padding + 'px'
        else if MAPJS.DOMRender.fixedLayout
          selfProps['background-position'] = 'center ' + padding + textHeight + 'px'
        else
          selfProps['background-position'] = 'center ' + icon.position + ' ' + padding + 'px'
        selfProps['padding-' + icon.position] = icon.height + padding * 2
        selfProps['min-width'] = icon.width
        if icon.width > maxTextWidth
          textProps['margin-left'] = (icon.width - maxTextWidth) / 2
      else if icon.position == 'left' or icon.position == 'right'
        if icon.position == 'left'
          selfProps['background-position'] = padding + 'px center'
        else if MAPJS.DOMRender.fixedLayout
          selfProps['background-position'] = textWidth + 2 * padding + 'px center '
        else
          selfProps['background-position'] = icon.position + ' ' + padding + 'px center'
        selfProps['padding-' + icon.position] = icon.width + padding * 2
        if icon.height > textHeight
          textProps['margin-top'] = (icon.height - textHeight) / 2
          selfProps['min-height'] = icon.height
      else
        if icon.height > textHeight
          textProps['margin-top'] = (icon.height - textHeight) / 2
          selfProps['min-height'] = icon.height
        selfProps['min-width'] = icon.width
        if icon.width > maxTextWidth
          textProps['margin-left'] = (icon.width - maxTextWidth) / 2
    self.css selfProps
    textBox.css textProps
    return

  self.attr nodeContent.attr or {}
  self.attr 'mapjs-level', nodeContent.level
  updateText nodeContent.title
  # applyLinkUrl nodeContent.title
  # applyLabel nodeContent.label
  # applyAttachment()
  self.data(
    'x': Math.round(nodeContent.x)
    'y': Math.round(nodeContent.y)
    'width': Math.round(nodeContent.width)
    'height': Math.round(nodeContent.height)
    'nodeId': nodeContent.id).addNodeCacheMark nodeContent
  # setColors()
  # setIcon nodeContent.attr and nodeContent.attr.icon
  setClasses()
  setCollapseClass()
  self

$.fn.placeCaretAtEnd = ->
  'use strict'
  el = @[0]
  range = undefined
  sel = undefined
  textRange = undefined
  if window.getSelection and document.createRange
    range = document.createRange()
    range.selectNodeContents el
    range.collapse false
    sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange range
  else if document.body.createTextRange
    textRange = document.body.createTextRange()
    textRange.moveToElementText el
    textRange.collapse false
    textRange.select()
  return

$.fn.selectAll = ->
  'use strict'
  el = @[0]
  range = undefined
  sel = undefined
  textRange = undefined
  if window.getSelection and document.createRange
    range = document.createRange()
    range.selectNodeContents el
    sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange range
  else if document.body.createTextRange
    textRange = document.body.createTextRange()
    textRange.moveToElementText el
    textRange.select()
  return

$.fn.innerText = ->
  'use strict'
  htmlContent = @html()
  containsBr = /<br\/?>/.test(htmlContent)
  containsDiv = /<div>/.test(htmlContent)
  if containsDiv and @[0].innerText
    return @[0].innerText.trim()
  else if containsBr
    return htmlContent.replace(/<br\/?>/gi, '\n').replace(/(<([^>]+)>)/gi, '')
  @text()

$.fn.editNode = (shouldSelectAll) ->
  'use strict'
  node = this
  textBox = @find('[data-mapjs-role=title]')
  unformattedText = @data('title')
  originalText = textBox.text()
  result = $.Deferred()

  clear = ->
    detachListeners()
    textBox.css 'word-break', ''
    textBox.removeAttr 'contenteditable'
    node.shadowDraggable()
    return

  finishEditing = ->
    content = textBox.innerText()
    if content == unformattedText
      return cancelEditing()
    clear()
    result.resolve content
    return

  cancelEditing = ->
    clear()
    textBox.text originalText
    result.reject()
    return

  keyboardEvents = (e) ->
    ENTER_KEY_CODE = 13
    ESC_KEY_CODE = 27
    TAB_KEY_CODE = 9
    S_KEY_CODE = 83
    Z_KEY_CODE = 90
    LEFT_KEY_CODE = 37
    RIGHT_KEY_CODE = 39
    UP_KEY_CODE = 38
    DOWN_KEY_CODE = 40
    BACKSPACE_KEY_CODE = 8
    DELETE_KEY_CODE = 46
    if e.shiftKey and e.which == ENTER_KEY_CODE
      return
    else if e.which == ENTER_KEY_CODE
      finishEditing()
      e.stopPropagation()
    else if e.which == ESC_KEY_CODE
      cancelEditing()
      e.stopPropagation()
    else if e.which == TAB_KEY_CODE or e.which == S_KEY_CODE and (e.metaKey or e.ctrlKey) and !e.altKey
      finishEditing()
      e.preventDefault()
    else if !e.shiftKey and e.which == Z_KEY_CODE and (e.metaKey or e.ctrlKey) and !e.altKey
      if textBox.text() == unformattedText
        cancelEditing()
      e.stopPropagation()
    else if e.which == LEFT_KEY_CODE
      alter = if e.shiftKey then 'extend' else 'move'
      granularity = if e.metaKey or e.ctrlKey then 'word' else 'character'
      window.getSelection().modify(alter,"left",granularity)
    else if e.which == RIGHT_KEY_CODE
      alter = if e.shiftKey then 'extend' else 'move'
      granularity = if e.metaKey or e.ctrlKey then 'word' else 'character'
      window.getSelection().modify(alter,"right",granularity)
    else if e.which == UP_KEY_CODE
      alter = if e.shiftKey then 'extend' else 'move'
      window.getSelection().modify(alter,"left","line")
    else if e.which == DOWN_KEY_CODE
      alter = if e.shiftKey then 'extend' else 'move'
      window.getSelection().modify(alter,"right","line")
    else if e.which == BACKSPACE_KEY_CODE
      selection = window.getSelection()
      if selection.isCollapsed
        selection.modify("extend","left","character")
      selection.deleteFromDocument()
    else if e.which == DELETE_KEY_CODE
      selection = window.getSelection()
      if selection.isCollapsed
        selection.modify("extend","right","character")
      selection.deleteFromDocument()
    return

  attachListeners = ->
    textBox.on('blur', finishEditing).on 'keydown', keyboardEvents
    return

  detachListeners = ->
    textBox.off('blur', finishEditing).off 'keydown', keyboardEvents
    return

  attachListeners()
  if unformattedText != originalText
    textBox.css 'word-break', 'break-all'
  textBox.text(unformattedText).attr('contenteditable', true).focus()
  if shouldSelectAll
    textBox.selectAll()
  else if unformattedText
    textBox.placeCaretAtEnd()
  node.shadowDraggable disable: true
  result.promise()

$.fn.updateReorderBounds = (border, box) ->
  'use strict'
  element = this
  if !border
    element.hide()
    return
  element.show()
  element.attr 'mapjs-edge', border.edge
  element.css
    top: box.y + box.height / 2 - (element.height() / 2)
    left: border.x - (if border.edge == 'left' then element.width() else 0)
  return

do ->
  'use strict'

  cleanDOMId = (s) ->
    s.replace /[^A-Za-z0-9_-]/g, '_'

  connectorKey = (connectorObj) ->
    cleanDOMId 'connector_' + connectorObj.from + '_' + connectorObj.to

  linkKey = (linkObj) ->
    cleanDOMId 'link_' + linkObj.ideaIdFrom + '_' + linkObj.ideaIdTo

  nodeKey = (id) ->
    cleanDOMId 'node_' + id

  $.fn.createNode = (node) ->
    $('<div>').attr(
      'id': nodeKey(node.id)
      'tabindex': 0
      'data-mapjs-role': 'node').css(
      display: 'block'
      position: 'absolute').addClass('mapjs-node').appendTo this

  $.fn.createConnector = (connector) ->
    MAPJS.createSVG().attr(
      'id': connectorKey(connector)
      'data-mapjs-role': 'connector'
      'class': 'mapjs-draw-container').data(
      'nodeFrom': @nodeWithId(connector.from)
      'nodeTo': @nodeWithId(connector.to)).appendTo this

  $.fn.createLink = (l) ->
    defaults = _.extend({
      color: 'red'
      lineStyle: 'dashed'
    }, l.style)
    MAPJS.createSVG().attr(
      'id': linkKey(l)
      'data-mapjs-role': 'link'
      'class': 'mapjs-draw-container').data(
      'nodeFrom': @nodeWithId(l.ideaIdFrom)
      'nodeTo': @nodeWithId(l.ideaIdTo)).data(defaults).appendTo this

  $.fn.nodeWithId = (id) ->
    @find '#' + nodeKey(id)

  $.fn.findConnector = (connectorObj) ->
    @find '#' + connectorKey(connectorObj)

  $.fn.findLink = (linkObj) ->
    @find '#' + linkKey(linkObj)

  $.fn.createReorderBounds = ->
    result = $('<div>').attr(
      'data-mapjs-role': 'reorder-bounds'
      'class': 'mapjs-reorder-bounds').hide().css('position', 'absolute').appendTo(this)
    result

  return

MAPJS.DOMRender.viewController = (mapModel, stageElement, touchEnabled, imageInsertController, resourceTranslator, options) ->
  'use strict'
  viewPort = stageElement.parent()
  connectorsForAnimation = $()
  linksForAnimation = $()
  nodeAnimOptions =
    duration: 400
    queue: 'nodeQueue'
    easing: 'linear'
  reorderBounds = if mapModel.isEditingEnabled() then stageElement.createReorderBounds() else $('<div>')

  getViewPortDimensions = ->
    if viewPortDimensions
      return viewPortDimensions
    viewPortDimensions =
      left: viewPort.scrollLeft()
      top: viewPort.scrollTop()
      innerWidth: viewPort.innerWidth()
      innerHeight: viewPort.innerHeight()
    viewPortDimensions

  stageToViewCoordinates = (x, y) ->
    stage = stageElement.data()
    scrollPosition = getViewPortDimensions()
    {
      x: stage.scale * (x + stage.offsetX) - (scrollPosition.left)
      y: stage.scale * (y + stage.offsetY) - (scrollPosition.top)
    }

  viewToStageCoordinates = (x, y) ->
    stage = stageElement.data()
    scrollPosition = getViewPortDimensions()
    {
      x: (scrollPosition.left + x) / stage.scale - (stage.offsetX)
      y: (scrollPosition.top + y) / stage.scale - (stage.offsetY)
    }

  updateScreenCoordinates = ->
    element = $(this)
    element.css(
      'left': element.data('x')
      'top': element.data('y')).trigger 'mapjs-move'
    return

  animateToPositionCoordinates = ->
    element = $(this)
    element.clearQueue(nodeAnimOptions.queue).animate({
      'left': element.data('x')
      'top': element.data('y')
      'opacity': 1
    }, _.extend({ complete: ->
      element.css 'opacity', ''
      element.each updateScreenCoordinates
      return
    }, nodeAnimOptions)).trigger 'mapjs-animatemove'
    return

  ensureSpaceForPoint = (x, y) ->
    stage = stageElement.data()
    dirty = false
    if x < -1 * stage.offsetX
      stage.width = stage.width - (stage.offsetX) - x
      stage.offsetX = -1 * x
      dirty = true
    if y < -1 * stage.offsetY
      stage.height = stage.height - (stage.offsetY) - y
      stage.offsetY = -1 * y
      dirty = true
    if x > stage.width - (stage.offsetX)
      stage.width = stage.offsetX + x
      dirty = true
    if y > stage.height - (stage.offsetY)
      stage.height = stage.offsetY + y
      dirty = true
    if dirty
      stageElement.updateStage()
    return

  ensureSpaceForNode = ->
    $(this).each ->
      node = $(this).data()
      margin = MAPJS.DOMRender.stageMargin or
        top: 150
        left: 150
        bottom: 150
        right: 150
      ensureSpaceForPoint node.x - (margin.left), node.y - (margin.top)
      ensureSpaceForPoint node.x + node.width + margin.right, node.y + node.height + margin.bottom
      return

  centerViewOn = (x, y, animate) ->
    stage = stageElement.data()
    viewPortCenter =
      x: viewPort.innerWidth() / 2
      y: viewPort.innerHeight() / 2
    newLeftScroll = undefined
    newTopScroll = undefined
    margin = MAPJS.DOMRender.stageVisibilityMargin or
      top: 0
      left: 0
      bottom: 0
      right: 0
    ensureSpaceForPoint x - (viewPortCenter.x / stage.scale), y - (viewPortCenter.y / stage.scale)
    ensureSpaceForPoint x + viewPortCenter.x / stage.scale - (margin.left), y + viewPortCenter.y / stage.scale - (margin.top)
    newLeftScroll = stage.scale * (x + stage.offsetX) - (viewPortCenter.x)
    newTopScroll = stage.scale * (y + stage.offsetY) - (viewPortCenter.y)
    viewPort.finish()
    if animate
      viewPort.animate {
        scrollLeft: newLeftScroll
        scrollTop: newTopScroll
      }, duration: 400
    else
      viewPort.scrollLeft newLeftScroll
      viewPort.scrollTop newTopScroll
    return

  stagePointAtViewportCenter = ->
    viewToStageCoordinates viewPort.innerWidth() / 2, viewPort.innerHeight() / 2

  ensureNodeVisible = (domElement) ->
    return #CHEM
    if !domElement or domElement.length == 0
      return
    viewPort.finish()
    node = domElement.data()
    nodeTopLeft = stageToViewCoordinates(node.x, node.y)
    nodeBottomRight = stageToViewCoordinates(node.x + node.width, node.y + node.height)
    animation = {}
    margin = MAPJS.DOMRender.stageVisibilityMargin or
      top: 10
      left: 10
      bottom: 10
      right: 10
    if nodeTopLeft.x - (margin.left) < 0
      animation.scrollLeft = viewPort.scrollLeft() + nodeTopLeft.x - (margin.left)
    else if nodeBottomRight.x + margin.right > viewPort.innerWidth()
      animation.scrollLeft = viewPort.scrollLeft() + nodeBottomRight.x - viewPort.innerWidth() + margin.right
    if nodeTopLeft.y - (margin.top) < 0
      animation.scrollTop = viewPort.scrollTop() + nodeTopLeft.y - (margin.top)
    else if nodeBottomRight.y + margin.bottom > viewPort.innerHeight()
      animation.scrollTop = viewPort.scrollTop() + nodeBottomRight.y - viewPort.innerHeight() + margin.bottom
    if !_.isEmpty(animation)
      viewPort.animate animation, duration: 100
    return

  viewportCoordinatesForPointEvent = (evt) ->
    dropPosition = evt and evt.gesture and evt.gesture.center or evt
    vpOffset = viewPort.offset()
    result = undefined
    if dropPosition
      result =
        x: dropPosition.pageX - (vpOffset.left)
        y: dropPosition.pageY - (vpOffset.top)
      if result.x >= 0 and result.x <= viewPort.innerWidth() and result.y >= 0 and result.y <= viewPort.innerHeight()
        return result
    return

  stagePositionForPointEvent = (evt) ->
    viewportDropCoordinates = viewportCoordinatesForPointEvent(evt)
    if viewportDropCoordinates
      return viewToStageCoordinates(viewportDropCoordinates.x, viewportDropCoordinates.y)
    return

  clearCurrentDroppable = ->
    if currentDroppable or currentDroppable == false
      $('.mapjs-node').removeClass 'droppable'
      currentDroppable = undefined
    return

  showDroppable = (nodeId) ->
    stageElement.nodeWithId(nodeId).addClass 'droppable'
    currentDroppable = nodeId
    return

  currentDroppable = false
  viewPortDimensions = undefined

  withinReorderBoundary = (boundaries, box) ->
    if _.isEmpty(boundaries)
      return false
    if !box
      return false

    closeTo = (reorderBoundary) ->
      nodeX = box.x
      if reorderBoundary.edge == 'right'
        nodeX += box.width
      Math.abs(nodeX - (reorderBoundary.x)) < reorderBoundary.margin * 2 and box.y < reorderBoundary.maxY and box.y > reorderBoundary.minY

    _.find boundaries, closeTo

  viewPort.on 'scroll', ->
    viewPortDimensions = undefined
    return
  if imageInsertController
    imageInsertController.addEventListener 'imageInserted', (dataUrl, imgWidth, imgHeight, evt) ->
      point = stagePositionForPointEvent(evt)
      mapModel.dropImage dataUrl, imgWidth, imgHeight, point and point.x, point and point.y
      return
  mapModel.addEventListener 'nodeCreated', (node) ->
    currentReorderBoundary = undefined
    element = stageElement.createNode(node).queueFadeIn(nodeAnimOptions).updateNodeContent(node, resourceTranslator).on('tap', (evt) ->
      realEvent = evt.gesture and evt.gesture.srcEvent or evt
      if realEvent.button and realEvent.button != -1
        return
      mapModel.clickNode node.id, realEvent
      if evt
        evt.stopPropagation()
      if evt and evt.gesture
        evt.gesture.stopPropagation()
      return
    ).on('doubletap', (event) ->
      if event
        event.stopPropagation()
        if event.gesture
          event.gesture.stopPropagation()
      if !mapModel.isEditingEnabled()
        mapModel.toggleCollapse 'mouse'
        return
      mapModel.editNode 'mouse'
      return
    ).on('attachment-click', ->
      mapModel.openAttachment 'mouse', node.id
      return
    ).each(ensureSpaceForNode).each(updateScreenCoordinates).on('mm-start-dragging mm-start-dragging-shadow', ->
      mapModel.selectNode node.id
      currentReorderBoundary = mapModel.getReorderBoundary(node.id)
      element.addClass 'dragging'
      return
    ).on('mm-drag', (evt) ->
      dropCoords = stagePositionForPointEvent(evt)
      currentPosition = evt.currentPosition and stagePositionForPointEvent(
        pageX: evt.currentPosition.left
        pageY: evt.currentPosition.top)
      nodeId = undefined
      hasShift = evt and evt.gesture and evt.gesture.srcEvent and evt.gesture.srcEvent.shiftKey
      border = undefined
      if !dropCoords
        clearCurrentDroppable()
        return
      nodeId = mapModel.getNodeIdAtPosition(dropCoords.x, dropCoords.y)
      if !hasShift and !nodeId and currentPosition
        currentPosition.width = element.outerWidth()
        currentPosition.height = element.outerHeight()
        border = withinReorderBoundary(currentReorderBoundary, currentPosition)
        reorderBounds.updateReorderBounds border, currentPosition
      else
        reorderBounds.hide()
      if !nodeId or nodeId == node.id
        clearCurrentDroppable()
      else if nodeId != currentDroppable
        clearCurrentDroppable()
        if nodeId
          showDroppable nodeId
      return
    ).on('contextmenu', (event) ->
      mapModel.selectNode node.id
      if mapModel.requestContextMenu(event.pageX, event.pageY)
        event.preventDefault()
        return false
      return
    ).on('mm-stop-dragging', (evt) ->
      element.removeClass 'dragging'
      reorderBounds.hide()
      isShift = evt and evt.gesture and evt.gesture.srcEvent and evt.gesture.srcEvent.shiftKey
      stageDropCoordinates = stagePositionForPointEvent(evt)
      nodeAtDrop = undefined
      finalPosition = undefined
      dropResult = undefined
      manualPosition = undefined
      vpCenter = undefined
      clearCurrentDroppable()
      if !stageDropCoordinates
        return
      nodeAtDrop = mapModel.getNodeIdAtPosition(stageDropCoordinates.x, stageDropCoordinates.y)
      finalPosition = stagePositionForPointEvent(
        pageX: evt.finalPosition.left
        pageY: evt.finalPosition.top)
      if nodeAtDrop and nodeAtDrop != node.id
        dropResult = mapModel.dropNode(node.id, nodeAtDrop, ! !isShift)
      else if node.level > 1
        finalPosition.width = element.outerWidth()
        finalPosition.height = element.outerHeight()
        manualPosition = ! !isShift or !withinReorderBoundary(currentReorderBoundary, finalPosition)
        dropResult = mapModel.positionNodeAt(node.id, finalPosition.x, finalPosition.y, manualPosition)
      else if node.level == 1 and evt.gesture
        vpCenter = stagePointAtViewportCenter()
        vpCenter.x -= evt.gesture.deltaX or 0
        vpCenter.y -= evt.gesture.deltaY or 0
        centerViewOn vpCenter.x, vpCenter.y, true
        dropResult = true
      else
        dropResult = false
      dropResult
    ).on('mm-cancel-dragging', ->
      clearCurrentDroppable()
      element.removeClass 'dragging'
      reorderBounds.hide()
      return
    )
    if touchEnabled
      element.on 'hold', (evt) ->
        realEvent = evt.gesture and evt.gesture.srcEvent or evt
        mapModel.clickNode node.id, realEvent
        if mapModel.requestContextMenu(evt.gesture.center.pageX, evt.gesture.center.pageY)
          evt.preventDefault()
          if evt.gesture
            evt.gesture.preventDefault()
            evt.gesture.stopPropagation()
          return false
        return
    #CHEM element.css 'min-width', element.css('width')
    if mapModel.isEditingEnabled()
      element.shadowDraggable()
    return
  mapModel.addEventListener 'nodeSelectionChanged', (ideaId, isSelected) ->
    node = stageElement.nodeWithId(ideaId)
    if isSelected
      node.addClass 'selected'
      ensureNodeVisible node
    else
      node.removeClass 'selected'
    return
  mapModel.addEventListener 'nodeRemoved', (node) ->
    stageElement.nodeWithId(node.id).queueFadeOut nodeAnimOptions
    return
  mapModel.addEventListener 'nodeMoved', (node) ->
    currentViewPortDimensions = getViewPortDimensions()
    nodeDom = stageElement.nodeWithId(node.id).data(
      'x': Math.round(node.x)
      'y': Math.round(node.y)).each(ensureSpaceForNode)
    screenTopLeft = stageToViewCoordinates(Math.round(node.x), Math.round(node.y))
    screenBottomRight = stageToViewCoordinates(Math.round(node.x + node.width), Math.round(node.y + node.height))
    if screenBottomRight.x < 0 or screenBottomRight.y < 0 or screenTopLeft.x > currentViewPortDimensions.innerWidth or screenTopLeft.y > currentViewPortDimensions.innerHeight
      nodeDom.each updateScreenCoordinates
    else
      nodeDom.each animateToPositionCoordinates
    return
  mapModel.addEventListener 'nodeTitleChanged nodeAttrChanged nodeLabelChanged', (n) ->
    stageElement.nodeWithId(n.id).updateNodeContent n, resourceTranslator
    return
  mapModel.addEventListener 'connectorCreated', (connector) ->
    element = stageElement.createConnector(connector).queueFadeIn(nodeAnimOptions).updateConnector(true)
    stageElement.nodeWithId(connector.from).add(stageElement.nodeWithId(connector.to)).on('mapjs-move', ->
      element.updateConnector true
      return
    ).on('mm-drag', ->
      element.updateConnector()
      return
    ).on 'mapjs-animatemove', ->
      connectorsForAnimation = connectorsForAnimation.add(element)
      return
    return
  mapModel.addEventListener 'connectorRemoved', (connector) ->
    stageElement.findConnector(connector).queueFadeOut nodeAnimOptions
    return
  mapModel.addEventListener 'linkCreated', (l) ->
    link = stageElement.createLink(l).queueFadeIn(nodeAnimOptions).updateLink()
    link.find('.mapjs-link-hit').on 'tap', (event) ->
      mapModel.selectLink 'mouse', l,
        x: event.gesture.center.pageX
        y: event.gesture.center.pageY
      event.stopPropagation()
      event.gesture.stopPropagation()
      return
    stageElement.nodeWithId(l.ideaIdFrom).add(stageElement.nodeWithId(l.ideaIdTo)).on('mapjs-move mm-drag', ->
      link.updateLink()
      return
    ).on 'mapjs-animatemove', ->
      linksForAnimation = linksForAnimation.add(link)
      return
    return
  mapModel.addEventListener 'linkRemoved', (l) ->
    stageElement.findLink(l).queueFadeOut nodeAnimOptions
    return
  mapModel.addEventListener 'mapScaleChanged', (scaleMultiplier) ->
    currentScale = stageElement.data('scale')
    targetScale = Math.max(Math.min(currentScale * scaleMultiplier, 5), 0.2)
    currentCenter = stagePointAtViewportCenter()
    if currentScale == targetScale
      return
    stageElement.data('scale', targetScale).updateStage()
    centerViewOn currentCenter.x, currentCenter.y
    return
  mapModel.addEventListener 'nodeVisibilityRequested', (ideaId) ->
    id = ideaId or mapModel.getCurrentlySelectedIdeaId()
    node = stageElement.nodeWithId(id)
    if node
      ensureNodeVisible node
      viewPort.finish()
    return
  mapModel.addEventListener 'nodeFocusRequested', (ideaId) ->
    node = stageElement.nodeWithId(ideaId).data()
    nodeCenterX = node.x + node.width / 2
    nodeCenterY = node.y + node.height / 2
    if stageElement.data('scale') != 1
      stageElement.data('scale', 1).updateStage()
    centerViewOn nodeCenterX, nodeCenterY, true
    return
  mapModel.addEventListener 'mapViewResetRequested', ->
    stageElement.data(
      'scale': 1
      'height': 0
      'width': 0
      'offsetX': 0
      'offsetY': 0).updateStage()
    stageElement.children().andSelf().finish nodeAnimOptions.queue
    $(stageElement).find('.mapjs-node').each ensureSpaceForNode
    $(stageElement).find('[data-mapjs-role=connector]').updateConnector true
    $(stageElement).find('[data-mapjs-role=link]').updateLink()
    centerViewOn 0, 0
    viewPort.focus()
    return
  mapModel.addEventListener 'layoutChangeStarting', ->
    viewPortDimensions = undefined
    stageElement.children().finish nodeAnimOptions.queue
    stageElement.finish nodeAnimOptions.queue
    return
  mapModel.addEventListener 'layoutChangeComplete', ->
    connectorGroupClone = $()
    linkGroupClone = $()
    connectorsForAnimation.each ->
      if !$(this).animateConnectorToPosition(nodeAnimOptions, 2)
        connectorGroupClone = connectorGroupClone.add(this)
      return
    linksForAnimation.each ->
      if !$(this).animateConnectorToPosition(nodeAnimOptions, 2)
        linkGroupClone = linkGroupClone.add(this)
      return
    connectorsForAnimation = $()
    linksForAnimation = $()
    stageElement.animate { 'opacity': 1 }, _.extend({ progress: ->
      connectorGroupClone.updateConnector()
      linkGroupClone.updateLink()
      return
    }, nodeAnimOptions)
    ensureNodeVisible stageElement.nodeWithId(mapModel.getCurrentlySelectedIdeaId())
    stageElement.children().dequeue nodeAnimOptions.queue
    stageElement.dequeue nodeAnimOptions.queue
    return

  ###editing ###
  if !options or !options.inlineEditingDisabled
    mapModel.addEventListener 'nodeEditRequested', (nodeId, shouldSelectAll, editingNew) ->
      editingElement = stageElement.nodeWithId(nodeId)
      mapModel.setInputEnabled false
      viewPort.finish()
      editingElement.editNode(shouldSelectAll).done((newText) ->
        mapModel.setInputEnabled true
        mapModel.updateTitle nodeId, newText, editingNew
        editingElement.focus()
        return
      ).fail ->
        mapModel.setInputEnabled true
        if editingNew
          mapModel.undo 'internal'
        editingElement.focus()
        return
      return
  mapModel.addEventListener 'addLinkModeToggled', (isOn) ->
    if isOn
      stageElement.addClass 'mapjs-add-link'
    else
      stageElement.removeClass 'mapjs-add-link'
    return
  mapModel.addEventListener 'linkAttrChanged', (l) ->
    attr = _.extend({ arrow: false }, l.style)
    stageElement.findLink(l).data(attr).updateLink()
    return
  mapModel.addEventListener 'activatedNodesChanged', (activatedNodes, deactivatedNodes) ->
    _.each activatedNodes, (nodeId) ->
      stageElement.nodeWithId(nodeId).addClass 'activated'
      return
    _.each deactivatedNodes, (nodeId) ->
      stageElement.nodeWithId(nodeId).removeClass 'activated'
      return
    return
  return
