esprima = require('../../js/esprima.js')

module.exports =
  parse: (prefix,text) ->
    dfd = $.Deferred()
    AST = esprima.parse(text)
    map = new JavascriptMap(AST, 'file', false)
    map.attr.root = true
    map.attr.value = prefix
    setIds(prefix,map)
    dfd.resolve map
    return dfd.promise()

  deparse: (map) ->
    jsText = map2js map,0,''
    return jsText

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

class JavascriptMap
  constructor: (node,edge,@collapse) ->
    @attr =
      value: ''
      edge: edge
      type: node.type
      classes: ['javascript']
    #@setCollapse(edge)
    @setChildren(node)
    @process(node)
    @setOrder(node)

  setCollapse: (edge) ->
    if edge in []
      @collapse = true

  setChildren: (node) ->
    @children = {}
    edges = Object.getOwnPropertyNames(childrenProperties)
    if @attr.type in edges
      for edge in childrenProperties[@attr.type]
        @children[edge] = []
        if node[edge]?
          if node[edge].constructor?.name == 'Array'
            @processChildren(node[edge],edge)
          else
            @processChild(node[edge],edge)
    return
  processChildren: (children,edge) ->
    for child in children
      @processChild(child,edge)
  processChild: (child,edge) ->
    if child.type == 'ExpressionStatement'
      @createChild(child.expression,edge)
      return
    @createChild(child,edge)
  createChild: (child,edge) ->
    @children[edge].push new JavascriptMap(child,edge,@collapse)

  setOrder: (node) ->
    @nextPos = genPositioner()
    edges = Object.getOwnPropertyNames(childrenProperties)
    if @attr.type in edges
      for edge in childrenProperties[@attr.type]
        for child in @children[edge]
          child.attr.edge += ':' + child.attr.order = @nextPos()
      if @children.chain?
        for child in @children.chain
          child.attr.edge += ':' + child.attr.order = @nextPos()

  process: (node,edge) ->
    switch @attr.type
      when 'AssignmentExpression'
        if @soak 'left'
          @soak 'operator',false,' ','',' '
        @attr.classes.push 'assignment'
      when 'BinaryExpression','LogicalExpression'
        if @soak 'left'
          if @soak 'operator',false,' ','',' '
            @soak 'right'
      when 'BlockStatement'
        @attr.value = '{'
      when 'CallExpression'
        @soak 'callee',false,'','','('
        @attr.classes.push 'call'
      when 'CatchClause'
        @soak 'param',false,'catch(','',')'
      when 'ConditionalExpression'
        @soak 'test'
      when 'FunctionDeclaration'
        @soak 'id',false,'function '
        @children.generator.pop()
        @children.expression.pop()
        @attr.classes.push 'name'
      when 'Identifier'
        @soak 'name',true
      when 'IfStatement'
        @soak 'test',false,'if (','',')'
        @attr.classes.push 'keyword','control'
      when 'Literal'
        @soak 'raw',true
        @children.value.pop()
      when 'MemberExpression'
        @soak 'object'
        @soak 'property',false,'.','.'
        @children.computed.pop()
      when 'ObjectExpression'
        if @children.properties?.length > 0
          @attr.value = '{'
        else
          @attr.value = '{}'
      when 'Property'
        @soak 'key',false,'','',':'
        @children.computed.pop()
        @children.kind.pop()
        @children.method.pop()
        @children.shorthand.pop()
        @attr.classes.push ''
      when 'ReturnStatement'
        @soak 'argument','false','return '
        @attr.classes.push 'return'
      when 'UnaryExpression'
        @soak 'operator',false,'','',' '
        @soak 'argument'
        @children.prefix.pop()
      when 'VariableDeclaration'
        @soak 'kind'
        @attr.classes.push 'keyword'
      when 'VariableDeclarator'
        @soak 'id'
      when 'ThrowStatement'
        @soak 'argument',false,'throw '
      when 'TryStatement'
        @attr.value = 'try'
        @children.handler.pop()
        @attr.classes.push 'attempt'
      else
        if @attr.type?
          @attr.value = @attr.type
        else
          @attr.value = node.toString()
          if isNaN(Number(@attr.value))
            if @attr.value.slice(0,1) in ['"',"'"]
              @attr.classes.push 'string','quoted'
              @attr.type = 'String'
            else if @attr.value == 'this'
              @attr.classes.push 'variable','instance'
              @attr.type = 'Variable'
            else
              @attr.classes.push 'variable','parameter'
              @attr.type = 'Variable'
          else
            @attr.type = typeof Number @attr.value
            @attr.classes.push 'constant','numeric'
    return

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

