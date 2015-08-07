MapDB = require './db/mapdb'

module.exports =
  class Datacule
    constructor: (@dir,@path,@file,@item) ->
      if chemist.logs then console.log ">>> initializing #{@path} ..."
      chemist.spin @path
      @grammar = @path.split('.').pop()
      @parse = require('./parsers/parsers').parsers[@grammar]
      @deparse = require('./parsers/parsers').deparsers[@grammar]
      @item?.getBuffer().onDidSave => @refresh()
      @file.onDidDelete @remove
      text = @file.readSync(true)
      digest = @file.getDigestSync()
      @parse(@path,text).then (map) =>
        map = chemist.Map(map)
        @db = new MapDB @dir,@path,map,digest
        @db.ready.then @finish,@fail

    refresh: =>
      chemist.spin @path
      if chemist.logs then console.log "refreshing #{@path} ..."
      if @item?.getBuffer().previousModifiedStatus
        text = @item.getText()
      else
        text = @file.readSync(true)
        digest = @file.getDigestSync()
      @parse(@path,text)
      .then (map) =>
        map = chemist.Map(map)
        @db.update map,digest
      .then @finish,@fail
      return

    finish: (@map) =>
      if chemist.logs then console.log "<<< completed #{@path}"
      if @active then chemist.draw @map
      chemist.stop @path
      @getImports()
      return
    fail: (error) =>
      console.error @path,error
      chemist.stop(@path)
      return

    getText: => @deparse @map
    get: => @db.get()
    remove: => @db.remove()
    insert: (map) => @db.insert(map)

    getImports: ->
      for parentId in Object.getOwnPropertyNames @db.imports
        pid = Number(parentId.split(':')[1])
        relPath = @db.imports[parentId].path
        name = @db.imports[parentId].name
        @import pid,relPath,name

    import: (pid,relPath,name) ->
      getImport = (expDb,name) =>
        expDb.children[name].get().then (map) =>
          if chemist.logs then console.log "importing:",pid,relPath,map,name
          if @active then chemist.drawAt(pid,map)
          return
      if expPath = chemist.repath(@path,relPath)
        if chemist.logs then console.log "Linking: #{expPath}"
        chemist.loadFile(@dir,expPath).then =>
          expDb = @dir.datacules[expPath].db
          if name? then getImport(expDb,name)
          else
            for key in keys = Object.getOwnPropertyNames(expDb.children)
              getImport(expDb,key)
      return
