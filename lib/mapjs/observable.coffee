root.observable = observable = (base) ->
  'use strict'
  listeners = []
  x = undefined

  base.addEventListener = (types, listener, priority) ->
    types.split(' ').forEach (type) ->
      if type
        listeners.push
          type: type
          listener: listener
          priority: priority or 0
      return
    return

  base.listeners = (type) ->
    listeners.filter((listenerDetails) ->
      listenerDetails.type == type
    ).map (listenerDetails) ->
      listenerDetails.listener

  base.removeEventListener = (type, listener) ->
    listeners = listeners.filter((details) ->
      details.listener != listener
    )
    return

  base.dispatchEvent = (type) ->
    args = Array::slice.call(arguments, 1)
    listeners.filter((listenerDetails) ->
      listenerDetails.type == type
    ).sort((firstListenerDetails, secondListenerDetails) ->
      secondListenerDetails.priority - (firstListenerDetails.priority)
    ).some (listenerDetails) ->
      try
        return listenerDetails.listener.apply(undefined, args) == false
      catch e
        console.log 'dispatchEvent failed', e, listenerDetails
      return
    return

  base
