parsers =
  coffee: require('./parsers/coffeescript').parse

module.exports =
  class Datacule
    constructor: (@db,@path,@file,@item) ->
      @grammar = @file.getBaseName().split('.').pop()
      @parse = parsers[@grammar]
      @item?.getBuffer().onDidSave @refresh
      @active = false
      @query =
        filter: (triple) =>
          triple.subject.split(':')[0] == @path
      if @file.existsSync()
        @db.get @query, @init
        @file.onDidDelete @remove
      else @remove()

    init: (err,results) =>
      if err then console.log err
      if results.length? and results.length > 0
        #console.log "#{@path} returned #{results.length} rows"
        @map = chemist.triples2map(results)
        @refresh()
      else
        @refresh()

    refresh: () =>
      if text = @newText()
        map = @parse @path,text
        map.digest = @file.getDigestSync()
        @remove map
      else
        @select()
    newText: () =>
      if @item?.getBuffer().previousModifiedStatus
        return @item.getText()
      text = @file.readSync(true)
      if @file.getDigestSync() != @map?.digest
        return text
      return false

    remove: (replace) =>
      @db.get @query, (err,results) =>
        if err? then console.log err
        if results.length > 0
          @db.del results, (err) =>
            if err? then console.log err
            else
              #console.log "deleted #{results.length} rows from #{@path}"
              @insert(replace)
        else @insert(replace)
      return
    insert: (map) =>
      triples = chemist.map2triples(map)
      stream = @db.putStream()
      count = 0
      stream.on "close", =>
        #console.log "saved #{count} rows to #{@path}"
        @select()
      for row in triples
        stream.write(row)
        count += 1
      stream.end()
      return
    select: () =>
      @db.get @query, (err,results) =>
        if err then console.log err
        else if results.length? and results.length > 0
          @map = chemist.triples2map(results)
          if @active then chemist.draw(@map)
        #else console.log 'no matches found'
      return

    #console out
    get: (cursor) =>
     cursor.run @db,@path, (e,r) =>
        if e then console.log e
        else if r.length? and r.length > 0
          for row in r
            console.log row
          console.log r.length
        else
          console.log 'no matches found'
