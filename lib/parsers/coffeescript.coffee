{nodes} = require 'coffee-script'

genIdCounter = (prefix) ->
  currentId = 0
  nextId = () -> prefix + ':' + (currentId += 1)

stack = []

module.exports =
  parse: (prefix,text) ->
    root.AST = AST = nodes text
    nextId = genIdCounter(prefix)
    map = new CoffeeNode(AST, 'file', nextId, false)
    map._value = @path
    return map

class CoffeeNode
  constructor: (node,edge,@nextId,@collapse) ->
    @_id = @nextId()
    @_attr =
      edge: edge
      type: node.constructor.name
      classes: ['coffee']
    @_value = ''
    @setCollapse(edge)
    @getChildren(node)
    @process(node)

  process: (node) ->
    switch @_attr.type
      when 'Access' #name
        @soak('name',true,'.')
        if @_value == '.prototype'
          @_value = '::'
      when 'Arr' #objects
        if @collapse
          if !@soak('objects',true,'[',', ',']')
            @_value = '[]'
        else
          if @_children.objects.length == 0
            @_value = '[]'
          else @_value = '['
          @_attr.classes.push 'keyword','operator'
        @_attr.classes.push 'array'
        @_attr.type = 'Array'
      when 'Assign' #value,variable,(context)
        node.context = switch node.context
          when 'object' then ':'
          when undefined then ' ='
          else ' ' + node.context
        if @soak('variable',false,'','',"#{node.context}")
          if @_children.value[0]?._attr.type == 'Code'
            @_attr.classes.push 'entity','name','function'
          else
            @_attr.classes.push 'variable','assignment'
        if @collapse
          @soak('value',false,' ')
      when 'Bool' #(val)
        @_value = node.val
        @_attr.classes.push 'constant','boolean'
        @_attr.type = 'boolean'
      when 'Call' #args,variable; + caller
        if @soak('variable',false,'','','(')
          if @_value.slice(0,1) == '@'
            @_attr.classes.push 'variable','other','readwrite','instance'
          else
            @_attr.classes.push 'support','function'
          @_attr.classes.push 'call'
          if @_children.args.length == 0
            @_value += ')'
          else if @collapse
            @soak('args',false,'',',',')')
        else if !@_children.variable[0]?
          @soak('properties',true,')','')
      when 'Class' #variable,parent,body
        if @soak('variable',false,'class ')
          @soak('parent',false,' extends ')
          @_attr.classes.push 'meta','class'
      when 'Code' #params,body,(bound)
        @soak('params',false,'(',',',')')
        if node.bound
          @_value += ' =>'
        else
          @_value += ' ->'
        @_attr.classes.push 'variable','parameter'
      when 'Comment'
        @_attr.classes.push 'comment'
      when 'Existence' #expression
        @soak('expression',true,'','','?')
      when 'Expansion'
        @_value = '...'
        @_attr.classes.push 'keyword','operator'
      when 'For' #name,source,step,guard,body
        if @soak('source',false,"for#{node.name} in ")
          @_attr.classes.push 'keyword'
      when 'If' #condition,body,elseBody
        if @soak('condition',false,'if ')
          @_attr.classes.push 'if','keyword'
          for child in @_children.body
            child._attr.classes.push 'true'
        if @_children.elseBody.length > 0
          @_children.elseBody[0]._value = 'else'
          @_children.elseBody[0]._attr.classes.push 'else','keyword'
      when 'In' #object,array
        if @soak('object',false,'','',' in')
          @soak('array')
        else
          @_value = 'in'
        @_attr.classes.push 'keyword'
      when 'Index' #index
        @soak('index',true,'[','',']')
      when 'Literal' #(value)
        @_value = node.value
        if isNaN(Number(@_value))
          if @_value.slice(0,1) in ['"',"'"]
            @_attr.classes.push 'string','quoted'
            @_attr.type = 'string'
          else if @_value == 'this'
            @_value = '@'
            @_attr.classes.push 'variable','instance'
            @_attr.type = 'variable'
          else if @_value == 'break'
            @_attr.classes.push 'keyword','control'
            @_attr.type = 'Break'
          else
            @_attr.classes.push 'variable','parameter'
            @_attr.type = 'variable'
        else
          @_attr.type = typeof Number @_value
          @_attr.classes.push 'constant','numeric'
      when 'Null'
        @_value = 'null'
        @_attr.type = 'Object'
      when 'Obj' #properties
        if !@soak('properties',false,'{',',','}')
          if @_children.properties.length == 0
            @_value = '{}'
          else
            @_value = '{'
          @_attr.classes.push 'keyword','operator'
          @_attr.type = 'Object'
      when 'Op' #second,first,(operator)
        if node.operator == '&&' then operator = 'and'
        else if node.operator == '||' then operator = 'or'
        else operator = node.operator
        first = @_children.first[0]
        second = @_children.second[0]
        if @complex('first') or @complex('second')
          @_value = operator
          @_attr.classes.push 'keyword','operator'
          #Stack multiple same operators
          if operator == first._value and !@collapse
            first._children.second.push @_children.second.pop()
            first._children.second.push first._children.second.pop()
            @_children.second = first._children.second
            @_children.first = first._children.first
        else
          @soak('first',true)
          if @_children.second?
            @soak('second',true," #{operator} ")
          else
            @_value = "#{operator}#{@_value}"
          @_attr.type = 'Expression'
      when 'Param' #value,name
        if @soak('name')
          if node.splat
            @_value += '...'
          @soak('value',false,'=')
      when 'Parens' #body
        @_value = '('
        @_attr.classes.push 'keyword','operator'
      when 'Range' #from,to,(exclusive)
        dots = if node.exclusive then '...' else '..'
        @soak('from',true,'','',dots)
        @soak('to')
      when 'Return' #expression
        if !@soak('expression',false,'return ')
          @_value = 'return'
        @_attr.classes.push 'keyword','control','return'
      when 'Slice' #range
        @soak('range',true,'[','',']')
      when 'Splat' #name
        @soak('name',true,'','','...')
      when 'Switch' #subject,cases,otherwise
        if @soak('subject',false,'switch ')
          @_attr.classes.push 'switch','keyword'
      when 'Throw' #expression
        @soak('expression',false,'throw ')
        @_attr.classes.push 'keyword'
      when 'Try' #attempt,recovery,ensure,(errorVariable)
        @_value = 'try'
        @_attr.classes.push 'keyword'
        for child in @_children.attempt
          child._attr.classes.push 'attempt'
        if @_children.recovery.length > 0
          e = node.errorVariable?.value or ''
          @_children.recovery[0]._value = "catch #{e}"
          @_children.recovery[0]._attr.classes.push 'recovery','keyword'
        if @_children.ensure.length > 0
          @_children.ensure[0]._value = "finally"
          @_children.ensure[0]._attr.classes.push 'ensure','keyword'
      when 'Undefined'
        @_value = 'undefined'
        @_attr.type = 'undefined'
      when 'Value' #base,properties
        if @_children.properties[0]?._value == '::'
          @_children.properties[1]._value = @_children.properties[1]._value.slice(1)
        if @_attr.edge == 'cases'
          @soak('base',false,'when ')
          @_attr.classes.push 'keyword'
          @_attr.type = 'Case'
        else if @soak('base',true)
          if !@soak('properties',false,'','')
            if @_children.properties.length == 1 and @_children.properties[0]._attr.type == 'Index'
              @_value += '['
              @_children.properties[0] = @_children.properties[0]._children.index[0]
          if @_value.slice(0,2) == '@.'
            @_value = "@#{@_value.slice(2)}"
        else if !@_children.base[0]?
          @soak('properties',true,')','')
      when 'While' #condition,guard,body
        if @soak('condition',false,'while ')
          @_attr.classes.push 'keyword'
      else @_value = @_attr.type.toLowerCase()
    return

  complex: (edge) ->
    if edge?
      for child in @_children[edge]
        if child.complex()
          return true
      return false
    else
      keys = Object.getOwnPropertyNames(@_children)
      if keys.length == 0 then return false
      for key in keys
        if @_children[key].length > 0
          return true
      return false

  soak: (edge,soakClasses,pre='',sep=',',post='') ->
    if @_children[edge].length == 0 or @complex(edge) then return false
    values = []
    while @_children[edge].length > 0
      child = @_children[edge].pop()
      if soakClasses
        @_attr.type = child._attr.type
        @_attr.classes = @_attr.classes.concat child._attr.classes
      values.push child._value
    @_value += "#{pre}#{values.reverse().join(sep)}#{post}"
    return true

  setCollapse: (edge) ->
    if edge in ['condition','source','expression','index']
      @collapse = true

  getChildren: (node) ->
    @_children = {}
    edges = node.children.slice(0)
    if node.constructor.name == 'Call'
      edges = ['chain'].concat edges
    for edge in edges
      @_children[edge] = []
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
    @_children[edge].push new CoffeeNode(child,edge,@nextId,@collapse)

fixCases = (node) ->
  cases = []
  while node.cases.length > 0
    array = node.cases.pop()
    block = array.pop()
    value = array.pop()
    value.properties.push block
    cases.push value
  return cases.reverse()

# clone = (x) ->
#   y = x.constructor()
#   y[x.constructor.name] = x
#   JSON.parse JSON.stringify(y)
