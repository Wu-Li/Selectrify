do ->

  $.fn.simpleDraggableContainer = ->
    currentDragObject = undefined
    originalDragObjectPosition = undefined
    container = this

    drag = (event) ->
      if currentDragObject and event.gesture
        newpos =
          top: Math.round(parseInt(originalDragObjectPosition.top, 10) + event.gesture.deltaY)
          left: Math.round(parseInt(originalDragObjectPosition.left, 10) + event.gesture.deltaX)
        currentDragObject.css(newpos).trigger $.Event('mm-drag',
          currentPosition: newpos
          gesture: event.gesture)
        if event.gesture
          event.gesture.preventDefault()
        return false
      return

    rollback = (e) ->
      target = currentDragObject
      # allow it to be cleared while animating
      if target.attr('mapjs-drag-role') != 'shadow'
        target.animate originalDragObjectPosition,
          complete: ->
            target.trigger $.Event('mm-cancel-dragging', gesture: e.gesture)
            return
          progress: ->
            target.trigger 'mm-drag'
            return
      else
        target.trigger $.Event('mm-cancel-dragging', gesture: e.gesture)
      return

    Hammer this, 'drag_min_distance': 2
    @on('mm-start-dragging', (event) ->
      if !currentDragObject
        currentDragObject = $(event.relatedTarget)
        originalDragObjectPosition =
          top: currentDragObject.css('top')
          left: currentDragObject.css('left')
        $(this).on 'drag', drag
      return
    ).on('mm-start-dragging-shadow', (event) ->
      target = $(event.relatedTarget)

      clone = ->
        result = target.clone().addClass('drag-shadow').appendTo(container).offset(target.offset()).data(target.data()).attr('mapjs-drag-role', 'shadow')
        scale = target.parent().data('scale') or 1
        if scale != 0
          result.css
            'transform': 'scale(' + scale + ')'
            'transform-origin': 'top left'
        result

      if !currentDragObject
        currentDragObject = clone()
        originalDragObjectPosition =
          top: currentDragObject.css('top')
          left: currentDragObject.css('left')
        currentDragObject.on('mm-stop-dragging mm-cancel-dragging', (e) ->
          @remove()
          e.stopPropagation()
          e.stopImmediatePropagation()
          evt = $.Event(e.type,
            gesture: e.gesture
            finalPosition: e.finalPosition)
          target.trigger evt
          return
        ).on 'mm-drag', (e) ->
          target.trigger e
          return
        $(this).on 'drag', drag
      return
    ).on('dragend', (e) ->
      $(this).off 'drag', drag
      if currentDragObject
        evt = $.Event('mm-stop-dragging',
          gesture: e.gesture
          finalPosition: currentDragObject.offset())
        currentDragObject.trigger evt
        if evt.result == false
          rollback e
        currentDragObject = undefined
      return
    ).on('mouseleave', (e) ->
      if currentDragObject
        $(this).off 'drag', drag
        rollback e
        currentDragObject = undefined
      return
    ).attr 'data-drag-role', 'container'

  onDrag = (e) ->
    $(this).trigger $.Event('mm-start-dragging',
      relatedTarget: this
      gesture: e.gesture)
    e.stopPropagation()
    e.preventDefault()
    if e.gesture
      e.gesture.stopPropagation()
      e.gesture.preventDefault()
    return

  onShadowDrag = (e) ->
    $(this).trigger $.Event('mm-start-dragging-shadow',
      relatedTarget: this
      gesture: e.gesture)
    e.stopPropagation()
    e.preventDefault()
    if e.gesture
      e.gesture.stopPropagation()
      e.gesture.preventDefault()
    return

  $.fn.simpleDraggable = (options) ->
    if !options or !options.disable
      $(this).on 'dragstart', onDrag
    else
      $(this).off 'dragstart', onDrag

  $.fn.shadowDraggable = (options) ->
    if !options or !options.disable
      $(this).on 'dragstart', onShadowDrag
    else
      $(this).off 'dragstart', onShadowDrag

  return
