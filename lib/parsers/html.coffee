module.exports =
  parse: (prefix,text) ->
    dfd = $.Deferred
    root.dom = dom = document.createElement('html')
    dom.innerHTML = text
    map = new HTMLMap dom,'file'
    map.attr.root = true
    map.attr.value = @path
    setIds(prefix,map)
    dfd.resolve map
    return dfd.promise()

  deparse: (map) ->
    map.attr.value = 'html'
    htmlText = map2html map,0,'<!DOCTYPE html>'
    return htmlText

setIds = (prefix,map) ->
  currentId = 0
  nextId = (map) =>
    map.id = prefix + ':' + (currentId += 1)
    keys = Object.getOwnPropertyNames(map.children)
    for key in keys
      for child in map.children[key]
        nextId(child)
  nextId(map)

genPositioner = ->
  order = 0
  nextPos = -> order += 1

class HTMLMap
  constructor: (node,edge) ->
    @attr =
      edge: edge
      type: node.nodeName
      classes: ['html']
    @setChildren(node)
    if edge == 'elements' and !@children.attributes?
      @attr.classes.push 'no-attributes'
    @setValue(node)
    @setOrder(node)

  setChildren: (node) ->
    @children = @children or {}
    if node.childNodes?
      for child in node.childNodes
        switch child.nodeType
          when 1
            @createChild child,'elements'
          when 3
            if child.nodeValue?.trim().length > 0
              if @attr.edge == 'attributes'
                @createChild child,'values'
              else
                @createChild child,'elements'
    if node.attributes?
      for child in node.attributes
        @createChild child,'attributes'
    return

  createChild: (child,edge) ->
    @children[edge] = @children[edge] or []
    @children[edge].push new HTMLMap child,edge

  setValue: (node) ->
    if @attr.type == '#text'
      @attr.classes.push 'text'
      div = document.createElement 'div'
      div.innerHTML = node.nodeValue
      div.innerHTML = div.firstChild?.nodeValue
      if div.firstChild?.nodeType == 1
        @setChildren(div)
        @attr.value = '"'
      else
        @attr.value = div.firstChild?.nodeValue
    else switch @attr.edge
      when 'values'
        @attr.classes.push 'values'
      when 'attributes'
        @attr.value = node.nodeName + '='
        @attr.classes.push 'attributes'
      when 'elements'
        @attr.value = node.nodeName.toLowerCase()
        @attr.classes.push 'elements'
        if @attr.type == 'script'
          @attr.classes.push 'script'

  setOrder: (node) ->
    @nextPos = genPositioner()
    if @children.attributes?
      for child in @children.attributes
        child.attr.edge += ':' + child.attr.order = @nextPos()
    edges = Object.getOwnPropertyNames @children
    for edge in edges
      if edge != 'attributes'
        for child in @children[edge]
          child.attr.edge += ':' + child.attr.order = @nextPos()

order = (a,b) -> return a.attr.order - b.attr.order

map2html = (map,level,text) ->
    indent = '\n' + Array(level).join('\t')
    text += indent + '<' + map.attr.value
    if map.children.attributes?
      text = getAttributes(map.children.attributes,level,text)
    text += '>'
    if map.children.elements?
      text = getElements(map.children.elements,level+1,text)
    if map.attr.value not in ['br','hr','img','input','link','meta','area',
                          'base','col','embed','keygen','menuitem',
                          'param','source','track','wbr']
      text += indent + '</' + map.attr.value + '>'
    return text

getAttributes = (attributes,indent,text) ->
  for attribute in attributes
    text += ' ' + attribute.attr.value
    for value in attribute.children.values
      text += value.attr.value
  return text

getElements = (elements,level,text) ->
  indent = '\n' + Array(level).join('\t')
  elements.sort(order)
  for element in elements
    if element.attr.type == '#text'
      text += indent + element.attr.value.trim()
    else
      text = map2html element,level,text
  return text
