MAPJS.MemoryClipboard = ->
  'use strict'
  self = this

  clone = (something) ->
    if !something
      return undefined
    JSON.parse JSON.stringify(something)

  contents = undefined

  self.get = ->
    clone contents

  self.put = (c) ->
    contents = clone(c)
    return

  return
