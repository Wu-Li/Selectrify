MAPJS.MapModel = (layoutCalculatorArg, selectAllTitles, clipboardProvider, defaultReorderMargin) ->
  'use strict'
  self = this
  layoutCalculator = layoutCalculatorArg
  reorderMargin = defaultReorderMargin or 20
  clipboard = clipboardProvider or new (MAPJS.MemoryClipboard)
  analytic = undefined
  currentLayout =
    nodes: {}
    connectors: {}
  idea = undefined
  currentLabelGenerator = undefined
  isInputEnabled = true
  isEditingEnabled = true
  currentlySelectedIdeaId = undefined
  activatedNodes = []

  setActiveNodes = (activated) ->
    wasActivated = _.clone(activatedNodes)
    if activated.length == 0
      activatedNodes = [ currentlySelectedIdeaId ]
    else
      activatedNodes = activated
    self.dispatchEvent 'activatedNodesChanged', _.difference(activatedNodes, wasActivated), _.difference(wasActivated, activatedNodes)
    return

  horizontalSelectionThreshold = 300
  isAddLinkMode = undefined

  applyLabels = (newLayout) ->
    if !currentLabelGenerator
      return
    labelMap = currentLabelGenerator(idea)
    _.each newLayout.nodes, (node, id) ->
      if labelMap[id] or labelMap[id] == 0
        node.label = labelMap[id]
      return
    return

  updateCurrentLayout = (newLayout, sessionId) ->
    self.dispatchEvent 'layoutChangeStarting', _.size(newLayout.nodes) - _.size(currentLayout.nodes)
    applyLabels newLayout
    #CHEM
    _.each currentLayout.connectors, (oldConnector, connectorId) ->
      newConnector = newLayout.connectors[connectorId]
      if !newConnector or newConnector.from != oldConnector.from or newConnector.to != oldConnector.to
        self.dispatchEvent 'connectorRemoved', oldConnector
      return
    _.each currentLayout.links, (oldLink, linkId) ->
      newLink = newLayout.links and newLayout.links[linkId]
      if !newLink
        self.dispatchEvent 'linkRemoved', oldLink
      return
    _.each currentLayout.nodes, (oldNode, nodeId) ->
      newNode = newLayout.nodes[nodeId]
      newActive = undefined
      if !newNode
        if nodeId == currentlySelectedIdeaId
          self.selectNode idea.id
        newActive = _.reject(activatedNodes, (e) ->
          e == nodeId
        )
        if newActive.length != activatedNodes.length
          setActiveNodes newActive
        self.dispatchEvent 'nodeRemoved', oldNode, nodeId, sessionId
      return
    _.each newLayout.nodes, (newNode, nodeId) ->
      oldNode = currentLayout.nodes[nodeId]
      if !oldNode
        self.dispatchEvent 'nodeCreated', newNode, sessionId
      else
        if newNode.x != oldNode.x or newNode.y != oldNode.y
          self.dispatchEvent 'nodeMoved', newNode, sessionId
        if newNode.title != oldNode.title
          self.dispatchEvent 'nodeTitleChanged', newNode, sessionId
        if !_.isEqual(newNode.attr or {}, oldNode.attr or {})
          self.dispatchEvent 'nodeAttrChanged', newNode, sessionId
        if newNode.label != oldNode.label
          self.dispatchEvent 'nodeLabelChanged', newNode, sessionId
      return
    _.each newLayout.connectors, (newConnector, connectorId) ->
      oldConnector = currentLayout.connectors[connectorId]
      if !oldConnector or newConnector.from != oldConnector.from or newConnector.to != oldConnector.to
        self.dispatchEvent 'connectorCreated', newConnector, sessionId
      return
    _.each newLayout.links, (newLink, linkId) ->
      oldLink = currentLayout.links and currentLayout.links[linkId]
      if oldLink
        if !_.isEqual(newLink.attr or {}, oldLink and oldLink.attr or {})
          self.dispatchEvent 'linkAttrChanged', newLink, sessionId
      else
        self.dispatchEvent 'linkCreated', newLink, sessionId
      return
    currentLayout = newLayout
    if !self.isInCollapse
      self.dispatchEvent 'layoutChangeComplete'
    return

  revertSelectionForUndo = undefined
  revertActivatedForUndo = undefined

  selectNewIdea = (newIdeaId) ->
    revertSelectionForUndo = currentlySelectedIdeaId
    revertActivatedForUndo = activatedNodes.slice(0)
    self.selectNode newIdeaId
    return

  editNewIdea = (newIdeaId) ->
    selectNewIdea newIdeaId
    self.editNode false, true, true
    return

  getCurrentlySelectedIdeaId = ->
    currentlySelectedIdeaId or idea.id

  paused = false

  onIdeaChanged = (action, args, sessionId) ->
    if paused
      return
    revertSelectionForUndo = false
    revertActivatedForUndo = false
    self.rebuildRequired sessionId
    return

  currentlySelectedIdea = ->
    idea.findSubIdeaById(currentlySelectedIdeaId) or idea

  ensureNodeIsExpanded = (source, nodeId) ->
    node = idea.findSubIdeaById(nodeId) or idea
    if node.getAttr('collapsed')
      idea.updateAttr nodeId, 'collapsed', false
    return

  observable this
  analytic = self.dispatchEvent.bind(self, 'analytic', 'mapModel')

  self.pause = ->
    paused = true
    return

  self.resume = ->
    paused = false
    self.rebuildRequired()
    return

  self.getIdea = ->
    idea

  self.isEditingEnabled = ->
    isEditingEnabled

  self.getCurrentLayout = ->
    currentLayout

  self.analytic = analytic
  self.getCurrentlySelectedIdeaId = getCurrentlySelectedIdeaId

  self.rebuildRequired = (sessionId) ->
    if !idea
      return
    updateCurrentLayout self.reactivate(layoutCalculator(idea)), sessionId
    return

  @setIdea = (anIdea) ->
    if idea
      idea.removeEventListener 'changed', onIdeaChanged
      paused = false
      setActiveNodes []
      self.dispatchEvent 'nodeSelectionChanged', currentlySelectedIdeaId, false
      currentlySelectedIdeaId = undefined
    idea = anIdea
    idea.addEventListener 'changed', onIdeaChanged
    onIdeaChanged()
    self.selectNode idea.id, true
    self.dispatchEvent 'mapViewResetRequested'
    return

  @setEditingEnabled = (value) ->
    isEditingEnabled = value
    return

  @getEditingEnabled = ->
    isEditingEnabled

  @setInputEnabled = (value, holdFocus) ->
    if isInputEnabled != value
      isInputEnabled = value
      self.dispatchEvent 'inputEnabledChanged', value, ! !holdFocus
    return

  @getInputEnabled = ->
    isInputEnabled

  @selectNode = (id, force, appendToActive) ->
    if force or isInputEnabled and (id != currentlySelectedIdeaId or !self.isActivated(id))
      if currentlySelectedIdeaId
        self.dispatchEvent 'nodeSelectionChanged', currentlySelectedIdeaId, false
      currentlySelectedIdeaId = id
      if appendToActive
        self.activateNode 'internal', id
      else
        setActiveNodes [ id ]
      self.dispatchEvent 'nodeSelectionChanged', id, true
    return

  @clickNode = (id, event) ->
    button = event and event.button and event.button != -1
    if event and event.altKey
      self.toggleLink 'mouse', id
    else if event and event.shiftKey

      ###don't stop propagation, this is needed for drop targets###

      self.toggleActivationOnNode 'mouse', id
    else if isAddLinkMode and !button
      @toggleLink 'mouse', id
      @toggleAddLinkMode()
    else
      @selectNode id
      if button and button != -1 and isInputEnabled
        self.dispatchEvent 'contextMenuRequested', id, event.layerX, event.layerY
    return

  @findIdeaById = (id) ->
    if idea.id == id
      return idea
    idea.findSubIdeaById id

  @getSelectedStyle = (prop) ->
    @getStyleForId currentlySelectedIdeaId, prop

  @getStyleForId = (id, prop) ->
    node = currentLayout.nodes and currentLayout.nodes[id]
    node and node.attr and node.attr.style and node.attr.style[prop]

  @toggleCollapse = (source) ->
    selectedIdea = currentlySelectedIdea()
    isCollapsed = undefined
    if self.isActivated(selectedIdea.id) and _.size(selectedIdea.ideas) > 0
      isCollapsed = selectedIdea.getAttr('collapsed')
    else
      isCollapsed = self.everyActivatedIs((id) ->
        node = self.findIdeaById(id)
        if node and _.size(node.ideas) > 0
          return node.getAttr('collapsed')
        true
      )
    @collapse source, !isCollapsed
    return

  @collapse = (source, doCollapse) ->
    analytic 'collapse:' + doCollapse, source
    self.isInCollapse = true
    contextNodeId = getCurrentlySelectedIdeaId()

    contextNode = ->
      contextNodeId and currentLayout and currentLayout.nodes and currentLayout.nodes[contextNodeId]

    moveNodes = (nodes, deltaX, deltaY) ->
      if deltaX or deltaY
        _.each nodes, (node) ->
          node.x += deltaX
          node.y += deltaY
          self.dispatchEvent 'nodeMoved', node, 'scroll'
          return
      return

    oldContext = undefined
    newContext = undefined
    oldContext = contextNode()
    if isInputEnabled
      self.applyToActivated (id) ->
        node = self.findIdeaById(id)
        if node and (!doCollapse or node.ideas and _.size(node.ideas) > 0)
          idea.updateAttr id, 'collapsed', doCollapse
        return
    newContext = contextNode()
    if oldContext and newContext
      moveNodes currentLayout.nodes, oldContext.x - (newContext.x), oldContext.y - (newContext.y)
    self.isInCollapse = false
    self.dispatchEvent 'layoutChangeComplete'
    return

  @updateStyle = (source, prop, value) ->
    if !isEditingEnabled
      return false
    if isInputEnabled
      analytic 'updateStyle:' + prop, source
      self.applyToActivated (id) ->
        if self.getStyleForId(id, prop) != value
          idea.mergeAttrProperty id, 'style', prop, value
        return
    return

  @updateLinkStyle = (source, ideaIdFrom, ideaIdTo, prop, value) ->
    if !isEditingEnabled
      return false
    if isInputEnabled
      analytic 'updateLinkStyle:' + prop, source
      merged = _.extend({}, idea.getLinkAttr(ideaIdFrom, ideaIdTo, 'style'))
      merged[prop] = value
      idea.updateLinkAttr ideaIdFrom, ideaIdTo, 'style', merged
    return

  @addSubIdea = (source, parentId, initialTitle) ->
    if !isEditingEnabled
      return false
    target = parentId or currentlySelectedIdeaId
    newId = undefined
    analytic 'addSubIdea', source
    if isInputEnabled
      idea.batch ->
        ensureNodeIsExpanded source, target
        if initialTitle
          newId = idea.addSubIdea(target, initialTitle)
        else
          newId = idea.addSubIdea(target)
        return
      if newId
        if initialTitle
          selectNewIdea newId
        else
          editNewIdea newId
    return

  @insertIntermediate = (source) ->
    if !isEditingEnabled
      return false
    if !isInputEnabled or currentlySelectedIdeaId == idea.id
      return false
    activeNodes = []
    newId = undefined
    analytic 'insertIntermediate', source
    self.applyToActivated (i) ->
      activeNodes.push i
      return
    newId = idea.insertIntermediateMultiple(activeNodes)
    if newId
      editNewIdea newId
    return

  @flip = (source) ->
    if !isEditingEnabled
      return false
    analytic 'flip', source
    if !isInputEnabled or currentlySelectedIdeaId == idea.id
      return false
    node = currentLayout.nodes[currentlySelectedIdeaId]
    if !node or node.level != 2
      return false
    idea.flip currentlySelectedIdeaId

  @addSiblingIdeaBefore = (source) ->
    newId = undefined
    parent = undefined
    contextRank = undefined
    newRank = undefined
    if !isEditingEnabled
      return false
    analytic 'addSiblingIdeaBefore', source
    if !isInputEnabled
      return false
    parent = idea.findParent(currentlySelectedIdeaId) or idea
    idea.batch ->
      ensureNodeIsExpanded source, parent.id
      newId = idea.addSubIdea(parent.id)
      if newId and currentlySelectedIdeaId != idea.id
        contextRank = parent.findChildRankById(currentlySelectedIdeaId)
        newRank = parent.findChildRankById(newId)
        if contextRank * newRank < 0
          idea.flip newId
        idea.positionBefore newId, currentlySelectedIdeaId
      return
    if newId
      editNewIdea newId
    return

  @addSiblingIdea = (source, optionalNodeId, optionalInitialText) ->
    newId = undefined
    nextId = undefined
    parent = undefined
    contextRank = undefined
    newRank = undefined
    currentId = undefined
    currentId = optionalNodeId or currentlySelectedIdeaId
    if !isEditingEnabled
      return false
    analytic 'addSiblingIdea', source
    if isInputEnabled
      parent = idea.findParent(currentId) or idea
      idea.batch ->
        ensureNodeIsExpanded source, parent.id
        if optionalInitialText
          newId = idea.addSubIdea(parent.id, optionalInitialText)
        else
          newId = idea.addSubIdea(parent.id)
        if newId and currentId != idea.id
          nextId = idea.nextSiblingId(currentId)
          contextRank = parent.findChildRankById(currentId)
          newRank = parent.findChildRankById(newId)
          if contextRank * newRank < 0
            idea.flip newId
          if nextId
            idea.positionBefore newId, nextId
        return
      if newId
        if optionalInitialText
          selectNewIdea newId
        else
          editNewIdea newId
    return

  @removeSubIdea = (source) ->
    if !isEditingEnabled
      return false
    analytic 'removeSubIdea', source
    removed = undefined
    if isInputEnabled
      self.applyToActivated (id) ->
        parent = undefined
        if currentlySelectedIdeaId == id
          parent = idea.findParent(currentlySelectedIdeaId)
          if parent
            self.selectNode parent.id
        removed = idea.removeSubIdea(id)
        return
    removed

  @updateTitle = (ideaId, title, isNew) ->
    if isNew
      idea.initialiseTitle ideaId, title
    else
      idea.updateTitle ideaId, title
    return

  @editNode = (source, shouldSelectAll, editingNew) ->
    if !isEditingEnabled
      return false
    if source
      analytic 'editNode', source
    if !isInputEnabled
      return false
    title = currentlySelectedIdea().title
    if _.include(selectAllTitles, title)
      shouldSelectAll = true
    self.dispatchEvent 'nodeEditRequested', currentlySelectedIdeaId, shouldSelectAll, ! !editingNew
    return

  @editIcon = (source) ->
    if !isEditingEnabled
      return false
    if source
      analytic 'editIcon', source
    if !isInputEnabled
      return false
    self.dispatchEvent 'nodeIconEditRequested', currentlySelectedIdeaId
    return

  @scaleUp = (source) ->
    self.scale source, 1.25
    return

  @scaleDown = (source) ->
    self.scale source, 0.8
    return

  @scale = (source, scaleMultiplier, zoomPoint) ->
    if isInputEnabled
      self.dispatchEvent 'mapScaleChanged', scaleMultiplier, zoomPoint
      analytic(scaleMultiplier < 1 ? 'scaleDown' : 'scaleUp', source)
    return

  @move = (source, deltaX, deltaY) ->
    if isInputEnabled
      self.dispatchEvent 'mapMoveRequested', deltaX, deltaY
      analytic 'move', source
    return

  @resetView = (source) ->
    if isInputEnabled
      self.selectNode idea.id
      self.dispatchEvent 'mapViewResetRequested'
      analytic 'resetView', source
    return

  @openAttachment = (source, nodeId) ->
    analytic 'openAttachment', source
    nodeId = nodeId or currentlySelectedIdeaId
    node = currentLayout.nodes[nodeId]
    attachment = node and node.attr and node.attr.attachment
    if node
      self.dispatchEvent 'attachmentOpened', nodeId, attachment
    return

  @setAttachment = (source, nodeId, attachment) ->
    if !isEditingEnabled
      return false
    analytic 'setAttachment', source
    hasAttachment = ! !(attachment and attachment.content)
    idea.updateAttr nodeId, 'attachment', hasAttachment and attachment
    return

  @toggleLink = (source, nodeIdTo) ->
    exists = _.find(idea.links, (link) ->
      String(link.ideaIdFrom) == String(nodeIdTo) and String(link.ideaIdTo) == String(currentlySelectedIdeaId) or String(link.ideaIdTo) == String(nodeIdTo) and String(link.ideaIdFrom) == String(currentlySelectedIdeaId)
    )
    if exists
      self.removeLink source, exists.ideaIdFrom, exists.ideaIdTo
    else
      self.addLink source, nodeIdTo
    return

  @addLink = (source, nodeIdTo) ->
    if !isEditingEnabled
      return false
    analytic 'addLink', source
    idea.addLink currentlySelectedIdeaId, nodeIdTo
    return

  @selectLink = (source, link, selectionPoint) ->
    if !isEditingEnabled
      return false
    analytic 'selectLink', source
    if !link
      return false
    self.dispatchEvent 'linkSelected', link, selectionPoint, idea.getLinkAttr(link.ideaIdFrom, link.ideaIdTo, 'style')
    return

  @removeLink = (source, nodeIdFrom, nodeIdTo) ->
    if !isEditingEnabled
      return false
    analytic 'removeLink', source
    idea.removeLink nodeIdFrom, nodeIdTo
    return

  @toggleAddLinkMode = (source) ->
    if !isEditingEnabled
      return false
    if !isInputEnabled
      return false
    analytic 'toggleAddLinkMode', source
    isAddLinkMode = !isAddLinkMode
    self.dispatchEvent 'addLinkModeToggled', isAddLinkMode
    return

  @cancelCurrentAction = (source) ->
    if !isInputEnabled
      return false
    if !isEditingEnabled
      return false
    if isAddLinkMode
      @toggleAddLinkMode source
    return

  self.undo = (source) ->
    if !isEditingEnabled
      return false
    analytic 'undo', source
    undoSelectionClone = revertSelectionForUndo
    undoActivationClone = revertActivatedForUndo
    if isInputEnabled
      idea.undo()
      if undoSelectionClone
        self.selectNode undoSelectionClone
      if undoActivationClone
        setActiveNodes undoActivationClone
    return

  self.redo = (source) ->
    if !isEditingEnabled
      return false
    analytic 'redo', source
    if isInputEnabled
      idea.redo()
    return

  self.moveRelative = (source, relativeMovement) ->
    if !isEditingEnabled
      return false
    analytic 'moveRelative', source
    if isInputEnabled
      idea.moveRelative currentlySelectedIdeaId, relativeMovement
    return

  self.cut = (source) ->
    if !isEditingEnabled
      return false
    analytic 'cut', source
    if isInputEnabled
      activeNodeIds = []
      parents = []
      firstLiveParent = undefined
      self.applyToActivated (nodeId) ->
        activeNodeIds.push nodeId
        parents.push idea.findParent(nodeId).id
        return
      clipboard.put idea.cloneMultiple(activeNodeIds)
      idea.removeMultiple activeNodeIds
      firstLiveParent = _.find(parents, idea.findSubIdeaById)
      self.selectNode firstLiveParent or idea.id
    return

  self.contextForNode = (nodeId) ->
    node = self.findIdeaById(nodeId)
    hasChildren = node and node.ideas and _.size(node.ideas) > 0
    hasSiblings = idea.hasSiblings(nodeId)
    canPaste = node and isEditingEnabled and clipboard and clipboard.get()
    if node
      return {
        'hasChildren': ! !hasChildren
        'hasSiblings': ! !hasSiblings
        'canPaste': ! !canPaste
      }
    return

  self.copy = (source) ->
    activeNodeIds = []
    if !isEditingEnabled
      return false
    analytic 'copy', source
    if isInputEnabled
      self.applyToActivated (node) ->
        activeNodeIds.push node
        return
      clipboard.put idea.cloneMultiple(activeNodeIds)
    return

  self.paste = (source) ->
    if !isEditingEnabled
      return false
    analytic 'paste', source
    if isInputEnabled
      result = idea.pasteMultiple(currentlySelectedIdeaId, clipboard.get())
      if result and result[0]
        self.selectNode result[0]
    return

  self.pasteStyle = (source) ->
    clipContents = clipboard.get()
    pastingStyle = undefined
    if !isEditingEnabled
      return false
    analytic 'pasteStyle', source
    if isInputEnabled and clipContents and clipContents[0]
      pastingStyle = clipContents[0].attr and clipContents[0].attr.style
      self.applyToActivated (id) ->
        idea.updateAttr id, 'style', pastingStyle
        return
    return

  self.getIcon = (nodeId) ->
    node = currentLayout.nodes[nodeId or currentlySelectedIdeaId]
    if !node
      return false
    node.attr and node.attr.icon

  self.setIcon = (source, url, imgWidth, imgHeight, position, nodeId) ->
    if !isEditingEnabled
      return false
    analytic 'setIcon', source
    nodeId = nodeId or currentlySelectedIdeaId
    nodeIdea = self.findIdeaById(nodeId)
    if !nodeIdea
      return false
    if url
      idea.updateAttr nodeId, 'icon',
        url: url
        width: imgWidth
        height: imgHeight
        position: position
    else if nodeIdea.title or nodeId == idea.id
      idea.updateAttr nodeId, 'icon', false
    else
      idea.removeSubIdea nodeId
    return

  self.moveUp = (source) ->
    self.moveRelative source, -1
    return

  self.moveDown = (source) ->
    self.moveRelative source, 1
    return

  self.getSelectedNodeId = ->
    getCurrentlySelectedIdeaId()

  self.centerOnNode = (nodeId) ->
    if !currentLayout.nodes[nodeId]
      idea.startBatch()
      _.each idea.calculatePath(nodeId), (parent) ->
        idea.updateAttr parent.id, 'collapsed', false
        return
      idea.endBatch()
    self.dispatchEvent 'nodeFocusRequested', nodeId
    self.selectNode nodeId
    return

  self.search = (query) ->
    result = []
    query = query.toLocaleLowerCase()
    idea.traverse (contentIdea) ->
      if contentIdea.title and contentIdea.title.toLocaleLowerCase().indexOf(query) >= 0
        result.push
          id: contentIdea.id
          title: contentIdea.title
      return
    result

  #CHEM
  self.toggleEdges = () ->
    if $(".toggleEdges")[0].checked
      chemist.edges = true
      $(".mapjs-node").addClass('show-edges')
    else
      $(".mapjs-node").removeClass('show-edges')
      chemist.edges = false

  self.toggleTypes = () ->
    if $(".toggleTypes")[0].checked
      chemist.types = true
      $(".mapjs-node").addClass('show-types')
    else
      $(".mapjs-node").removeClass('show-types')
      chemist.types = false

  #node activation and selection
  do ->

    isRootOrRightHalf = (id) ->
      currentLayout.nodes[id].x >= currentLayout.nodes[idea.id].x

    isRootOrLeftHalf = (id) ->
      currentLayout.nodes[id].x <= currentLayout.nodes[idea.id].x

    nodesWithIDs = ->
      _.map currentLayout.nodes, (n, nodeId) ->
        _.extend { id: parseInt(nodeId, 10) }, n

    applyToNodeLeft = (source, analyticTag, method) ->
      node = undefined
      rank = undefined
      isRoot = currentlySelectedIdeaId == idea.id
      targetRank = if isRoot then -Infinity else Infinity
      if !isInputEnabled
        return
      analytic analyticTag, source
      if isRootOrLeftHalf(currentlySelectedIdeaId)
        node = if idea.id == currentlySelectedIdeaId then idea else idea.findSubIdeaById(currentlySelectedIdeaId)
        ensureNodeIsExpanded source, node.id
        for rank of node.ideas
          `rank = rank`
          rank = parseFloat(rank)
          if isRoot and rank < 0 and rank > targetRank or !isRoot and rank > 0 and rank < targetRank
            targetRank = rank
        if targetRank != Infinity and targetRank != -Infinity
          method.apply self, [ node.ideas[targetRank].id ]
      else
        method.apply self, [ idea.findParent(currentlySelectedIdeaId).id ]
      return

    applyToNodeRight = (source, analyticTag, method) ->
      node = undefined
      rank = undefined
      minimumPositiveRank = Infinity
      if !isInputEnabled
        return
      analytic analyticTag, source
      if isRootOrRightHalf(currentlySelectedIdeaId)
        node = if idea.id == currentlySelectedIdeaId then idea else idea.findSubIdeaById(currentlySelectedIdeaId)
        ensureNodeIsExpanded source, node.id
        for rank of node.ideas
          `rank = rank`
          rank = parseFloat(rank)
          if rank > 0 and rank < minimumPositiveRank
            minimumPositiveRank = rank
        if minimumPositiveRank != Infinity
          method.apply self, [ node.ideas[minimumPositiveRank].id ]
      else
        method.apply self, [ idea.findParent(currentlySelectedIdeaId).id ]
      return

    applyToNodeUp = (source, analyticTag, method) ->
      previousSibling = idea.previousSiblingId(currentlySelectedIdeaId)
      nodesAbove = undefined
      closestNode = undefined
      currentNode = currentLayout.nodes[currentlySelectedIdeaId]
      if !isInputEnabled
        return
      analytic analyticTag, source
      if previousSibling
        method.apply self, [ previousSibling ]
      else
        if !currentNode
          return
        nodesAbove = _.reject(nodesWithIDs(), (node) ->
          node.y >= currentNode.y or Math.abs(node.x - (currentNode.x)) > horizontalSelectionThreshold
        )
        if _.size(nodesAbove) == 0
          return
        closestNode = _.min(nodesAbove, (node) ->
          (node.x - (currentNode.x)) ** 2 + (node.y - (currentNode.y)) ** 2
        )
        method.apply self, [ closestNode.id ]
      return

    applyToNodeDown = (source, analyticTag, method) ->
      nextSibling = idea.nextSiblingId(currentlySelectedIdeaId)
      nodesBelow = undefined
      closestNode = undefined
      currentNode = currentLayout.nodes[currentlySelectedIdeaId]
      if !isInputEnabled
        return
      analytic analyticTag, source
      if nextSibling
        method.apply self, [ nextSibling ]
      else
        if !currentNode
          return
        nodesBelow = _.reject(nodesWithIDs(), (node) ->
          node.y <= currentNode.y or Math.abs(node.x - (currentNode.x)) > horizontalSelectionThreshold
        )
        if _.size(nodesBelow) == 0
          return
        closestNode = _.min(nodesBelow, (node) ->
          (node.x - (currentNode.x)) ** 2 + (node.y - (currentNode.y)) ** 2
        )
        method.apply self, [ closestNode.id ]
      return

    applyFuncs =
      'Left': applyToNodeLeft
      'Up': applyToNodeUp
      'Down': applyToNodeDown
      'Right': applyToNodeRight

    self.getActivatedNodeIds = ->
      activatedNodes.slice 0

    self.activateSiblingNodes = (source) ->
      parent = idea.findParent(currentlySelectedIdeaId)
      siblingIds = undefined
      analytic 'activateSiblingNodes', source
      if !parent or !parent.ideas
        return
      siblingIds = _.map(parent.ideas, (child) ->
        child.id
      )
      setActiveNodes siblingIds
      return

    self.activateNodeAndChildren = (source) ->
      analytic 'activateNodeAndChildren', source
      contextId = getCurrentlySelectedIdeaId()
      subtree = idea.getSubTreeIds(contextId)
      subtree.push contextId
      setActiveNodes subtree
      return

    _.each [
      'Left'
      'Right'
      'Up'
      'Down'
    ], (position) ->

      self['activateNode' + position] = (source) ->
        applyFuncs[position] source, 'activateNode' + position, (nodeId) ->
          self.selectNode nodeId, false, true
          return
        return

      self['selectNode' + position] = (source) ->
        applyFuncs[position] source, 'selectNode' + position, self.selectNode
        return

      return

    self.toggleActivationOnNode = (source, nodeId) ->
      analytic 'toggleActivated', source
      if !self.isActivated(nodeId)
        setActiveNodes [ nodeId ].concat(activatedNodes)
      else
        setActiveNodes _.without(activatedNodes, nodeId)
      return

    self.activateNode = (source, nodeId) ->
      analytic 'activateNode', source
      if !self.isActivated(nodeId)
        activatedNodes.push nodeId
        self.dispatchEvent 'activatedNodesChanged', [ nodeId ], []
      return

    self.activateChildren = (source) ->
      analytic 'activateChildren', source
      context = currentlySelectedIdea()
      if !context or _.isEmpty(context.ideas) or context.getAttr('collapsed')
        return
      setActiveNodes idea.getSubTreeIds(context.id)
      return

    self.activateSelectedNode = (source) ->
      analytic 'activateSelectedNode', source
      setActiveNodes [ getCurrentlySelectedIdeaId() ]
      return

    self.isActivated = (id) ->
      _.find activatedNodes, (activeId) ->
        id == activeId

    self.applyToActivated = (toApply) ->
      idea.batch ->
        _.each activatedNodes, toApply
        return
      return

    self.everyActivatedIs = (predicate) ->
      _.every activatedNodes, predicate

    self.activateLevel = (source, level) ->
      analytic 'activateLevel', source
      toActivate = _.map(_.filter(currentLayout.nodes, (node) ->
        node.level == level
      ), (node) ->
        node.id
      )
      if !_.isEmpty(toActivate)
        setActiveNodes toActivate
      return

    self.reactivate = (layout) ->
      _.each layout.nodes, (node) ->
        if _.contains(activatedNodes, node.id)
          node.activated = true
        return
      layout

    return

  self.getNodeIdAtPosition = (x, y) ->

    isPointOverNode = (node) ->
      x >= node.x and y >= node.y and x <= node.x + node.width and y <= node.y + node.height

    node = _.find(currentLayout.nodes, isPointOverNode)
    node and node.id

  self.autoPosition = (nodeId) ->
    idea.updateAttr nodeId, 'position', false

  self.positionNodeAt = (nodeId, x, y, manualPosition) ->
    rootNode = currentLayout.nodes[idea.id]
    verticallyClosestNode =
      id: null
      y: Infinity
    parentIdea = idea.findParent(nodeId)
    parentNode = currentLayout.nodes[parentIdea.id]
    nodeBeingDragged = currentLayout.nodes[nodeId]

    tryFlip = (rootNode, nodeBeingDragged, nodeDragEndX) ->
      flipRightToLeft = rootNode.x < nodeBeingDragged.x and nodeDragEndX < rootNode.x
      flipLeftToRight = rootNode.x > nodeBeingDragged.x and rootNode.x < nodeDragEndX
      if flipRightToLeft or flipLeftToRight
        return idea.flip(nodeId)
      false

    maxSequence = 1

    validReposition = ->
      nodeBeingDragged.level == 2 or (nodeBeingDragged.x - (parentNode.x)) * (x - (parentNode.x)) > 0

    result = false
    xOffset = undefined
    idea.startBatch()
    if currentLayout.nodes[nodeId].level == 2
      result = tryFlip(rootNode, nodeBeingDragged, x)
    _.each idea.sameSideSiblingIds(nodeId), (id) ->
      node = currentLayout.nodes[id]
      if y < node.y and node.y < verticallyClosestNode.y
        verticallyClosestNode = node
      return
    if !manualPosition and validReposition()
      self.autoPosition nodeId
    result = idea.positionBefore(nodeId, verticallyClosestNode.id) or result
    if manualPosition and validReposition()
      if x < parentNode.x
        xOffset = parentNode.x - x - (nodeBeingDragged.width) + parentNode.width

        ### negative nodes will get flipped so distance is not correct out of the box ###

      else
        xOffset = x - (parentNode.x)
      analytic 'nodeManuallyPositioned'
      maxSequence = _.max(_.map(parentIdea.ideas, (i) ->
        i.id != nodeId and i.attr and i.attr.position and i.attr.position[2] or 0
      ))
      result = idea.updateAttr(nodeId, 'position', [
        xOffset
        y - (parentNode.y)
        maxSequence + 1
      ]) or result
    idea.endBatch()
    result

  self.dropNode = (nodeId, dropTargetId, shiftKey) ->
    clone = undefined
    parentIdea = idea.findParent(nodeId)
    if dropTargetId == nodeId
      return false
    if shiftKey
      clone = idea.clone(nodeId)
      if clone
        idea.paste dropTargetId, clone
      return false
    if dropTargetId == parentIdea.id
      self.autoPosition nodeId
    else
      idea.changeParent nodeId, dropTargetId

  self.setLayoutCalculator = (newCalculator) ->
    layoutCalculator = newCalculator
    return

  self.dropImage = (dataUrl, imgWidth, imgHeight, x, y) ->
    nodeId = undefined

    dropOn = (ideaId, position) ->
      scaleX = Math.min(imgWidth, 300) / imgWidth
      scaleY = Math.min(imgHeight, 300) / imgHeight
      scale = Math.min(scaleX, scaleY)
      existing = idea.getAttrById(ideaId, 'icon')
      self.setIcon 'drag and drop', dataUrl, Math.round(imgWidth * scale), Math.round(imgHeight * scale), existing and existing.position or position, ideaId
      return

    addNew = ->
      newId = undefined
      idea.startBatch()
      newId = idea.addSubIdea(currentlySelectedIdeaId)
      dropOn newId, 'center'
      idea.endBatch()
      self.selectNode newId
      return

    nodeId = self.getNodeIdAtPosition(x, y)
    if nodeId
      return dropOn(nodeId, 'left')
    addNew()
    return

  self.setLabelGenerator = (labelGenerator) ->
    currentLabelGenerator = labelGenerator
    self.rebuildRequired()
    return

  self.getReorderBoundary = (nodeId) ->
    isRoot = ->
      nodeId == idea.id

    isFirstLevel = ->
      parentIdea.id == idea.id

    isRightHalf = (nodeId) ->
      currentLayout.nodes[nodeId].x >= currentLayout.nodes[idea.id].x

    siblingBoundary = (siblings, side) ->
      tops = _.map(siblings, (node) ->
        node.y
      )
      bottoms = _.map(siblings, (node) ->
        node.y + node.height
      )
      result =
        'minY': _.min(tops) - reorderMargin - (currentLayout.nodes[nodeId].height)
        'maxY': _.max(bottoms) + reorderMargin
        'margin': reorderMargin
      result.edge = side
      if side == 'left'
        result.x = parentNode.x + parentNode.width + reorderMargin
      else
        result.x = parentNode.x - reorderMargin
      result

    parentBoundary = (side) ->
      result =
        'minY': parentNode.y - reorderMargin - (currentLayout.nodes[nodeId].height)
        'maxY': parentNode.y + parentNode.height + reorderMargin
        'margin': reorderMargin
      result.edge = side
      if side == 'left'
        result.x = parentNode.x + parentNode.width + reorderMargin
      else
        result.x = parentNode.x - reorderMargin
      result

    otherSideSiblings = ->
      otherSide = _.map(parentIdea.ideas, (subIdea) ->
        currentLayout.nodes[subIdea.id]
      )
      otherSide = _.without(otherSide, currentLayout.nodes[nodeId])
      if !_.isEmpty(sameSide)
        otherSide = _.difference(otherSide, sameSide)
      otherSide

    parentIdea = undefined
    parentNode = undefined
    boundaries = []
    sameSide = undefined
    opposite = undefined
    primaryEdge = undefined
    secondaryEdge = undefined
    if isRoot(nodeId)
      return false
    parentIdea = idea.findParent(nodeId)
    parentNode = currentLayout.nodes[parentIdea.id]
    primaryEdge = if isRightHalf(nodeId) then 'left' else 'right'
    secondaryEdge = if isRightHalf(nodeId) then 'right' else 'left'
    sameSide = _.map(idea.sameSideSiblingIds(nodeId), (id) ->
      currentLayout.nodes[id]
    )
    if !_.isEmpty(sameSide)
      boundaries.push siblingBoundary(sameSide, primaryEdge)
    boundaries.push parentBoundary(primaryEdge)
    if isFirstLevel()
      opposite = otherSideSiblings()
      if !_.isEmpty(opposite)
        boundaries.push siblingBoundary(opposite, secondaryEdge)
      boundaries.push parentBoundary(secondaryEdge)
    boundaries

  self.focusAndSelect = (nodeId) ->
    self.selectNode nodeId
    self.dispatchEvent 'nodeFocusRequested', nodeId
    return

  self.requestContextMenu = (eventPointX, eventPointY) ->
    if isInputEnabled and isEditingEnabled
      self.dispatchEvent 'contextMenuRequested', currentlySelectedIdeaId, eventPointX, eventPointY
      return true
    false

  return
