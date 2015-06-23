root.File = {File} = require 'atom'
leveldb = require './db/levelgraph.min'

parsers =
  coffee: require('./grammars/coffeescript').parse

module.exports =
  class Datacule
    constructor: (@path) ->
      @file = new File(@path,false)
      @root = @file.getParent().path
      @text = @file.readSync()
      @db = leveldb(@file.digest)
      @title = @file.getBaseName()
      @parse = parsers[@title.split('.').pop()]
      @requires = []
      @map = @parse(@text)
      @results = undefined

    updateMap: () ->
      @text = @file.readSync()
      @map = @parse(@text)

    save: () ->
      @delete()
      triples = chemist.map2triples(@map)
      stream = @db.putStream()
      count = 0
      stream.on "close", ->
        console.log "saved #{count} rows to #{@title}"
      for t in triples
        stream.write(t)
        count += 1
      stream.end()
      return

    select: (query) ->
      if !query then query = {}
      @db.get query, (err,results) =>
        if results.length? and results.length > 0
          values = []
          types = []
          classes = []
          contains = []
          for row in results
            switch row.predicate
              when 'value'
                values[row.subject] = row.object
              when 'type'
                types[row.subject] =  row.object
              when 'class'
                if classes[row.subject]
                  classes[row.subject].push row.object
                else
                  classes[row.subject] = [row.object]
              when 'contains'
                if contains[row.subject]
                  contains[row.subject].push row.object
                else
                  contains[row.subject] = [row.object]
          @results = chemist.triples2map(1,values,types,classes,contains)
        else
          console.log 'no matches found'
          @results = Null
      return

    delete: (query) ->
      if !query then query = {}
      @db.get query, (err,results) =>
        if results.length > 0
          @db.del results, (err) =>
            if err? then console.log err
            else console.log "deleted #{results.length} rows from #{@title}"
        else
          console.log 'no matches found'
      return
