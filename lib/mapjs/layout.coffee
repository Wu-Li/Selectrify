MAPJS.defaultStyles = {}

MAPJS.layoutLinks = (idea, visibleNodes) ->
  'use strict'
  result = {}
  _.each idea.links, (link) ->
    if visibleNodes[link.ideaIdFrom] and visibleNodes[link.ideaIdTo]
      result[link.ideaIdFrom + '_' + link.ideaIdTo] =
        ideaIdFrom: link.ideaIdFrom
        ideaIdTo: link.ideaIdTo
        attr: _.clone(link.attr)
      #todo - clone
    return
  result

MAPJS.calculateFrame = (nodes, margin) ->
  'use strict'
  margin = margin or 0
  result =
    top: _.min(nodes, (node) ->
      node.y
    ).y - margin
    left: _.min(nodes, (node) ->
      node.x
    ).x - margin
  result.width = margin + _.max(_.map(nodes, (node) ->
    node.x + node.width
  )) - (result.left)
  result.height = margin + _.max(_.map(nodes, (node) ->
    node.y + node.height
  )) - (result.top)
  result

MAPJS.contrastForeground = (background) ->
  luminosity = Color(background).luminosity()
  if luminosity < 0.5
    return '#EEEEEE'
  if luminosity < 0.9
    return '#4F4F4F'
  '#000000'

MAPJS.Outline = (topBorder, bottomBorder) ->
  'use strict'

  shiftBorder = (border, deltaH) ->
    _.map border, (segment) ->
      {
        l: segment.l
        h: segment.h + deltaH
      }

  @initialHeight = ->
    @bottom[0].h - (@top[0].h)

  @borders = ->
    _.pick this, 'top', 'bottom'

  @spacingAbove = (outline) ->
    i = 0
    j = 0
    result = 0
    li = 0
    lj = 0
    while i < @bottom.length and j < outline.top.length
      result = Math.max(result, @bottom[i].h - (outline.top[j].h))
      if li + @bottom[i].l < lj + outline.top[j].l
        li += @bottom[i].l
        i += 1
      else if li + @bottom[i].l == lj + outline.top[j].l
        li += @bottom[i].l
        i += 1
        lj += outline.top[j].l
        j += 1
      else
        lj += outline.top[j].l
        j += 1
    result

  @indent = (horizontalIndent, margin) ->
    if !horizontalIndent
      return this
    top = @top.slice()
    bottom = @bottom.slice()
    vertCenter = (bottom[0].h + top[0].h) / 2
    top.unshift
      h: vertCenter - (margin / 2)
      l: horizontalIndent
    bottom.unshift
      h: vertCenter + margin / 2
      l: horizontalIndent
    new (MAPJS.Outline)(top, bottom)

  @stackBelow = (outline, margin) ->
    spacing = outline.spacingAbove(this)
    top = MAPJS.Outline.extendBorder(outline.top, shiftBorder(@top, spacing + margin))
    bottom = MAPJS.Outline.extendBorder(shiftBorder(@bottom, spacing + margin), outline.bottom)
    new (MAPJS.Outline)(top, bottom)

  @expand = (initialTopHeight, initialBottomHeight) ->
    topAlignment = initialTopHeight - (@top[0].h)
    bottomAlignment = initialBottomHeight - (@bottom[0].h)
    top = shiftBorder(@top, topAlignment)
    bottom = shiftBorder(@bottom, bottomAlignment)
    new (MAPJS.Outline)(top, bottom)

  @insertAtStart = (dimensions, margin) ->
    `var bottomBorder`
    `var topBorder`
    alignment = 0
    topBorder = shiftBorder(@top, alignment)
    bottomBorder = shiftBorder(@bottom, alignment)

    easeIn = (border) ->
      border[0].l *= 0.5
      border[1].l += border[0].l
      return

    topBorder[0].l += margin
    bottomBorder[0].l += margin
    topBorder.unshift
      h: -0.5 * dimensions.height
      l: dimensions.width
    bottomBorder.unshift
      h: 0.5 * dimensions.height
      l: dimensions.width
    if topBorder[0].h > topBorder[1].h
      easeIn topBorder
    if bottomBorder[0].h < bottomBorder[1].h
      easeIn bottomBorder
    new (MAPJS.Outline)(topBorder, bottomBorder)

  @top = topBorder.slice()
  @bottom = bottomBorder.slice()
  return

