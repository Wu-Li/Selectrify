{nodes} = require 'coffee-script'

stack = []
path = ''

module.exports =
  parse: (prefix,text) ->
    dfd = $.Deferred()
    root.AST = nodes text
    stack = []
    map = new CoffeeMap AST,'file',false
    map.attr.root = true
    map.attr.value = prefix
    setIds(prefix,map)
    dfd.resolve map
    return dfd.promise()

  deparse: (map) ->
    ct = new CoffeeBlock map,0
    return ct.text

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

class CoffeeMap
  constructor: (node,edge,@collapse) ->
    @attr =
      value: ''
      edge: edge
      type: node.constructor.name
      classes: ['coffee']
    @setCollapse(edge)
    @setChildren(node)
    @process(node)
    @setOrder(node)

  setCollapse: (edge) ->
    if edge == 'variable' and @attr.type == 'Assign' or
    edge in ['condition','source','expression','index','subject']
      @collapse = true

  setChildren: (node) ->
    @children = {}
    edges = node.children.slice(0)
    if node.constructor.name == 'Call'
      edges = ['chain'].concat edges
    for edge in edges
      @children[edge] = []
      if node[edge]?
        if node[edge].length?
          if edge == 'cases'
            @processChildren(fixCases(node),edge)
          else
            @processChildren(node[edge],edge)
        else
          @processChild(node[edge],edge)
    return

  processChildren: (children,edge) ->
    for child in children
      @processChild(child,edge)

  processChild: (child,edge) ->
    if child.constructor.name == 'Block'
      if !(edge in ['recovery','ensure','elseBody'])
        @processChildren(child.expressions,edge)
        return
    if child.constructor.name == 'Obj'
      if child.generated
        @processChildren(child.properties,edge)
        return
    if child.constructor.name == 'Value'
      if child.base?.constructor.name in ['Arr','Obj','Parens']
        @processChild(child.base,edge)
        return
      else if child.base?.constructor.name == 'Call'
        stack.push child
        @processChild(child.base,edge)
        return
    if child.constructor.name == 'Parens'
      if child.body.expressions.length == 1
        @processChild(child.body.expressions[0],edge)
        return
    if child.constructor.name == 'Call'
      if child.variable?.base?.constructor.name == 'Call'
        stack.push child
        @processChild(child.variable.base,edge)
        return
      else if stack.length > 0
        child.chain = stack.pop()
        child.chain.variable?.base = []
        child.chain.base = []
    @createChild(child,edge)

  createChild: (child,edge) ->
    @children[edge].push new CoffeeMap child,edge,@collapse

  setOrder: (node) ->
    @nextPos = genPositioner()
    for edge in node.children
      for child in @children[edge]
        child.attr.edge += ':' + child.attr.order = @nextPos()
    if @children.chain?
      for child in @children.chain
        child.attr.edge += ':' + child.attr.order = @nextPos()

  process: (node) ->
    switch @attr.type
      when 'Access' #name
        @soak('name',true,'.')
        if @attr.value == '.prototype'
          @attr.value = '::'
      when 'Arr' #objects
        if @collapse
          if !@soak('objects',true,'[',', ',']')
            @attr.value = '[]'
        else
          if @children.objects.length == 0
            @attr.value = '[]'
          else @attr.value = '['
          @attr.classes.push 'keyword','operator'
        @attr.classes.push 'array'
        @attr.type = 'Array'
      when 'Assign' #value,variable,(context)
        node.context = switch node.context
          when 'object' then ':'
          when undefined then ' ='
          else ' ' + node.context
        if @soak('variable',false,'','',"#{node.context}")
          if @children.value[0]?.attr.type == 'Code'
            @attr.classes.push 'entity','name','function'
          else
            @attr.classes.push 'variable','assignment'
          if @collapse
            @soak('value',false,' ')

          #Exports
          assigns = @attr.value.split(' ')[0].split(':')[0].split('.')
          if assigns[0] == 'module' and assigns[1] == 'exports'
            if assigns.length > 2
              @attr.exports = assigns[2..].join('.')
            else
              for child in @children.value
                if child.attr.type == 'Class'
                  child.attr.exports = child.attr.value.split(' ')[1]
                else
                  child.attr.exports = child.attr.value.split(':')[0]

      when 'Bool' #(val)
        @attr.value = node.val
        @attr.classes.push 'constant','boolean'
        @attr.type = 'boolean'
      when 'Call' #args,variable,do; + caller
        if node.do
          @attr.value = 'do'
          @children.args = []
          @attr.classes.push 'keyword','control'
        else if @soak('variable',false,'','','(')
          if @attr.value.slice(0,1) == '@'
            @attr.classes.push 'variable','other','readwrite','instance'
          else
            @attr.classes.push 'support','function'
          @attr.classes.push 'call'
          if @collapse
            if @children.chain.length == 0
              close = ')'
            else close = ''
            @soak('args')
            @soak('chain')
            @attr.value += close
          else if @children.args.length == @children.chain.length == 0
            @attr.value += ')'

          #Imports
          if @attr.value.slice(0,7) == 'require'
            if exportPath = @children.args[0].attr.value[1..-2]
              if name = @children.chain[0]?.attr.value.split('.')[1]
                @children.chain[0].attr.imports =
                  path: exportPath
                  name: name
              else
                @children.args[0].attr.imports =
                  path: exportPath

      when 'Class' #variable,parent,body
        if @soak('variable',false,'class ')
          @soak('parent',false,' extends ')
          @attr.classes.push 'meta','class'
      when 'Code' #params,body,(bound)
        @soak('params',false,'(',',',')')
        if node.bound
          @attr.value += ' =>'
        else
          @attr.value += ' ->'
        @attr.classes.push 'variable','parameter'
      when 'Comment'
        @attr.classes.push 'comment'
      when 'Existence' #expression
        @soak('expression',true,'','','?')
      when 'Expansion'
        @attr.value = '...'
        @attr.classes.push 'keyword','operator'
      when 'For' #name,source,step,guard,body
        if @soak('source',false,"for#{node.name} in")
          @attr.classes.push 'keyword'
      when 'If' #condition,body,elseBody
        if @soak('condition',false,'if ')
          @attr.classes.push 'if','keyword'
          for child in @children.body
            child.attr.classes.push 'true'
        if @children.elseBody.length > 0
          @children.elseBody[0].attr.value = 'else'
          @children.elseBody[0].attr.classes.push 'else','keyword'
      when 'In' #object,array
        if @soak('object',false,'','',' in ')
          @soak('array')
        else
          @attr.value = 'in'
        @attr.classes.push 'keyword'
      when 'Index' #index
        @soak('index',false,'[','',']')
      when 'Literal' #(value)
        @attr.value = node.value
        if isNaN(Number(@attr.value))
          if @attr.value.slice(0,1) in ['"',"'"]
            @attr.classes.push 'string','quoted'
            @attr.type = 'string'
          else if @attr.value == 'this'
            @attr.value = '@'
            @attr.classes.push 'variable','instance'
            @attr.type = 'variable'
          else if @attr.value == 'break'
            @attr.classes.push 'keyword','control'
            @attr.type = 'Break'
          else
            @attr.classes.push 'variable','parameter'
            @attr.type = 'variable'
        else
          @attr.type = typeof Number @attr.value
          @attr.classes.push 'constant','numeric'
      when 'Null'
        @attr.value = 'null'
        @attr.type = 'Object'
      when 'Obj' #properties
        if !@soak('properties',false,'{',',','}')
          if @children.properties.length == 0
            @attr.value = '{}'
          else
            @attr.value = '{'
          @attr.classes.push 'keyword','operator'
          @attr.type = 'Object'
      when 'Op' #second,first,(operator)
        if node.operator == '&&' then operator = 'and'
        else if node.operator == '||' then operator = 'or'
        else operator = node.operator
        first = @children.first[0]
        second = @children.second[0]
        if @complex('first') or @complex('second')
          @attr.value = operator
          @attr.classes.push 'keyword','operator'
          #Stack multiple same operators
          if operator == first.attr.value and !@collapse
            first.children.second.push @children.second.pop()
            first.children.second.push first.children.second.pop()
            @children.second = first.children.second
            @children.first = first.children.first
        else
          @soak('first',true)
          if @children.second?
            @soak('second',true," #{operator} ")
          else
            @attr.value = "#{operator}#{@attr.value}"
          @attr.type = 'Expression'
      when 'Param' #value,name
        if @soak('name')
          if node.splat
            @attr.value += '...'
          @soak('value',false,'=')
      when 'Parens' #body
        @attr.value = '('
        @attr.classes.push 'keyword','operator'
      when 'Range' #from,to,(exclusive)
        dots = if node.exclusive then '...' else '..'
        @soak('from',true,'','',dots)
        @soak('to')
      when 'Return' #expression
        if !@soak('expression',false,'return ')
          @attr.value = 'return'
        @attr.classes.push 'keyword','control','return'
      when 'Slice' #range
        @soak('range',true,'[','',']')
      when 'Splat' #name
        @soak('name',true,'','','...')
      when 'Switch' #subject,cases,otherwise
        if @soak('subject',false,'switch ')
          @attr.classes.push 'switch','keyword'
        if @children.otherwise.length > 0
          @children.otherwise[0].attr.classes.push 'else'
      when 'Throw' #expression
        @soak('expression',false,'throw ')
        @attr.classes.push 'keyword'
      when 'Try' #attempt,recovery,ensure,(errorVariable)
        @attr.value = 'try'
        @attr.classes.push 'keyword'
        for child in @children.attempt
          child.attr.classes.push 'attempt'
        if @children.recovery.length > 0
          e = node.errorVariable?.value or ''
          @children.recovery[0].attr.value = "catch #{e}"
          @children.recovery[0].attr.classes.push 'recovery','keyword'
        if @children.ensure.length > 0
          @children.ensure[0].attr.value = "finally"
          @children.ensure[0].attr.classes.push 'ensure','keyword'
      when 'Undefined'
        @attr.value = 'undefined'
        @attr.type = 'undefined'
      when 'Value' #base,properties
        if @children.properties[0]?.attr.value == '::'
          @children.properties[1].attr.value = @children.properties[1].attr.value.slice(1)
        if @attr.edge == 'cases'
          @soak('base',false,'when ')
          @attr.classes.push 'keyword'
          @attr.type = 'Case'
        else if @soak('base',true)
          if !@soak('properties',false,'','')
            if @children.properties.length == 1 and @children.properties[0].attr.type == 'Index'
              @attr.value += '['
              @children.properties[0] = @children.properties[0].children.index[0]
          if @attr.value.slice(0,2) == '@.'
            @attr.value = "@#{@attr.value.slice(2)}"
        else if !@children.base[0]?
          @soak('properties',true,')','')
      when 'While' #condition,guard,body
        if @soak('condition',false,'while ')
          @attr.classes.push 'keyword'
      else @attr.value = @attr.type.toLowerCase()
    return

  complex: (edge) ->
    if edge?
      for child in @children[edge]
        if child.complex()
          return true
      return false
    else
      keys = Object.getOwnPropertyNames(@children)
      if keys.length == 0 then return false
      for key in keys
        if @children[key].length > 0
          return true
      return false

  soak: (edge,soakClasses,pre='',sep=',',post='') ->
    if @children[edge].length == 0 or @complex(edge) then return false
    values = []
    while @children[edge].length > 0
      child = @children[edge].pop()
      if soakClasses
        @attr.type = child.attr.type
        @attr.classes = @attr.classes.concat child.attr.classes
      values.push child.attr.value
    @attr.value += "#{pre}#{values.reverse().join(sep)}#{post}"
    return true

