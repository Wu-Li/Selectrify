MAPJS = require './mapjs/src/mapjs'
root.Datacule = Datacule = require('./datacule')

module.exports =
  class Chemist
    constructor: () ->
      @mapModel = MAPJS.init()
      @datacules = {}
      @edges = false
      @types = false
      @activeTab = undefined
      @activeMap = undefined

    loadItem: (paneItem) ->
      if paneItem.constructor.name == 'TextEditor'
        title = paneItem.getTitle?()
        if !@datacules[title]
          path = paneItem.getPath().replace(/\\/g,"\\\\")
          @datacules[title] = new Datacule path

    tab: (paneItem) ->
      @activeTab = paneItem.getTitle?()

    draw: (title) ->
      if !@activeTab and !@activeMap and !title then return
      if !title then title = @activeTab
      @activeMap = title
      clean = MAPJS.content {title:''}
      @mapModel.setIdea(clean)
      map = @datacules[@activeMap].map
      idea = MAPJS.content @map2idea map
      @mapModel.setIdea(idea)
      return

    save: (title) ->
      if !title then title = @title
      @datacules[title].save()

    saveAll: ->
      keys = Object.keys(@datacules)
      for key in keys
        @datacules[key].save()

    select: (query,title) ->
      if !title then title = @title
      @datacules[title].select(query)

    delete: (query,title) ->
      if !title then title = @title
      @datacules[title].delete(query)

    map2idea: (map) ->
      subIdeas = {}
      position = 1
      keys = Object.getOwnPropertyNames(map.children)
      for key in keys
        for child in map.children[key]
          subIdeas[position] = @map2idea child
          position += 10
      classes = []
      if @edges then classes.push 'show-edges'
      if @types then classes.push 'show-types'
      if map.id == 1 then classes = []
      idea =
        id: map.id
        title: map.value
        ideas: subIdeas
        attr:
          type: map.type
          edge: map.edge
          path: map.path
          scope: map.scope
          classes: map.classes.concat classes
      return idea

    idea2map: (idea) ->
      if !idea then idea = @mapModel.getIdea()
      map =
        id: idea.id
        value: idea.title
        type: idea.attr.type
        classes: idea.attr.classes
        children: @idea2map idea for idea in idea.sortedSubIdeas()
      return map

    map2triples: (map) ->
      triples = []
      triples.push
        subject: map.id
        predicate: 'value'
        object: map.value
      triples.push
        subject: map.id
        predicate: 'type'
        object: map.type
      for c in map.classes
        triples.push
          subject: map.id
          predicate: 'class'
          object: c
      if map.children.length == 0
        return triples
      for child in map.children
        if !child.id then console.log map
        triples.push
          subject: map.id
          predicate: 'contains'
          object: child.id
        triples = triples.concat @map2triples child
      return triples

    triples2map: (id,values,types,classes,contains) ->
      children = []
      if contains[id]?
        for kid in contains[id]
          children.push @triples2map(kid,values,types,classes,contains)
      map =
        id: id
        value: values[id]
        type: types[id]
        classes: classes[id]
        children: children
      return map
