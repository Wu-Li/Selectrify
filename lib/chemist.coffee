#Packages
{File} = require 'atom'
Spinner = require '../js/spin.min'
#Modules
MAPJS = require './mapjs/mapjs'
Datacule = require './datacule'
Cursor = require './db/cursor'
#leveldb
leveljs = require("level-js")
levelup = require("levelup")
sublevel = require('level-sublevel')

module.exports =
  class Chemist
    constructor: (projectPaths) ->
      @name = 'Selectrify'
      @logs = true
      @directories = {}
      @mapModel = MAPJS.init()
      @db = sublevel levelup @name,
        db: (factory) -> return new leveljs(factory)
      @loadProject(projectPaths)

    loadProject: (projectPaths) ->
      openDirectories = Object.getOwnPropertyNames(@directories)
      for path in projectPaths
        if path not in openDirectories
          @directories[path] = @db.sublevel path
          @directories[path].path = path
          @directories[path].datacules = {}
    loader: (item) => return => @loadItem item
    loadItem: (item) =>
      if dirPath = @getDirPath item
        item.saveSubscription?.dispose()
        @loadFile(dirPath[0],dirPath[1],item)
      else if item?.constructor.name == 'TextEditor'
        if !item.saveSubscription?
          item.saveSubscription = item.getBuffer().onDidSave @loader item
    loadFile: (dir,path,item) =>
      try
        if !datacule = dir.datacules[path]
          file = new File dir.path + '/' + path
          datacule = dir.datacules[path] = new Datacule dir,path,file,item
      catch
        console.log dir,path,item
      return datacule.db.ready

    mappable: ['coffee','js','html','less','css']
    paths: ['lib','styles']
    getDirPath: (item) =>
      if item?.constructor.name == 'TextEditor'
        if item.getTitle()?.split('.').pop() in @mappable
          fullPath = item.getPath?()
          [dpath,path] = atom.project.relativizePath(fullPath)
          if @directories[dpath]? and path.split('\\')[0] in @paths
            return [@directories[dpath],path]

    tab: (item) ->
      if item?.constructor.name == 'TextEditor'
        if item.getTitle()?.split('.').pop() in @mappable
          if [dir,path] = @getDirPath(item)
            @activeTab = dir.datacules[path]
    activate: () ->
      if @activeTab?
        @datacule?.active = false
        @datacule?.idea = null
        @datacule = @activeTab
        @datacule.active = true
        @datacule.refresh()
        return @datacule
      return false

    #Active datacule shortcuts
    refresh: -> @datacule?.refresh()
    get: -> @datacule?.get()
    remove: -> @datacule?.remove()
    insert: (map) -> @datacule?.insert map
    select: -> @datacule?.select @cursor

    draw: (@map,collapse=10,depth=10) ->
      chemist.spin 'draw'
      clean = MAPJS.content {title:''}
      @mapModel.setIdea(clean)
      idea = MAPJS.content @map2idea @map,collapse,depth,0
      @mapModel.setIdea(idea)
      $("#queryBox")[0].focus()
      chemist.stop 'draw'
      return
    drawAt: (parentId,map,collapse=1,depth=10) ->
      idea = @map2idea map,collapse,depth,0,true
      ideas = []
      for key in Object.getOwnPropertyNames(idea.ideas)
        ideas.push idea.ideas[key]
      chemist.mapModel.getIdea().pasteMultiple(parentId,ideas)
      chemist.mapModel.collapse('chemist',true,parentId)
      return

    #Map <=> Idea
    map2idea: (map,collapse,depth,level,foreign) ->
      if level > depth then return title: '...'
      subIdeas = {}
      hasChildren = false
      keys = Object.getOwnPropertyNames(map.children)
      for key in keys
        for child in map.children[key]
          hasChildren = true
          subIdeas[child.attr.order] = @map2idea child,collapse,depth,level+1,foreign
      idea =
        id: Number(map.id.split(':')[1])
        title: map.attr.value
        attr: map.attr
        ideas: subIdeas
      if foreign
        delete(idea.id)
        map.attr.foreign = true
      if hasChildren and level >= collapse
        idea.attr.collapsed = true
      return idea
    idea2map: (idea) ->
      idea = idea or @mapModel.getIdea()
      if !idea.attr? then return
      idea.attr.value = idea.title
      if !idea.attr.foreign
        map =
          id: idea.id
          attr: idea.attr
          children: {}
        for subIdea in idea.sortedSubIdeas()
          child = @idea2map subIdea
          if child?
            edge = child.attr.edge
            map.children[edge] = map.children[edge] or []
            map.children[edge].push child
      return map

    repath: (importPath,exportPath) ->
      importFolders = importPath.split('\\')
      exportFolders = exportPath.split('\\')
      if exportFolders.length == 1
        exportFolders = exportFolders[0].split('/')
      if exportFolders.length == 1 then return false
      if exportFolders[0] == '.'
        exportFolders = importFolders[0..-2].concat exportFolders[1..-1]
      else
        depth = importFolders.length - 1
        height = 0
        for folder in exportFolders
          if folder == '..'
            height += 1
        if depth > height
          exportFolders = importFolders[0..(depth - height - 1)].concat exportFolders[height..-1]
        else
          exportFolders = exportFolders[height..-1]
      if exportFolders[0] in @paths
        return exportFolders.join('\\') + '.coffee'
      else return false

    wipe: ->
      chemist.spin('wipe')
      @wipedb(@db,@name).then ->
        console.log '<<< wipe complete'
        chemist.stop('wipe')
      return
    wipedb: (db,path) ->
      console.log ">>> #{path}"
      dfd = $.Deferred()
      results = []
      stream = db.createReadStream()
      .on 'error', (err) -> console.error err
      .on 'data', (data) ->
        if data and data.key
          results.push {type:'del', key:data.key}
      .on 'end', ->
        db.batch results, =>
          if results.length > 0
            console.log "removed #{results.length} rows from #{path}"
          keys = Object.getOwnPropertyNames(db.sublevels)
          $.when.apply $,
            for key in keys
              chemist.wipedb(db.sublevels[key],path + '\\' + key)
          .then ->
            stream.destroy()
            dfd.resolve()
      return dfd.promise()

    Map: (map) ->
      map.getSubMap = (id) =>
        search = (node) =>
          for key in Object.getOwnPropertyNames(node.children)
            for child in node.children[key]
              if child.id == id
                return child
              else if submap = search(child)
                return submap
          return
        if submap = search(map) then return chemist.Map(submap)
        else console.log "#{map.id} does not contain #{id}"
        return

      return map

    spinner: new Spinner(opts).spin()
    running: []
    spin: (source) =>
      if source in @running then return
      @running.push source
      @target = @target or document.getElementById('laboratory')
      @target.appendChild(@spinner.spin().el)
    stop: (source) =>
      @running.splice @running.indexOf(source), 1
      if @running.length == 0
        @spinner.stop()

opts =
  lines: 13 # The number of lines to draw
  length: 28 # The length of each line
  width: 14 # The line thickness
  radius: 42 # The radius of the inner circle
  scale: 1 # Scales overall size of the spinner
  corners: 1 # Corner roundness (0..1)
  color: '#000' # #rgb or #rrggbb or array of colors
  opacity: 0.25 # Opacity of the lines
  rotate: 0 # The rotation offset
  direction: 1 # 1: clockwise, -1: counterclockwise
  speed: 1 # Rounds per second
  trail: 60 # Afterglow percentage
  fps: 20 # Frames per second when using setTimeout() as a fallback for CSS
  zIndex: 2e9 # The z-index (defaults to 2000000000)
  className: 'spinner' # The CSS class to assign to the spinner
  top: '50%' # Top position relative to parent
  left: '50%' # Left position relative to parent
  shadow: false # Whether to render a shadow
  hwaccel: false # Whether to use hardware acceleration
  position: 'absolute' # Element positioning
