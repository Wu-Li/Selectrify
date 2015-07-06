$.fn.mapToolbarWidget = (mapModel) ->
  'use strict'
  clickMethodNames = [
    'insertIntermediate'
    'scaleUp'
    'scaleDown'
    'addSubIdea'
    'editNode'
    'removeSubIdea'
    'toggleCollapse'
    'addSiblingIdea'
    'undo'
    'redo'
    'copy'
    'cut'
    'paste'
    'resetView'
    'openAttachment'
    'toggleAddLinkMode'
    'activateChildren'
    'activateNodeAndChildren'
    'activateSiblingNodes'
    'editIcon'
    'toggleEdges'
    'toggleTypes'
    'toggleIDs'
  ]
  changeMethodNames = [ 'updateStyle' ]
  @each ->
    element = $(this)
    preventRoundtrip = false
    mapModel.addEventListener 'nodeSelectionChanged', ->
      preventRoundtrip = true
      element.find('.updateStyle[data-mm-target-property]').val(->
        mapModel.getSelectedStyle $(this).data('mm-target-property')
      ).change()
      preventRoundtrip = false
      return
    mapModel.addEventListener 'addLinkModeToggled', ->
      element.find('.toggleAddLinkMode').toggleClass 'active'
      return
    clickMethodNames.forEach (methodName) ->
      element.find('.' + methodName).click ->
        if mapModel[methodName]
          mapModel[methodName] 'toolbar'
        return
      return
    changeMethodNames.forEach (methodName) ->
      element.find('.' + methodName).change ->
        if preventRoundtrip
          return
        tool = $(this)
        if tool.data('mm-target-property')
          mapModel[methodName] 'toolbar', tool.data('mm-target-property'), tool.val()
        return
      return
    return
