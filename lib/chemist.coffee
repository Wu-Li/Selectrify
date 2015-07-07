{File} = require 'atom'
MAPJS = require './mapjs/mapjs'
levelgraph = require '../js/levelgraph.min'
Datacule = require './datacule'
Cursor = require './db/cursor'
spin = require '../js/spin.min'

module.exports =
  class Chemist
    constructor: (projectPaths) ->
      @mapModel = MAPJS.init()
      @directories = {}
      @loadProject projectPaths
      @activeTab = undefined
      @activeMap = undefined
      @cursor = new Cursor()

    spin: spin
    
    loadProject: (projectPaths) ->
      openDirectories = Object.getOwnPropertyNames(@directories)
      for path in projectPaths
        if !(path in openDirectories)
          @loadDirectory path
    loadDirectory: (path) ->
      @directories[path] =
        db: levelgraph(path)
        datacules: {}

    mappable: ['coffee']
    getDirPath: (item) =>
      if item?.constructor.name == 'TextEditor'
        if item.getTitle()?.split('.').pop() in @mappable
          fullPath = item.getPath?()
          [dir,path] = atom.project.relativizePath(fullPath)
          if @directories[dir]?
            return [dir,path]

    getDatacule: (dirPath) => @directories[dirPath[0]]?.datacules[dirPath[1]]

    loadItem: (item) =>
      if dirPath = @getDirPath item
        item.saveSubscription?.dispose()
        @loadFile(dirPath[0],dirPath[1],item)
      else if item?.constructor.name == 'TextEditor'
        item.saveSubscription = item.getBuffer().onDidSave @loader item
    loadFile: (dir,path,item) =>
      if !@getDatacule([dir,path])
        if file = new File dir + '/' + path
          db = @directories[dir].db
          @directories[dir].datacules[path] = new Datacule db,path,file,item
    loader: (item) => return () => @loadItem item

    tab: (item) -> @activeTab = @getDirPath(item)
    activate: () ->
      if @activeTab
        @datacule?.active = false
        @datacule = @getDatacule @activeTab
        @datacule.active = true
        @db = @directories[@activeTab[0]].db
        @datacule.refresh()
    draw: (map) ->
      if map?
        @activeMap = @activeTab
        @map = map
        clean = MAPJS.content {title:''}
        @mapModel.setIdea(clean)
        idea = MAPJS.content @map2idea @map
        @mapModel.setIdea(idea)
      return

    #Active datacule shortcuts
    refresh: () -> @datacule?.refresh()
    select: () -> @datacule?.select()
    remove: () -> @datacule?.remove()
    insert: (map) -> @datacule?.insert map
    get: () -> @datacule?.get @cursor
    wipe: () ->
      paths = Object.getOwnPropertyNames(@directories)
      for path in paths
        db = @directories[path].db
        db.get {},(e,r) ->
          db.del r,(e) ->
            if e? then console.log e
            else console.log "deleted #{r.length} rows from #{path}"

    #Map <=> Idea
    first: ['args']
    map2idea: (map) ->
      subIdeas = {}
      keys = Object.getOwnPropertyNames(map._children)
      after = []
      for key in keys
        if key in @first
          [subIdeas,maxId] = @mapEdge(map,key,subIdeas)
        else after.push key
      for key in after
        subIdeas = @mapEdge(map,key,subIdeas,maxId)[0]
      idea =
        id: map._id.split(':')[1]
        title: map._value
        attr: map._attr
        ideas: subIdeas
      return idea
    mapEdge: (map,key,subIdeas,minId) ->
      maxId = 0
      minId = minId or 0
      for child in map._children[key]
        kid = child._id.split(':')[1] + minId
        maxId = Math.max(maxId,kid)
        subIdeas[kid] = @map2idea child
      return [subIdeas,maxId]
    idea2map: (idea) ->
      idea = idea or @mapModel.getIdea()
      map =
        _id: idea.id
        _value: idea.title
        _attr: idea.attr
        _children: @idea2map idea for idea in idea.sortedSubIdeas()
      return map

    #Map <=> Triples
    map2triples: (map,triples) ->
      if !map?._id? then return []
      triples = triples or [{
          subject: map._id
          predicate: 'path'
          object: map._id
          value: map._id.split(':')[0]
          type: 'Block'
          classes: []
          digest: map.digest
        }]
      keys = Object.getOwnPropertyNames(map._children)
      if keys? and keys.length?
        for key in keys
          if map._children[key]? and map._children[key].length?
            for child in map._children[key]
              if child?
                triples.push
                  subject: map._id
                  predicate: key
                  object: child._id
                  value: if child._value? then child._value
                  type: child._attr.type
                  classes: child._attr.classes
                @map2triples child,triples
      return triples
    triples2map: (triples) ->
      values = {}
      attrs = {}
      edges = {}
      for row in triples
        if row.predicate == 'path'
          root = row.subject
          digest = row.digest
        else if edges[row.subject]?
          if edges[row.subject][row.predicate]?
            edges[row.subject][row.predicate].push row.object
          else
            edges[row.subject][row.predicate] = [row.object]
        else
          edges[row.subject] = {}
          edges[row.subject][row.predicate] = [row.object]
        values[row.object] = row.value
        attrs[row.object] =
          edge: row.predicate
          type: row.type
          classes: row.classes
      return @buildMap(root,values,attrs,edges,digest)
    buildMap: (id,values,attrs,edges,digest) ->
      children = {}
      if edges[id]?
        keys = Object.getOwnPropertyNames(edges[id])
        for key in keys
          children[key] = []
          for kid in edges[id][key]
            children[key].push @buildMap(kid,values,attrs,edges)
      map =
        _id: id
        _value: values[id]
        _attr: attrs[id]
        _children: children
      if digest? then map.digest = digest
      return map