order = (a,b) -> return a.attr.order - b.attr.order

map2js = (map,level,text) ->
  sameLine =
    edge: [
      'right'
      'declarations'
      'consequent'
      'alternate'
      'value'
    ]
    type: []
  indent = (force,adjust) =>
    lvl = level + (adjust or 0)
    if !force and
    (map.attr.edge.split(':')[0] in sameLine.edge or
    map.attr.type in sameLine.type)
      return ' '
    else
      return '\n' + Array(lvl).join('\t')

  text += indent() + map.attr.value
  edges = Object.getOwnPropertyNames(map.children)
  children = []
  for edge in edges
    for child in map.children[edge]
      children.push child
  children.sort(order)
  for child in children
    text = map2js(child,level+1,text)
    if map.attr.type == 'BlockStatement' and text.slice(-1,1) != '}'
      text += ';'
  if map.attr.value == '{'
    text += indent(true,-1) + '}'
  return text

childrenProperties =
  ArrayExpression: ['elements']
  ArrayPattern: ['elements']
  ArrowFunctionExpression: ['id','params','defaults','body','generator','expression']
  AssignmentExpression: ['operator','left','right']
  AssignmentPattern: ['left','right']
  LogicalExpression: ['operator','left','right']
  BinaryExpression: ['operator','left','right']
  BlockStatement: ['body']
  BreakStatement: ['label']
  CallExpression: ['callee','arguments']
  CatchClause: ['param','body']
  ClassBody: ['body']
  ClassDeclaration: ['id','superClass','body']
  ClassExpression: ['id','superClass','body']
  ConditionalExpression: ['test','consequent','alternate']
  ContinueStatement: ['label']
  DebuggerStatement: []
  DoWhileStatement: ['body','test']
  EmptyStatement: []
  ExpressionStatement: ['expression']
  ForStatement: ['init','test','update','body']
  ForOfStatement: ['left','right','body']
  ForInStatement: ['left','right','body','each']
  FunctionDeclaration: ['id','params','defaults','body','generator','expression']
  FunctionExpression: ['id','params','defaults','body','generator','expression']
  Identifier: ['name']
  IfStatement: ['test','consequent','alternate']
  LabeledStatement: ['label','body']
  Literal: ['value','raw','regex']
  MemberExpression: ['computed','object','property']
  MetaProperty: ['meta','property']
  NewExpression: ['callee','arguments']
  ObjectExpression: ['properties']
  ObjectPattern: ['properties']
  UpdateExpression: ['operator','argument','prefix']
  Program: ['body','sourceType']
  Property: ['key','computed','value','kind','method','shorthand']
  RestElement: ['argument']
  ReturnStatement: ['argument']
  SequenceExpression: ['expressions']
  SpreadElement: ['argument']
  SwitchCase: ['test','consequent']
  Super: []
  SwitchStatement: ['discriminant','cases']
  TaggedTemplateExpression: ['tag','quasi']
  TemplateElement: ['value','tail']
  TemplateLiteral: ['quasis','expressions']
  ThisExpression: []
  ThrowStatement: ['argument']
  TryStatement: ['block','guardedHandlers','handlers','handler','finalizer']
  UnaryExpression: ['operator','argument','prefix']
  UpdateExpression: ['operator','argument','prefix']
  VariableDeclaration: ['declarations','kind']
  VariableDeclarator: ['id','init']
  WhileStatement: ['test','body']
  WithStatement: ['object','body']
  ExportSpecifier: ['exported','local']
  ImportDefaultSpecifier: ['local']
  ImportNamespaceSpecifier: ['local']
  ExportNamedDeclaration: ['declaration','specifiers','source']
  ExportDefaultDeclaration: ['declaration']
  ExportAllDeclaration: ['source']
  ImportSpecifier: ['local','imported']
  ImportDeclaration: ['specifiers','source']
  YieldExpression: ['argument','delegate']
