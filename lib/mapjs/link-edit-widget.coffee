$.fn.linkEditWidget = (mapModel) ->
  'use strict'
  @each ->
    element = $(this)
    currentLink = undefined
    width = undefined
    height = undefined
    colorElement = undefined
    lineStyleElement = undefined
    arrowElement = undefined
    colorElement = element.find('.color')
    lineStyleElement = element.find('.lineStyle')
    arrowElement = element.find('.arrow')
    mapModel.addEventListener 'linkSelected', (link, selectionPoint, linkStyle) ->
      currentLink = link
      element.show()
      width = width or element.width()
      height = height or element.height()
      element.css
        top: selectionPoint.y - (0.5 * height) - 15 + 'px'
        left: selectionPoint.x - (0.5 * width) - 15 + 'px'
      colorElement.val(linkStyle.color).change()
      lineStyleElement.val linkStyle.lineStyle
      arrowElement[if linkStyle.arrow then 'addClass' else 'removeClass'] 'active'
      return
    mapModel.addEventListener 'mapMoveRequested', ->
      element.hide()
      return
    element.find('.delete').click ->
      mapModel.removeLink 'mouse', currentLink.ideaIdFrom, currentLink.ideaIdTo
      element.hide()
      return
    colorElement.change ->
      mapModel.updateLinkStyle 'mouse', currentLink.ideaIdFrom, currentLink.ideaIdTo, 'color', $(this).val()
      return
    lineStyleElement.find('a').click ->
      mapModel.updateLinkStyle 'mouse', currentLink.ideaIdFrom, currentLink.ideaIdTo, 'lineStyle', $(this).text()
      return
    arrowElement.click ->
      mapModel.updateLinkStyle 'mouse', currentLink.ideaIdFrom, currentLink.ideaIdTo, 'arrow', !arrowElement.hasClass('active')
      return
    element.mouseleave element.hide.bind(element)
    return

$.fn.attachmentEditorWidget = (mapModel) ->
  'use strict'
  @each ->
    element = $(this)
    mapModel.addEventListener 'attachmentOpened', (nodeId, attachment) ->
      mapModel.setAttachment 'attachmentEditorWidget', nodeId,
        contentType: 'text/html'
        #content: prompt('attachment', attachment and attachment.content)
      return
    return
