module.exports =
  class Cursor
    constructor: (@db) ->
      @text = ''

    run: (@path) =>
      chemist.spin('cursor')
      @query = []
      if @text.length == 0
        @query.push
          subject: @db.v 'subject'
          object: @path
        @query.push
          subject: @db.v 'subject'
          predicate: @db.v 'predicate'
          object: @db.v 'object'
      else
        lines = @text.split('\n')
        for line in lines
          if line.length != 0
            queryRow = {}
            switch line.slice(0,1)
              when '#'
                @query.push
                  subject: @path + ':' + line.slice(1)
                  predicate: @db.v 'predicate'
                  object: @db.v 'object'
              when '_'
                queryRow.subject = @db.v 'subject'
                [queryRow.predicate,queryRow.object] = line.split(' ')
                if !queryRow.object?
                  queryRow.object = @db.v 'object'
                @query.push queryRow
                @query.push
                  subject: @db.v 'subject'
                  predicate: '_path'
                  object: @path
              else
                @query.push
                  subject: @db.v 'subject'
                  predicate: @db.v 'predicate'
                  object: line
                @query.push
                  subject: @db.v 'subject'
                  predicate: '_path'
                  object: @path
      @db.search @query, @format

    getMap: (error,results) =>
      if error? then console.log error
      count = results.length
      if results.length == 0
        console.log 'no results'
      for row in results
        console.log row
      if @text == '' then text = @path
      else text = @text
      next = genPositioner()
      edges = []
      for triple in results
        triple.predicate.order = next()
        edges.push
          subject: 'Query:1'
          predicate: 'results'
          object: triple.object
      results = results.concat(edges)
      results.push
        subject: 'Query:1'
        predicate:
          type: 'Query'
          root: true
          value: "#{text}\n\n returned #{count} node#{if count != 1 then 's' else ''}"
        object: 'Query:1'
      @map = chemist.triples2map results
      chemist.draw(this)

    format: (e,r) =>
      if e then console.log
      else
        chemist.stop('cursor')
        for row in r
          console.log row


genPositioner = ->
  order = 0
  nextPos = -> order += 1