MAPJS.Outline.borderLength = (border) ->
  'use strict'
  _.reduce border, ((seed, el) ->
    seed + el.l
  ), 0

MAPJS.Outline.borderSegmentIndexAt = (border, length) ->
  'use strict'
  l = 0
  i = -1
  while l <= length
    i += 1
    if i >= border.length
      return -1
    l += border[i].l
  i

MAPJS.Outline.extendBorder = (originalBorder, extension) ->
  'use strict'
  result = originalBorder.slice()
  origLength = MAPJS.Outline.borderLength(originalBorder)
  i = MAPJS.Outline.borderSegmentIndexAt(extension, origLength)
  lengthToCut = undefined
  if i >= 0
    lengthToCut = MAPJS.Outline.borderLength(extension.slice(0, i + 1))
    result.push
      h: extension[i].h
      l: lengthToCut - origLength
    result = result.concat(extension.slice(i + 1))
  result

MAPJS.Tree = (options) ->
  'use strict'
  _.extend this, options

  @toLayout = (x, y, parentId) ->
    x = x or 0
    y = y or 0
    result =
      nodes: {}
      connectors: {}
    self = undefined
    self = _.pick(this, 'id', 'title', 'attr', 'width', 'height', 'level')
    if self.level == 1
      self.x = -0.5 * @width
      self.y = -0.5 * @height
    else
      self.x = x + @deltaX or 0
      self.y = y + @deltaY or 0
    result.nodes[@id] = self
    if parentId != undefined
      result.connectors[self.id] =
        from: parentId
        to: self.id
    if @subtrees
      @subtrees.forEach (t) ->
        subLayout = t.toLayout(self.x, self.y, self.id)
        _.extend result.nodes, subLayout.nodes
        _.extend result.connectors, subLayout.connectors
        return
    result

  return

MAPJS.Outline.fromDimensions = (dimensions) ->
  'use strict'
  new (MAPJS.Outline)([ {
    h: -0.5 * dimensions.height
    l: dimensions.width
  } ], [ {
    h: 0.5 * dimensions.height
    l: dimensions.width
  } ])

