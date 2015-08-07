levelgraph = require("levelgraph")

module.exports =
  class MapDB
    constructor: (dir,@path,map,digest) ->
      dfd = $.Deferred()
      @ready = dfd.promise()
      @leveldb = dir.sublevel @path
      @vertices = @leveldb.sublevel '_vertices'
      @edges = levelgraph @leveldb.sublevel '_edges'
      @children = {}
      @imports = {}
      @exports = {}
      meta = {}
      @leveldb.createReadStream()
      .on 'error', dfd.reject
      .on 'data', (data) => meta[data.key] = data.value
      .on 'end', =>
        if digest? and digest == meta.digest
          @digest = digest
          if meta.imports?
            @imports = JSON.parse meta.imports
          if meta.exports?
            @exports = JSON.parse meta.exports
          if meta.children?
            $.when.apply $,
              for path in JSON.parse meta.children
                submap = map.getSubMap @exports[path]
                @children[path] = new MapDB @leveldb,path,submap,digest
                @children[path].ready
            .then => dfd.resolve map
          else dfd.resolve map
        else @update(map,digest).then (map) => dfd.resolve map

    addChild: (path,map,digest) ->
      if path.slice(1) == '_' then return
      if @children[path]?
        return @children[path].update(map,digest)
      else
        @children[path] = new MapDB @leveldb,path,map,digest
        @leveldb.put 'children',JSON.stringify Object.getOwnPropertyNames(@children)
        return @children[path].ready
    removeChild: (path) ->
      @children[path].leveldb.destroy()
      delete(@children[path])
      @leveldb.put 'children',Object.getOwnPropertyNames(@children)
      return
    removeChildren: ->
      for key in Object.getOwnPropertyNames(@children)
        @removeChild key
      return

    update: (map,digest) ->
      dfd = $.Deferred()
      if digest? and digest == @digest
        dfd.resolve map
      else
        @remove()
        .then => @insert map,digest
        .then => @get()
        .then (map) =>
          if digest?
            @leveldb.put 'digest',digest,(err) => dfd.resolve map
          else
            @leveldb.del 'digest',(err) => dfd.resolve map
      return dfd.promise()

    ##Remove##
    remove: (path) ->
      if @children[path]?
        return @children[path].remove()
      dfd = $.Deferred()
      if path? then dfd.reject
      else
        @wipe @leveldb.sublevels['_edges']
        .then => @wipe @vertices
        .then (count) =>
          if count > 0 and chemist.logs
            console.log "#{@path} --- #{count}"
          $.when.apply $,
            for key in Object.getOwnPropertyNames @children
              @children[key].remove()
          .then dfd.resolve,dfd.reject
      return dfd.promise()
    wipe: (db) ->
      dfd = $.Deferred()
      results = []
      db.createReadStream()
      .on 'error', dfd.reject
      .on 'data', (data) =>
        if data and data.key
          results.push {type:'del', key:data.key}
      .on 'end', =>
        db.batch results, =>
          dfd.resolve results.length
      return dfd.promise()

    ##Insert##
    insert: (map,digest) ->
      dfd = $.Deferred()
      map.attr.root = true
      [vertices,edges,submaps] = @map2db(map)
      if chemist.logs then console.log "#{@path} +++ #{vertices.length} ..."
      @vertices.batch vertices, (err) =>
        if err? then return dfd.reject(err)
        @edges.put edges, (err) =>
          if err? then return dfd.reject(err)
          $.when.apply $,
            for submap in submaps
              @addChild(submap.attr.exports,submap,digest)
          .then dfd.resolve,dfd.reject
      return dfd.promise()
    map2db: (map) =>
      vertices = []
      edges = []
      submaps = []
      process = (map) =>
        if map.attr.imports?
          @imports[map.id] = map.attr.imports
          @leveldb.put 'imports',JSON.stringify @imports
        if map.attr.exports? and !map.attr.root
          submaps.push map
          @exports[map.attr.exports] = map.id
          @leveldb.put 'exports',JSON.stringify @exports
          return
        vertices.push
          type: 'put'
          key: map.id
          value: JSON.stringify map.attr
        for key in Object.getOwnPropertyNames(map.children)
            for child in map.children[key]
              edges.push
                subject: map.id
                predicate: key
                object: child.id
              process(child)
      process(map)
      if chemist.logs then console.log "map2db(#{@path}) v:#{vertices.length} e:#{edges.length}",submaps
      return [vertices,edges,submaps]

    ##Get##
    get: ->
      dfd = $.Deferred()
      @getRows().then (vertices,edges) =>
        if vertices.length == edges.length == 0
          dfd.reject "#{@path} >>> no results found"
        else
          map = @db2map vertices,edges
          if chemist.logs then console.log "#{@path}:",map
        dfd.resolve map
      return dfd.promise()
    getRows: ->
      dfd = $.Deferred()
      if chemist.logs then console.log "getting #{@path} ..."
      vertices = []
      edges = []
      @vertices.createReadStream()
      .on 'error', dfd.reject
      .on 'data', (data) => vertices.push data
      .on 'end', =>
        @edges.getStream({})
        .on 'error', dfd.reject
        .on 'data', (data) => edges.push data
        .on 'end', =>
          $.when.apply $,
            for key in Object.getOwnPropertyNames(@children)
              @children[key].getRows().then (vrows,erows) =>
                vertices = vertices.concat vrows
                edges = edges.concat erows
          .then =>
            if chemist.logs then console.log "#{@path} returned v:#{vertices.length} e:#{edges.length}"
            dfd.resolve vertices,edges
      return dfd.promise()
    db2map: (vertices,edges) ->
      attrs = {}
      children = {}
      for row in vertices
        attr = JSON.parse row.value
        attrs[row.key] = attr
        if attr.root and (!rootId? or attr.edge == 'file')
          rootId = row.key
      for row in edges
        if children[row.subject]?
          if children[row.subject][row.predicate]?
            children[row.subject][row.predicate].push row.object
          else
            children[row.subject][row.predicate] = [row.object]
        else
          children[row.subject] = {}
          children[row.subject][row.predicate] = [row.object]
      return @buildMap(rootId,attrs,children)
    buildMap: (id,attrs,children) ->
      map =
        id: id
        attr: attrs[id]
        children: {}
      if children[id]?
        for key in Object.getOwnPropertyNames(children[id])
          map.children[key] = []
          for kid in children[id][key]
            map.children[key].push @buildMap(kid,attrs,children)
      return chemist.Map map
