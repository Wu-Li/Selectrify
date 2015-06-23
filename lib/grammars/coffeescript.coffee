{nodes} = require 'coffee-script'

class Map
  constructor: (node,@edge,@id,@path,@collapse) ->
    @type = node.constructor.name
    if @type == 'Array' then fixArray(node)
    if @edge == 1 then @edge = 'body'
    @classes = ['coffee']
    @children = @getChildren(node)
    @scope = @path
    @value = ''
    @process(node)
    if !@value then @value = @type

  process: (node,literalsOnly) ->
    if literalsOnly and @type != 'Literal' then return
    switch @type
      when 'Access' #name
        @soak('name',false,'.')
        if @value == '.prototype'
          @value = '::'
      when 'Arr' #objects
        if @collapse
          if !@soak('objects',true,'[',', ',']')
            @value = '[]'
        else
          @value = '['
          @classes.push 'keyword','operator'
        @classes.push 'array'
      when 'Array' #0,1
        if @soak('0',false,'when ')
          @classes.push 'keyword'
      when 'Assign' #value,variable,(context)
        node.context = switch node.context
          when 'object' then ':'
          when undefined then ' ='
          else ' ' + node.context
        if @soak('variable',false,'','',"#{node.context}")
          if @children.value[0].type == 'Code'
            @classes.push 'entity','name','function'
          else
            @classes.push 'variable','assignment'
        if @collapse
          @soak('value',false,' ')
      when 'Bool' #(val)
        @value = node.val
        @classes.push 'constant','boolean'
      when 'Call' #args,variable; + caller
        if @soak('variable',true,'','','(')
          if @value.slice(0,1) == '@'
            @classes.push 'variable','other','readwrite','instance'
          else
            @classes.push 'support','function'
          @classes.push 'call'
          if @children.args.length == 0
            @value += ')'
          else if @collapse
            @soak('args',false,'',',',')')
        else if @children.variable?[0]?.children.base?[0]?
          @value = ')' + @children.variable[0].value + '('
          @classes.push 'call','support','function'
          @children.variable[0] = @children.variable[0].children.base[0]
          @children.variable[0].children.args = swap(@children.args,@children.args = @children.variable[0].children.args)
          @children.variable[0].value = swap(@value,@value=@children.variable[0].value)
          @children.variable[0].edge = 'then'
      when 'Class' #variable,parent,body
        if @soak('variable',false,'class ')
          @soak('parent',false,' extends ')
          @classes.push 'meta','class'
      when 'Code' #params,body,(bound)
        @soak('params',false,'(',',',')')
        if node.bound
          @value += ' =>'
        else
          @value += ' ->'
        @classes.push 'variable','parameter'
      when 'Comment'
        @classes.push 'comment'
      when 'Existence' #expression
        @soak('expression',true,'','','?')
      when 'Expansion'
        @value = '...'
        @classes.push 'keyword','operator'
      when 'For' #name,source,step,guard,body
        if @soak('source',false,"for#{node.name} in ")
          @classes.push 'keyword','control'
      when 'If' #condition,body,elseBody
        if @soak('condition',false,'if ')
          @classes.push 'if','keyword','control'
          for child in @children.body
            child.classes.push 'true'
        if @children.elseBody.length > 0
          @children.elseBody[0].value = 'else'
          @children.elseBody[0].classes.push 'else','keyword'
      when 'In' #object,array
        if object = @soak('object')
          @soak('array',false,' in ')
      when 'Index' #index
        @soak('index',true,'[','',']')
      when 'Literal' #(value)
        @value = node.value
        if isNaN(Number(@value))
          if @value.slice(0,1) in ['"',"'"]
            @classes.push 'string','quoted'
          else if @value == 'this'
            @value = '@'
            @classes.push 'variable','instance'
          else if @value == 'break'
            @classes.push 'keyword','control'
          else
            @classes.push 'variable','parameter'
        else
          @classes.push 'constant','numeric'
      when 'Obj' #properties
        if !@soak('properties',false,'{',',','}')
          @value = '{}'
          @classes.push 'keyword','operator'
      when 'Op' #second,first,(operator)
        if @soak('first',true)
          if !@soak('second',false," #{node.operator} ")
            @value = "#{node.operator}#{@value}"
        else
          @value = node.operator
          @classes.push 'keyword','operator'
      when 'Param' #value,name
        if @soak('name')
          if node.splat
            @value += '...'
          @soak('value',false,'=')
      when 'Parens' #body
        if !@soak('body',true,'(','',')')
          @value = '('
          @classes.push 'keyword','operator'
      when 'Range' #from,to,(exclusive)
        dots = if node.exclusive then '...' else '..'
        @soak('from',true,'','',dots)
        @soak('to')
      when 'Return' #expression
        if !@soak('expression',false,'return ')
          @value = 'return'
        @classes.push 'keyword','control','return'
      when 'Slice' #range
        @soak('range',true,'[','',']')
      when 'Splat' #name
        @soak('name',true,'','','...')
      when 'Switch' #subject,cases,otherwise
        if @soak('subject',false,'switch ')
          @classes.push 'switch','keyword','control'
      when 'Throw' #expression
        @soak('expression',false,'throw ')
        @classes.push 'keyword'
      when 'Try' #attempt,recovery,ensure,(errorVariable)
        @value = 'try'
        @classes.push 'keyword','control'
        for child in @children.attempt
          child.classes.push 'attempt'
        if @children.recovery.length > 0
          e = node.errorVariable?.value or ''
          @children.recovery[0].value = "catch #{e}"
          @children.recovery[0].classes.push 'recovery','keyword'
        if @children.ensure.length > 0
          @children.ensure[0].value = "finally"
          @children.ensure[0].classes.push 'ensure','keyword'
      when 'Value' #base,properties
        if @children.properties[0]?.value == '::'
          @children.properties[1].value = @children.properties[1].value.slice(1)
        if @soak('base',true)
          @soak('properties',false,'','')
          if @value.slice(0,2) == '@.'
            @value = "@#{@value.slice(2)}"
        else if @children.base[0].type == 'Call'
          @soak('properties')
      when 'While' #condition,guard,body
        if @soak('condition',false,'while ')
          @classes.push 'keyword','control'
      else @value = @type.toLowerCase()
    return

  complex: (edge) ->
    if !edge
      keys = Object.getOwnPropertyNames(@children)
      if keys.length == 0 then return false
      for key in keys
        if @children[key].length > 0
          return true
      return false
    else
      for child in @children[edge]
        if child.complex()
          return true
      return false

  soak: (edge,classes,pre='',sep=',',post='') ->
    if @children[edge].length == 0 or @complex(edge) then return false
    values = []
    while @children[edge].length > 0
      child = @children[edge].pop()
      if classes then @classes = @classes.concat child.classes
      values.push child.value
    @value += "#{pre}#{values.reverse().join(sep)}#{post}"
    return true

  getCollapse: (edge) ->
    if @collapse or edge in ['condition','source','expression']
      return true
    else return false

  getChildren: (node) ->
    children = {}
    if node.constructor.name == 'Call' and node.variable?.base?.constructor.name == 'Call'
      node.children = ['args','variable']
    for edge in node.children
      children[edge] = []
      for childNode in childNodes(node[edge],edge)
        children[edge].push new Map(childNode,edge,nextId(),".#{@id}#{@path}",@getCollapse(edge))
    return children

root.calls = []
childNodes = (node,edge) ->
  if node?
    if node.length?
      if node.length == 1
        return childNodes(node[0])
      return node
    else
      if node.constructor.name == 'Block'
        if edge in ['recovery','ensure','elseBody']
          return [node]
        return childNodes(node.expressions)
      if node.constructor.name == 'Value'
        if node.base.constructor.name in ['Obj','Parens','Arr']
          return childNodes(node.base)
      return [node]
  return []

swap = (x) -> return x

fixArray = (node) ->
  node.children = [0,1]
  node.isComplex = -> return true

nextId = () -> return chemist.cid += 1

module.exports =
  parse: (text) ->
    root.AST = AST = nodes text
    chemist.cid = 0
    map = new Map(AST, 'file', nextId(),'')
    map.value = @title
    return map