MAPJS.calculateTree = (content, dimensionProvider, margin, rankAndParentPredicate, level) ->
  'use strict'
  options =
    id: content.id
    title: content.title
    attr: content.attr
    deltaY: 0
    deltaX: 0
    level: level or 1

  setVerticalSpacing = (treeArray, dy) ->
    i = undefined
    tree = undefined
    oldSpacing = undefined
    newSpacing = undefined
    oldPositions = _.map(treeArray, (t) ->
      _.pick t, 'deltaX', 'deltaY'
    )
    referenceTree = undefined
    alignment = undefined
    i = 0
    while i < treeArray.length
      tree = treeArray[i]
      if tree.attr and tree.attr.position
        tree.deltaY = tree.attr.position[1]
        if referenceTree == undefined or tree.attr.position[2] > treeArray[referenceTree].attr.position[2]
          referenceTree = i
      else
        tree.deltaY += dy
      if i > 0
        oldSpacing = oldPositions[i].deltaY - (oldPositions[i - 1].deltaY)
        newSpacing = treeArray[i].deltaY - (treeArray[i - 1].deltaY)
        if newSpacing < oldSpacing
          tree.deltaY += oldSpacing - newSpacing
      i += 1
    alignment = referenceTree and treeArray[referenceTree].attr.position[1] - (treeArray[referenceTree].deltaY)
    if alignment
      i = 0
      while i < treeArray.length
        treeArray[i].deltaY += alignment
        i += 1
    return

  shouldIncludeSubIdeas = ->
    !(_.isEmpty(content.ideas) or content.attr and content.attr.collapsed)

  includedSubIdeaKeys = ->
    allRanks = _.map(_.keys(content.ideas), parseFloat)
    includedRanks = if rankAndParentPredicate then _.filter(allRanks, ((rank) ->
      rankAndParentPredicate rank, content.id
    )) else allRanks
    _.sortBy includedRanks, Math.abs

  includedSubIdeas = ->
    result = []
    _.each includedSubIdeaKeys(), (key) ->
      result.push content.ideas[key]
      return
    result

  nodeDimensions = dimensionProvider(content, options.level)

  appendSubtrees = (subtrees) ->
    suboutline = undefined
    deltaHeight = undefined
    subtreePosition = undefined
    horizontal = undefined
    treeOutline = undefined
    _.each subtrees, (subtree) ->
      subtree.deltaX = nodeDimensions.width + margin
      subtreePosition = subtree.attr and subtree.attr.position and subtree.attr.position[0]
      if subtreePosition and subtreePosition > subtree.deltaX
        horizontal = subtreePosition - (subtree.deltaX)
        subtree.deltaX = subtreePosition
      else
        horizontal = 0
      if !suboutline
        suboutline = subtree.outline.indent(horizontal, margin)
      else
        treeOutline = subtree.outline.indent(horizontal, margin)
        deltaHeight = treeOutline.initialHeight()
        suboutline = treeOutline.stackBelow(suboutline, margin)
        subtree.deltaY = suboutline.initialHeight() - (deltaHeight / 2) - (subtree.height / 2)
      return
    if subtrees and subtrees.length
      setVerticalSpacing subtrees, 0 * (nodeDimensions.height - suboutline.initialHeight())
      suboutline = suboutline.expand(subtrees[0].deltaY - (nodeDimensions.height * 0.5), subtrees[subtrees.length - 1].deltaY + subtrees[subtrees.length - 1].height - (nodeDimensions.height * 0.5))
    options.outline = suboutline.insertAtStart(nodeDimensions, margin)
    return

  _.extend options, nodeDimensions
  options.outline = new (MAPJS.Outline.fromDimensions)(nodeDimensions)
  if shouldIncludeSubIdeas()
    options.subtrees = _.map(includedSubIdeas(), (i) ->
      MAPJS.calculateTree i, dimensionProvider, margin, rankAndParentPredicate, options.level + 1
    )
    if !_.isEmpty(options.subtrees)
      appendSubtrees options.subtrees
  new (MAPJS.Tree)(options)

MAPJS.calculateLayout = (idea, dimensionProvider, margin) ->
  'use strict'
  positiveTree = undefined
  negativeTree = undefined
  layout = undefined
  negativeLayout = undefined

  setDefaultStyles = (nodes) ->
    _.each nodes, (node) ->
      node.attr = node.attr or {}
      node.style = _.extend({}, MAPJS.defaultStyles[if node.level == 1 then 'root' else 'nonRoot'], node.style)
      return
    return

  positive = (rank, parentId) ->
    parentId != idea.id or rank > 0

  negative = (rank, parentId) ->
    parentId != idea.id or rank < 0

  margin = margin or 20
  positiveTree = MAPJS.calculateTree(idea, dimensionProvider, margin, positive)
  negativeTree = MAPJS.calculateTree(idea, dimensionProvider, margin, negative)
  layout = positiveTree.toLayout()
  negativeLayout = negativeTree.toLayout()
  _.each negativeLayout.nodes, (n) ->
    n.x = -1 * n.x - (n.width)
    return
  _.extend negativeLayout.nodes, layout.nodes
  _.extend negativeLayout.connectors, layout.connectors
  setDefaultStyles negativeLayout.nodes
  negativeLayout.links = MAPJS.layoutLinks(idea, negativeLayout.nodes)
  negativeLayout.rootNodeId = idea.id
  negativeLayout
