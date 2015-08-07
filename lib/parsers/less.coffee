less = require('less')

module.exports =
  parse: (prefix,text,callback) ->
    dfd = $.Deferred()
    less.parse(text)
    .then (ruleset) =>
      parseRuleSet prefix,ruleset
    .then (map) =>
      dfd.resolve map
    return dfd.promise()

  deparse: (map) ->
    lessText = map2less map,0,''
    return lessText

parseRuleSet = (prefix,ruleset) ->
  map = new LessMap ruleset,'file'
  map.attr.root = true
  map.attr.value = prefix
  setIds(prefix,map)
  return map

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

class LessMap
  constructor: (node,edge) ->
    @attr =
      edge: edge
      type: node.type
      classes: ['less']
    @setChildren(node)
    @setValue(node)
    @setOrder(node)

  setChildren: (node) ->
    @children = {}
    @nextPos = genPositioner()
    switch node.type
      when 'Ruleset'
        for child in node.rules
          if child.type != 'Comment'
            @createChild child,'rules'
      when 'Rule'
        if node.value.type? and node.value.type == 'Anonymous'
          @createChild node.value,'value'
        else if node.value.type == 'Value'
          for child in node.value.value[0].value
            @createChild child,'value'
      when 'Call'
        if node.args? and node.args.length > 0
          for arg in node.args
            @createChild arg.value[0],'arguments'
      when 'Url'
        @createChild node.value,'value'
    return

  createChild: (child,edge) ->
    @children[edge] = @children[edge] or []
    @children[edge].push new LessMap child,edge,@nextPos()

  setValue: (node) ->
    switch node.type
      when 'Ruleset'
        if node.selectors?
          selectors = []
          for selector in node.selectors
            elements = []
            for element in selector.elements
              if element.value.type == 'Attribute'
                if element.value.value.type == 'Quoted'
                  value = '"' + element.value.value.value + '"'
                else value = element.value.value
                elements.push "[#{element.value.key}#{element.value.op}#{value}]"
              else if element.combinator.emptyOrWhitespace
                elements.push element.value
              else
                elements.push ' ' + element.combinator.value + ' ' + element.value
            selectors.push elements.join('')
          @attr.value = selectors.join(',\n')
          @attr.classes.push 'selector','keyword','control'
      when 'Rule'
        @attr.value = node.name[0].value
        @attr.classes.push 'property','property-name','support'
      when 'Anonymous'
        @attr.value = node.value
        @attr.classes.push 'value'
        if isNaN Number @attr.value.slice(0,1)
          @attr.classes.push 'property-value','support'
        else
          @attr.classes.push 'constant','numeric'
      when 'Keyword'
        @attr.value = node.value
      when 'Call'
        @attr.value = node.name + '('
        @attr.classes.push 'support','function','call'
      when 'Url'
        @attr.value = "url("
        @attr.classes.push 'support','function'
      when 'Quoted'
        @attr.value = "#{node.quote}#{node.value}#{node.quote}"
        @attr.classes.push 'string'
      when 'Dimension'
        @attr.value = node.value + ''
        if node.unit.numerator.length > 0
          @attr.value += node.unit.numerator.join(' * ')
        if node.unit.denominator.length > 0
          for denom in node.unit.denominator
            @attr.value += ' / ' + denom
        @attr.classes.push 'constant','numeric'
      else
        console.log node
    return

  setOrder: (node) ->
    @nextPos = genPositioner()
    edges = Object.getOwnPropertyNames @children
    for edge in edges
      for child in @children[edge]
        child.attr.edge += ':' + child.attr.order = @nextPos()

order = (a,b) -> return a.attr.order - b.attr.order

map2less = (map,level,text) ->
  indent = '\n' + Array(level).join('\t')
  switch map.attr.type
    when 'Ruleset'
      if level > 0
        text += indent + map.attr.value + ' {'
      map.children.rules.sort(order)
      for rule in map.children.rules
        text = map2less(rule,level+1,text)
      if level > 0
        text += indent + '}'
    when 'Rule'
      text += indent + map.attr.value + ': '
      map.children.value.sort(order)
      for value in map.children.value
        text = map2less(value,level+1,text) + ' '
      text = text.slice(0,-1) + ';'
    when 'Call'
      text += map.attr.value
      map.children.arguments.sort(order)
      for arg in map.children.arguments
        text = map2less(arg,level,text) + ','
      text = text.slice(0,-1) + ')'
    when 'Anonymous','Keyword','Dimension'
      text += map.attr.value
  return text
