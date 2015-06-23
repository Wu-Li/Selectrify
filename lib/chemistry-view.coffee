{$, View} = require('atom-space-pen-views')

module.exports =
class ChemistryView extends View
  @content: ->
    @div class: "chemistry" , =>
      @div class: "chemistry-resize-handle"
      @div id: "tray", =>
        @button class: 'scaleUp'
        @button class: 'scaleDown'
        @div =>
          @label 'edges', for: 'edges', =>
            @input type: 'checkbox', id: 'edges', class: 'toggleEdges'
            @span ''
        @div =>
          @label 'types', for: 'types', =>
            @input type: 'checkbox', id: 'types', class: 'toggleTypes'
            @span ''


      @div id: "container"

  initialize: (state) ->
    @on 'mousedown', '.chemistry-resize-handle', (e) => @resizeStarted(e)

  attached: ->
    @focus()

  detached: ->
    @resizeStopped()

  serialize: ->

  destroy: ->
    @element.remove()

  getElement: ->
    @element

  resizeStarted: =>
    $(document).on('mousemove', @resizeChemistry)
    $(document).on('mouseup', @resizeStopped)

  resizeStopped: =>
    $(document).off('mousemove', @resizeChemistry)
    $(document).off('mouseup', @resizeStopped)

  resizeChemistry: ({pageX, which}) =>
    return @resizeStopped() unless which is 1
    width = $(document.body).width() - pageX
    @width(width)
