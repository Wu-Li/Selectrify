MAPJS.content = (contentAggregate, sessionKey) ->
  'use strict'
  cachedId = undefined

  invalidateIdCache = ->
    cachedId = undefined
    return

  maxId = (idea) ->
    idea = idea or contentAggregate
    if !idea.ideas
      return parseInt(idea.id, 10) or 0
    _.reduce idea.ideas, ((result, subidea) ->
      Math.max result, maxId(subidea)
    ), parseInt(idea.id, 10) or 0

  nextId = (originSession) ->
    originSession = originSession or sessionKey
    if !cachedId
      cachedId = maxId()
    cachedId += 1
    if originSession
      return cachedId + '.' + originSession
    cachedId

  init = (contentIdea, originSession) ->
    if !contentIdea.id
      contentIdea.id = nextId(originSession)
    else
      invalidateIdCache()
    if contentIdea.ideas
      _.each contentIdea.ideas, (value, key) ->
        contentIdea.ideas[parseFloat(key)] = init(value, originSession)
        return
    if !contentIdea.title
      contentIdea.title = ''
    contentIdea.containsDirectChild =
    contentIdea.findChildRankById = (childIdeaId) ->
      parseFloat _.reduce(contentIdea.ideas, ((res, value, key) ->
        if value.id == childIdeaId then key else res
      ), undefined)

    contentIdea.findSubIdeaById = (childIdeaId) ->
      myChild = _.find(contentIdea.ideas, (idea) ->
        idea.id == childIdeaId
      )
      myChild or _.reduce(contentIdea.ideas, ((result, idea) ->
        result or idea.findSubIdeaById(childIdeaId)
      ), undefined)

    contentIdea.find = (predicate) ->
      current = if predicate(contentIdea) then [ _.pick(contentIdea, 'id', 'title') ] else []
      if _.size(contentIdea.ideas) == 0
        return current
      _.reduce contentIdea.ideas, ((result, idea) ->
        _.union result, idea.find(predicate)
      ), current

    contentIdea.getAttr = (name) ->
      if contentIdea.attr and contentIdea.attr[name]
        return _.clone(contentIdea.attr[name])
      false

    contentIdea.sortedSubIdeas = ->
      if !contentIdea.ideas
        return []
      result = []
      childKeys = _.groupBy(_.map(_.keys(contentIdea.ideas), parseFloat), (key) ->
        key > 0
      )
      sortedChildKeys = _.sortBy(childKeys[true], Math.abs).concat(_.sortBy(childKeys[false], Math.abs))
      _.each sortedChildKeys, (key) ->
        result.push contentIdea.ideas[key]
        return
      result

    contentIdea.traverse = (iterator, postOrder) ->
      if !postOrder
        iterator contentIdea
      _.each contentIdea.sortedSubIdeas(), (subIdea) ->
        subIdea.traverse iterator, postOrder
        return
      if postOrder
        iterator contentIdea
      return

    contentIdea

  maxKey = (kvMap, sign) ->
    sign = sign or 1
    if _.size(kvMap) == 0
      return 0
    currentKeys = _.keys(kvMap)
    currentKeys.push 0
    _.max _.map(currentKeys, parseFloat), (x) ->
      x * sign

  nextChildRank = (parentIdea) ->
    newRank = undefined
    counts = undefined
    childRankSign = 1
    if parentIdea.id == contentAggregate.id
      counts = _.countBy(parentIdea.ideas, (v, k) ->
        k < 0
      )
      if (counts['true'] or 0) < counts['false']
        childRankSign = -1
    newRank = maxKey(parentIdea.ideas, childRankSign) + childRankSign
    newRank

  appendSubIdea = (parentIdea, subIdea) ->
    rank = undefined
    parentIdea.ideas = parentIdea.ideas or {}
    rank = nextChildRank(parentIdea)
    parentIdea.ideas[rank] = subIdea
    rank

  findIdeaById = (ideaId) ->
    if contentAggregate.id == ideaId then contentAggregate else contentAggregate.findSubIdeaById(ideaId)

  sameSideSiblingRanks = (parentIdea, ideaRank) ->
    _(_.map(_.keys(parentIdea.ideas), parseFloat)).reject (k) ->
      k * ideaRank < 0

  sign = (number) ->
    if number < 0 then -1 else 1

  eventStacks = {}
  redoStacks = {}
  isRedoInProgress = false
  batches = {}

  notifyChange = (method, args, originSession) ->
    if originSession
      contentAggregate.dispatchEvent 'changed', method, args, originSession
    else
      contentAggregate.dispatchEvent 'changed', method, args
    return

  appendChange = (method, args, undofunc, originSession) ->
    prev = undefined
    if method == 'batch' or batches[originSession] or !eventStacks or !eventStacks[originSession] or eventStacks[originSession].length == 0
      logChange method, args, undofunc, originSession
      return
    else
      prev = eventStacks[originSession].pop()
      if prev.eventMethod == 'batch'
        eventStacks[originSession].push
          eventMethod: 'batch'
          eventArgs: prev.eventArgs.concat([ [ method ].concat(args) ])
          undoFunction: ->
            undofunc()
            prev.undoFunction()
            return
      else
        eventStacks[originSession].push
          eventMethod: 'batch'
          eventArgs: [ [ prev.eventMethod ].concat(prev.eventArgs) ].concat([ [ method ].concat(args) ])
          undoFunction: ->
            undofunc()
            prev.undoFunction()
            return
    if isRedoInProgress
      contentAggregate.dispatchEvent 'changed', 'redo', undefined, originSession
    else
      notifyChange method, args, originSession
      redoStacks[originSession] = []
    return

  logChange = (method, args, undofunc, originSession) ->
    event =
      eventMethod: method
      eventArgs: args
      undoFunction: undofunc
    if batches[originSession]
      batches[originSession].push event
      return
    if !eventStacks[originSession]
      eventStacks[originSession] = []
    eventStacks[originSession].push event
    if isRedoInProgress
      contentAggregate.dispatchEvent 'changed', 'redo', undefined, originSession
    else
      notifyChange method, args, originSession
      redoStacks[originSession] = []
    return

  reorderChild = (parentIdea, newRank, oldRank) ->
    parentIdea.ideas[newRank] = parentIdea.ideas[oldRank]
    delete parentIdea.ideas[oldRank]
    return

  upgrade = (idea) ->
    if idea.style
      idea.attr = {}
      collapsed = idea.style.collapsed
      delete idea.style.collapsed
      idea.attr.style = idea.style
      if collapsed
        idea.attr.collapsed = collapsed
      delete idea.style
    if idea.ideas
      _.each idea.ideas, upgrade
    return

  sessionFromId = (id) ->
    dotIndex = String(id).indexOf('.')
    dotIndex > 0 and id.substr(dotIndex + 1)

  commandProcessors = {}
  configuration = {}
  uniqueResourcePostfix = '/xxxxxxxx-yxxx-yxxx-yxxx-xxxxxxxxxxxx/'.replace(/[xy]/g, (c) ->
    r = Math.random() * 16 | 0
    v = if c == 'x' then r else r & 0x3 | 0x8
    v.toString 16
  ) + (sessionKey or '')

  updateAttr = (object, attrName, attrValue) ->
    oldAttr = undefined
    if !object
      return false
    oldAttr = _.extend({}, object.attr)
    object.attr = _.extend({}, object.attr)
    if !attrValue or attrValue == 'false' or _.isObject(attrValue) and _.isEmpty(attrValue)
      if !object.attr[attrName]
        return false
      delete object.attr[attrName]
    else
      if _.isEqual(object.attr[attrName], attrValue)
        return false
      object.attr[attrName] = JSON.parse(JSON.stringify(attrValue))
    if _.size(object.attr) == 0
      delete object.attr
    ->
      object.attr = oldAttr
      return

  contentAggregate.setConfiguration = (config) ->
    configuration = config or {}
    return

  contentAggregate.getSessionKey = ->
    sessionKey

  contentAggregate.nextSiblingId = (subIdeaId) ->
    parentIdea = contentAggregate.findParent(subIdeaId)
    currentRank = undefined
    candidateSiblingRanks = undefined
    siblingsAfter = undefined
    if !parentIdea
      return false
    currentRank = parentIdea.findChildRankById(subIdeaId)
    candidateSiblingRanks = sameSideSiblingRanks(parentIdea, currentRank)
    siblingsAfter = _.reject(candidateSiblingRanks, (k) ->
      Math.abs(k) <= Math.abs(currentRank)
    )
    if siblingsAfter.length == 0
      return false
    parentIdea.ideas[_.min(siblingsAfter, Math.abs)].id

  contentAggregate.sameSideSiblingIds = (subIdeaId) ->
    parentIdea = contentAggregate.findParent(subIdeaId)
    currentRank = parentIdea.findChildRankById(subIdeaId)
    _.without _.map(_.pick(parentIdea.ideas, sameSideSiblingRanks(parentIdea, currentRank)), (i) ->
      i.id
    ), subIdeaId

  contentAggregate.getAttrById = (ideaId, attrName) ->
    idea = findIdeaById(ideaId)
    idea and idea.getAttr(attrName)

  contentAggregate.previousSiblingId = (subIdeaId) ->
    parentIdea = contentAggregate.findParent(subIdeaId)
    currentRank = undefined
    candidateSiblingRanks = undefined
    siblingsBefore = undefined
    if !parentIdea
      return false
    currentRank = parentIdea.findChildRankById(subIdeaId)
    candidateSiblingRanks = sameSideSiblingRanks(parentIdea, currentRank)
    siblingsBefore = _.reject(candidateSiblingRanks, (k) ->
      Math.abs(k) >= Math.abs(currentRank)
    )
    if siblingsBefore.length == 0
      return false
    parentIdea.ideas[_.max(siblingsBefore, Math.abs)].id

  contentAggregate.clone = (subIdeaId) ->
    toClone = subIdeaId and subIdeaId != contentAggregate.id and contentAggregate.findSubIdeaById(subIdeaId) or contentAggregate
    JSON.parse JSON.stringify(toClone)

  contentAggregate.cloneMultiple = (subIdeaIdArray) ->
    _.map subIdeaIdArray, contentAggregate.clone

  contentAggregate.calculatePath = (ideaId, currentPath, potentialParent) ->
    if contentAggregate.id == ideaId
      return []
    currentPath = currentPath or [ contentAggregate ]
    potentialParent = potentialParent or contentAggregate
    if potentialParent.containsDirectChild(ideaId)
      return currentPath
    _.reduce potentialParent.ideas, ((result, child) ->
      result or contentAggregate.calculatePath(ideaId, [ child ].concat(currentPath), child)
    ), false

  contentAggregate.getSubTreeIds = (rootIdeaId) ->
    result = []

    collectIds = (idea) ->
      if _.isEmpty(idea.ideas)
        return []
      _.each idea.sortedSubIdeas(), (child) ->
        collectIds child
        result.push child.id
        return
      return

    collectIds contentAggregate.findSubIdeaById(rootIdeaId) or contentAggregate
    result

  contentAggregate.findParent = (subIdeaId, parentIdea) ->
    parentIdea = parentIdea or contentAggregate
    if parentIdea.containsDirectChild(subIdeaId)
      return parentIdea
    _.reduce parentIdea.ideas, ((result, child) ->
      result or contentAggregate.findParent(subIdeaId, child)
    ), false

  ###*** aggregate command processing methods ***###

  contentAggregate.startBatch = (originSession) ->
    activeSession = originSession or sessionKey
    contentAggregate.endBatch originSession
    batches[activeSession] = []
    return

  contentAggregate.endBatch = (originSession) ->
    activeSession = originSession or sessionKey
    inBatch = batches[activeSession]
    batchArgs = undefined
    batchUndoFunctions = undefined
    undo = undefined
    batches[activeSession] = undefined
    if _.isEmpty(inBatch)
      return
    if _.size(inBatch) == 1
      logChange inBatch[0].eventMethod, inBatch[0].eventArgs, inBatch[0].undoFunction, activeSession
    else
      batchArgs = _.map(inBatch, (event) ->
        [ event.eventMethod ].concat event.eventArgs
      )
      batchUndoFunctions = _.sortBy(_.map(inBatch, (event) ->
        event.undoFunction
      ), (f, idx) ->
        -1 * idx
      )

      undo = ->
        _.each batchUndoFunctions, (eventUndo) ->
          eventUndo()
          return
        return

      logChange 'batch', batchArgs, undo, activeSession
    return

  contentAggregate.execCommand = (cmd, args, originSession) ->
    if !commandProcessors[cmd]
      return false
    commandProcessors[cmd].apply contentAggregate, [ originSession or sessionKey ].concat(_.toArray(args))

  contentAggregate.batch = (batchOp) ->
    contentAggregate.startBatch()
    try
      batchOp()
    finally
      contentAggregate.endBatch()
    return

  commandProcessors.batch = (originSession) ->
    contentAggregate.startBatch originSession
    try
      _.each _.toArray(arguments).slice(1), (event) ->
        contentAggregate.execCommand event[0], event.slice(1), originSession
        return
    finally
      contentAggregate.endBatch originSession
    return

  contentAggregate.pasteMultiple = (parentIdeaId, jsonArrayToPaste) ->
    contentAggregate.startBatch()
    results = _.map(jsonArrayToPaste, (json) ->
      contentAggregate.paste parentIdeaId, json
    )
    contentAggregate.endBatch()
    results

  contentAggregate.paste = (parentIdeaId, jsonToPaste, initialId) ->
    contentAggregate.execCommand 'paste', arguments

  commandProcessors.paste = (originSession, parentIdeaId, jsonToPaste, initialId) ->
    pasteParent = if parentIdeaId == contentAggregate.id then contentAggregate else contentAggregate.findSubIdeaById(parentIdeaId)

    cleanUp = (json) ->
      result = _.omit(json, 'ideas', 'id', 'attr')
      index = 1
      childKeys = undefined
      sortedChildKeys = undefined
      result.attr = _.omit(json.attr, configuration.nonClonedAttributes)
      if _.isEmpty(result.attr)
        delete result.attr
      if json.ideas
        childKeys = _.groupBy(_.map(_.keys(json.ideas), parseFloat), (key) ->
          key > 0
        )
        sortedChildKeys = _.sortBy(childKeys[true], Math.abs).concat(_.sortBy(childKeys[false], Math.abs))
        result.ideas = {}
        _.each sortedChildKeys, (key) ->
          result.ideas[index++] = cleanUp(json.ideas[key])
          return
      result

    newIdea = undefined
    newRank = undefined
    oldPosition = undefined
    if initialId
      cachedId = parseInt(initialId, 10) - 1
    newIdea = jsonToPaste and (jsonToPaste.title or jsonToPaste.attr) and init(cleanUp(jsonToPaste), sessionFromId(initialId))
    if !pasteParent or !newIdea
      return false
    newRank = appendSubIdea(pasteParent, newIdea)
    if initialId
      invalidateIdCache()
    updateAttr newIdea, 'position'
    logChange 'paste', [
      parentIdeaId
      jsonToPaste
      newIdea.id
    ], (->
      delete pasteParent.ideas[newRank]
      return
    ), originSession
    newIdea.id

  contentAggregate.flip = (ideaId) ->
    contentAggregate.execCommand 'flip', arguments

  commandProcessors.flip = (originSession, ideaId) ->
    newRank = undefined
    maxRank = undefined
    currentRank = contentAggregate.findChildRankById(ideaId)
    if !currentRank
      return false
    maxRank = maxKey(contentAggregate.ideas, -1 * sign(currentRank))
    newRank = maxRank - (10 * sign(currentRank))
    reorderChild contentAggregate, newRank, currentRank
    logChange 'flip', [ ideaId ], (->
      reorderChild contentAggregate, currentRank, newRank
      return
    ), originSession
    true

  contentAggregate.initialiseTitle = (ideaId, title) ->
    contentAggregate.execCommand 'initialiseTitle', arguments

  commandProcessors.initialiseTitle = (originSession, ideaId, title) ->
    idea = findIdeaById(ideaId)
    originalTitle = undefined
    if !idea
      return false
    originalTitle = idea.title
    if originalTitle == title
      return false
    idea.title = title
    appendChange 'initialiseTitle', [
      ideaId
      title
    ], (->
      idea.title = originalTitle
      return
    ), originSession
    true

  contentAggregate.updateTitle = (ideaId, title) ->
    contentAggregate.execCommand 'updateTitle', arguments

  commandProcessors.updateTitle = (originSession, ideaId, title) ->
    idea = findIdeaById(ideaId)
    originalTitle = undefined
    if !idea
      return false
    originalTitle = idea.title
    if originalTitle == title
      return false
    idea.title = title
    logChange 'updateTitle', [
      ideaId
      title
    ], (->
      idea.title = originalTitle
      return
    ), originSession
    true

  contentAggregate.addSubIdea = (parentId, ideaTitle, optionalNewId) ->
    contentAggregate.execCommand 'addSubIdea', arguments

  commandProcessors.addSubIdea = (originSession, parentId, ideaTitle, optionalNewId) ->
    idea = undefined
    parent = findIdeaById(parentId)
    newRank = undefined
    if !parent
      return false
    if optionalNewId and findIdeaById(optionalNewId)
      return false
    idea = init(
      title: ideaTitle
      id: optionalNewId)
    newRank = appendSubIdea(parent, idea)
    logChange 'addSubIdea', [
      parentId
      ideaTitle
      idea.id
    ], (->
      delete parent.ideas[newRank]
      return
    ), originSession
    idea.id

  contentAggregate.removeMultiple = (subIdeaIdArray) ->
    contentAggregate.startBatch()
    results = _.map(subIdeaIdArray, contentAggregate.removeSubIdea)
    contentAggregate.endBatch()
    results

  contentAggregate.removeSubIdea = (subIdeaId) ->
    contentAggregate.execCommand 'removeSubIdea', arguments

  commandProcessors.removeSubIdea = (originSession, subIdeaId) ->
    parent = contentAggregate.findParent(subIdeaId)
    oldRank = undefined
    oldIdea = undefined
    oldLinks = undefined
    if parent
      oldRank = parent.findChildRankById(subIdeaId)
      oldIdea = parent.ideas[oldRank]
      delete parent.ideas[oldRank]
      oldLinks = contentAggregate.links
      contentAggregate.links = _.reject(contentAggregate.links, (link) ->
        link.ideaIdFrom == subIdeaId or link.ideaIdTo == subIdeaId
      )
      logChange 'removeSubIdea', [ subIdeaId ], (->
        parent.ideas[oldRank] = oldIdea
        contentAggregate.links = oldLinks
        return
      ), originSession
      return true
    false

  contentAggregate.insertIntermediateMultiple = (idArray) ->
    contentAggregate.startBatch()
    newId = contentAggregate.insertIntermediate(idArray[0])
    _.each idArray.slice(1), (id) ->
      contentAggregate.changeParent id, newId
      return
    contentAggregate.endBatch()
    newId

  contentAggregate.insertIntermediate = (inFrontOfIdeaId, title, optionalNewId) ->
    contentAggregate.execCommand 'insertIntermediate', arguments

  commandProcessors.insertIntermediate = (originSession, inFrontOfIdeaId, title, optionalNewId) ->
    if contentAggregate.id == inFrontOfIdeaId
      return false
    childRank = undefined
    oldIdea = undefined
    newIdea = undefined
    parentIdea = contentAggregate.findParent(inFrontOfIdeaId)
    if !parentIdea
      return false
    if optionalNewId and findIdeaById(optionalNewId)
      return false
    childRank = parentIdea.findChildRankById(inFrontOfIdeaId)
    if !childRank
      return false
    oldIdea = parentIdea.ideas[childRank]
    newIdea = init(
      title: title
      id: optionalNewId)
    parentIdea.ideas[childRank] = newIdea
    newIdea.ideas = 1: oldIdea
    logChange 'insertIntermediate', [
      inFrontOfIdeaId
      title
      newIdea.id
    ], (->
      parentIdea.ideas[childRank] = oldIdea
      return
    ), originSession
    newIdea.id

  contentAggregate.changeParent = (ideaId, newParentId) ->
    contentAggregate.execCommand 'changeParent', arguments

  commandProcessors.changeParent = (originSession, ideaId, newParentId) ->
    oldParent = undefined
    oldRank = undefined
    newRank = undefined
    idea = undefined
    parent = findIdeaById(newParentId)
    oldPosition = undefined
    if ideaId == newParentId
      return false
    if !parent
      return false
    idea = contentAggregate.findSubIdeaById(ideaId)
    if !idea
      return false
    if idea.findSubIdeaById(newParentId)
      return false
    if parent.containsDirectChild(ideaId)
      return false
    oldParent = contentAggregate.findParent(ideaId)
    if !oldParent
      return false
    oldRank = oldParent.findChildRankById(ideaId)
    newRank = appendSubIdea(parent, idea)
    oldPosition = idea.getAttr('position')
    updateAttr idea, 'position'
    delete oldParent.ideas[oldRank]
    logChange 'changeParent', [
      ideaId
      newParentId
    ], (->
      updateAttr idea, 'position', oldPosition
      oldParent.ideas[oldRank] = idea
      delete parent.ideas[newRank]
      return
    ), originSession
    true

  contentAggregate.mergeAttrProperty = (ideaId, attrName, attrPropertyName, attrPropertyValue) ->
    val = contentAggregate.getAttrById(ideaId, attrName) or {}
    if attrPropertyValue
      val[attrPropertyName] = attrPropertyValue
    else
      delete val[attrPropertyName]
    if _.isEmpty(val)
      val = false
    contentAggregate.updateAttr ideaId, attrName, val

  contentAggregate.updateAttr = (ideaId, attrName, attrValue) ->
    contentAggregate.execCommand 'updateAttr', arguments

  commandProcessors.updateAttr = (originSession, ideaId, attrName, attrValue) ->
    idea = findIdeaById(ideaId)
    undoAction = undefined
    undoAction = updateAttr(idea, attrName, attrValue)
    if undoAction
      logChange 'updateAttr', [
        ideaId
        attrName
        attrValue
      ], undoAction, originSession
    ! !undoAction

  contentAggregate.moveRelative = (ideaId, relativeMovement) ->
    parentIdea = contentAggregate.findParent(ideaId)
    currentRank = parentIdea and parentIdea.findChildRankById(ideaId)
    siblingRanks = currentRank and _.sortBy(sameSideSiblingRanks(parentIdea, currentRank), Math.abs)
    currentIndex = siblingRanks and siblingRanks.indexOf(currentRank)
    newIndex = currentIndex + (if relativeMovement > 0 then relativeMovement + 1 else relativeMovement)
    beforeSibling = newIndex >= 0 and parentIdea and siblingRanks and parentIdea.ideas[siblingRanks[newIndex]]
    if newIndex < 0 or !parentIdea
      return false
    contentAggregate.positionBefore ideaId, beforeSibling and beforeSibling.id, parentIdea

  contentAggregate.positionBefore = (ideaId, positionBeforeIdeaId, parentIdea) ->
    contentAggregate.execCommand 'positionBefore', arguments

  commandProcessors.positionBefore = (originSession, ideaId, positionBeforeIdeaId, parentIdea) ->
    parentIdea = parentIdea or contentAggregate
    newRank = undefined
    afterRank = undefined
    siblingRanks = undefined
    candidateSiblings = undefined
    beforeRank = undefined
    maxRank = undefined
    currentRank = undefined
    currentRank = parentIdea.findChildRankById(ideaId)
    if !currentRank
      return _.reduce(parentIdea.ideas, ((result, idea) ->
        result or commandProcessors.positionBefore(originSession, ideaId, positionBeforeIdeaId, idea)
      ), false)
    if ideaId == positionBeforeIdeaId
      return false
    newRank = 0
    if positionBeforeIdeaId
      afterRank = parentIdea.findChildRankById(positionBeforeIdeaId)
      if !afterRank
        return false
      siblingRanks = sameSideSiblingRanks(parentIdea, currentRank)
      candidateSiblings = _.reject(_.sortBy(siblingRanks, Math.abs), (k) ->
        Math.abs(k) >= Math.abs(afterRank)
      )
      beforeRank = if candidateSiblings.length > 0 then _.max(candidateSiblings, Math.abs) else 0
      if beforeRank == currentRank
        return false
      newRank = beforeRank + (afterRank - beforeRank) / 2
    else
      maxRank = maxKey(parentIdea.ideas, if currentRank < 0 then -1 else 1)
      if maxRank == currentRank
        return false
      newRank = maxRank + 10 * (if currentRank < 0 then -1 else 1)
    if newRank == currentRank
      return false
    reorderChild parentIdea, newRank, currentRank
    logChange 'positionBefore', [
      ideaId
      positionBeforeIdeaId
    ], (->
      reorderChild parentIdea, currentRank, newRank
      return
    ), originSession
    true

  observable contentAggregate
  do ->

    isLinkValid = (ideaIdFrom, ideaIdTo) ->
      isParentChild = undefined
      ideaFrom = undefined
      ideaTo = undefined
      if ideaIdFrom == ideaIdTo
        return false
      ideaFrom = findIdeaById(ideaIdFrom)
      if !ideaFrom
        return false
      ideaTo = findIdeaById(ideaIdTo)
      if !ideaTo
        return false
      isParentChild = _.find(ideaFrom.ideas, (node) ->
        node.id == ideaIdTo
      ) or _.find(ideaTo.ideas, (node) ->
        node.id == ideaIdFrom
      )
      if isParentChild
        return false
      true

    contentAggregate.addLink = (ideaIdFrom, ideaIdTo) ->
      contentAggregate.execCommand 'addLink', arguments

    commandProcessors.addLink = (originSession, ideaIdFrom, ideaIdTo) ->
      alreadyExists = undefined
      link = undefined
      if !isLinkValid(ideaIdFrom, ideaIdTo)
        return false
      alreadyExists = _.find(contentAggregate.links, (link) ->
        link.ideaIdFrom == ideaIdFrom and link.ideaIdTo == ideaIdTo or link.ideaIdFrom == ideaIdTo and link.ideaIdTo == ideaIdFrom
      )
      if alreadyExists
        return false
      contentAggregate.links = contentAggregate.links or []
      link =
        ideaIdFrom: ideaIdFrom
        ideaIdTo: ideaIdTo
        attr: style:
          color: '#FF0000'
          lineStyle: 'dashed'
      contentAggregate.links.push link
      logChange 'addLink', [
        ideaIdFrom
        ideaIdTo
      ], (->
        contentAggregate.links.pop()
        return
      ), originSession
      true

    contentAggregate.removeLink = (ideaIdOne, ideaIdTwo) ->
      contentAggregate.execCommand 'removeLink', arguments

    commandProcessors.removeLink = (originSession, ideaIdOne, ideaIdTwo) ->
      i = 0
      link = undefined
      while contentAggregate.links and i < contentAggregate.links.length
        link = contentAggregate.links[i]
        if String(link.ideaIdFrom) == String(ideaIdOne) and String(link.ideaIdTo) == String(ideaIdTwo)
          contentAggregate.links.splice i, 1
          logChange 'removeLink', [
            ideaIdOne
            ideaIdTwo
          ], (->
            contentAggregate.links.push _.clone(link)
            return
          ), originSession
          return true
        i += 1
      false

    contentAggregate.getLinkAttr = (ideaIdFrom, ideaIdTo, name) ->
      link = _.find(contentAggregate.links, (link) ->
        link.ideaIdFrom == ideaIdFrom and link.ideaIdTo == ideaIdTo
      )
      if link and link.attr and link.attr[name]
        return link.attr[name]
      false

    contentAggregate.updateLinkAttr = (ideaIdFrom, ideaIdTo, attrName, attrValue) ->
      contentAggregate.execCommand 'updateLinkAttr', arguments

    commandProcessors.updateLinkAttr = (originSession, ideaIdFrom, ideaIdTo, attrName, attrValue) ->
      link = _.find(contentAggregate.links, (link) ->
        link.ideaIdFrom == ideaIdFrom and link.ideaIdTo == ideaIdTo
      )
      undoAction = undefined
      undoAction = updateAttr(link, attrName, attrValue)
      if undoAction
        logChange 'updateLinkAttr', [
          ideaIdFrom
          ideaIdTo
          attrName
          attrValue
        ], undoAction, originSession
      ! !undoAction

    return

  ###undo/redo ###

  contentAggregate.undo = ->
    contentAggregate.execCommand 'undo', arguments

  commandProcessors.undo = (originSession) ->
    contentAggregate.endBatch()
    topEvent = undefined
    topEvent = eventStacks[originSession] and eventStacks[originSession].pop()
    if topEvent and topEvent.undoFunction
      topEvent.undoFunction()
      if !redoStacks[originSession]
        redoStacks[originSession] = []
      redoStacks[originSession].push topEvent
      contentAggregate.dispatchEvent 'changed', 'undo', [], originSession
      return true
    false

  contentAggregate.redo = ->
    contentAggregate.execCommand 'redo', arguments

  commandProcessors.redo = (originSession) ->
    contentAggregate.endBatch()
    topEvent = undefined
    topEvent = redoStacks[originSession] and redoStacks[originSession].pop()
    if topEvent
      isRedoInProgress = true
      contentAggregate.execCommand topEvent.eventMethod, topEvent.eventArgs, originSession
      isRedoInProgress = false
      return true
    false

  contentAggregate.storeResource = ->
    contentAggregate.execCommand 'storeResource', arguments

  commandProcessors.storeResource = (originSession, resourceBody, optionalKey) ->
    existingId = undefined
    id = undefined

    maxIdForSession = ->
      if _.isEmpty(contentAggregate.resources)
        return 0

      toInt = (string) ->
        parseInt string, 10

      keys = _.keys(contentAggregate.resources)
      filteredKeys = if sessionKey then _.filter(keys, RegExp::test.bind(new RegExp('\\/' + sessionKey + '$'))) else keys
      intKeys = _.map(filteredKeys, toInt)
      if _.isEmpty(intKeys) then 0 else _.max(intKeys)

    nextResourceId = ->
      intId = maxIdForSession() + 1
      intId + uniqueResourcePostfix

    if !optionalKey and contentAggregate.resources
      existingId = _.find(_.keys(contentAggregate.resources), (key) ->
        contentAggregate.resources[key] == resourceBody
      )
      if existingId
        return existingId
    id = optionalKey or nextResourceId()
    contentAggregate.resources = contentAggregate.resources or {}
    contentAggregate.resources[id] = resourceBody
    contentAggregate.dispatchEvent 'resourceStored', resourceBody, id, originSession
    id

  contentAggregate.getResource = (id) ->
    contentAggregate.resources and contentAggregate.resources[id]

  contentAggregate.hasSiblings = (id) ->
    if id == contentAggregate.id
      return false
    parent = contentAggregate.findParent(id)
    parent and _.size(parent.ideas) > 1

  if contentAggregate.formatVersion != 2
    upgrade contentAggregate
    contentAggregate.formatVersion = 2
  init contentAggregate
  contentAggregate
