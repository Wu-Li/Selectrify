ops =
'>': 'archOut'
'<': 'archIn'
'=': 'bind'
'as': 'as'

module.exports =
  class Cursor
    constructor: () ->
      @results = []

    run: (db,path,callback) ->
      # db.search [{
      #     subject: path
      #     predicate: '_path'
      #     object:
      #   },{
      #     subject: x
      #     predicate: 'base'
      #     #object: db.v('object')
      #   }], @format

      nav = db.nav(db.v('y')).archOut('_path').archIn(db.v('x'))
      nav.triples @format
    #   nav.values @genSub(db,@format)

    # genSub: (db,cb) ->
    #   sub = (e,r) ->
    #     if e then console.log e
    #     else if r.length? > 0
    #       for value in r
    #         db.get {subject: value}, cb
    #   return sub

    format: (e,r) ->
      if e then console.log e
      else if r.length? and r.length > 0
        for row in r
          console.log row
      else console.log 'no results'
