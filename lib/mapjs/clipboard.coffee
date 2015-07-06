class MAPJS.MemoryClipboard
  contents: undefined

  clone: (something) ->
    if !something
      return undefined
    JSON.parse JSON.stringify(something)

  get: ->
    @clone @contents

  put: (c) ->
    @contents = @clone(c)
    return