fixCases = (node) ->
  cases = []
  while node.cases.length > 0
    array = node.cases.pop()
    block = array.pop()
    values = array.pop()
    if values.length?
      while values.length > 1
        values[0].base.value += ',' + values.pop().base.value
        values = values[0]
    values.properties.push block
    cases.push values
  return cases.reverse()

sortById = (a,b) -> return a.id - b.id

class CoffeeLine
  constructor: (map,@level) ->
    @id = Number(map.id.split(':')[1])
    @line = Array(@level).join('\t')
    @line += map.value
    if map.attr.type == 'Call' and map.children.args?.length > 0
      @line.slice(-1,1)
    if map.attr.edge == 'args'
      @line += ', '
    else @line += ' '
    @append(map.children)
    @line += '\n'

  append: (children) ->
    edges = Object.getOwnPropertyNames(children)
    for edge in edges
      for child in children[edge]
        @line += child.value
        @append child.children

class CoffeeBlock
  constructor: (map,@level) ->
    if @level > 0
      @id = Number(map.id.split(':')[1])
      @type = map.attr.type
      if map.value == 'else'
        @level -= 1
      @line = Array(@level).join('\t')
      @line += map.value
      @line += '\n'
    @getChildren(map.children)
    @combineLines()

  getChildren: (children) ->
    @children = []
    edges = Object.getOwnPropertyNames(children)
    for edge in edges
      for child in children[edge]
        if child.attr.type == 'Assign' and child.children.value[0].attr.type == 'Code'
          child.children.value[0].value = child.value + ' ' + child.children.value[0].value
          @children.push new CoffeeBlock child.children.value[0],@level + 1
        else if child.attr.type == 'Assign' and child.children.value[0].attr.type == 'Assign'
          @children.push new CoffeeBlock child,@level + 1
        else if child.attr.type in ['If','Switch','For','Case','Code','Block','While','Class','Object']
          @children.push new CoffeeBlock child,@level + 1
        else
          @children.push new CoffeeLine child,@level + 1

  combineLines: () ->
    @text = @line or ''
    @children.sort(sortById)
    for child in @children
      if child.text?
        @text += child.text
      else
        @text += child.line
