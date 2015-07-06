MAPJS.getDataURIAndDimensions = (src, corsProxyUrl) ->
  'use strict'

  isDataUri = (string) ->
    /^data:image/.test string

  convertSrcToDataUri = (img) ->
    if isDataUri(img.src)
      return img.src
    canvas = document.createElement('canvas')
    ctx = undefined
    canvas.width = img.width
    canvas.height = img.height
    ctx = canvas.getContext('2d')
    ctx.drawImage img, 0, 0
    canvas.toDataURL 'image/png'

  deferred = $.Deferred()
  domImg = new Image

  domImg.onload = ->
    try
      deferred.resolve
        dataUri: convertSrcToDataUri(domImg)
        width: domImg.width
        height: domImg.height
    catch e
      deferred.reject()
    return

  domImg.onerror = ->
    deferred.reject()
    return

  if !isDataUri(src)
    if corsProxyUrl
      domImg.crossOrigin = 'Anonymous'
      src = corsProxyUrl + encodeURIComponent(src)
    else
      deferred.reject 'no-cors'
  domImg.src = src
  deferred.promise()

MAPJS.ImageInsertController = (corsProxyUrl, resourceConverter) ->
  'use strict'
  self = observable(this)

  readFileIntoDataUrl = (fileInfo) ->
    loader = $.Deferred()
    fReader = new FileReader

    fReader.onload = (e) ->
      loader.resolve e.target.result
      return

    fReader.onerror = loader.reject
    fReader.onprogress = loader.notify
    fReader.readAsDataURL fileInfo
    loader.promise()

  self.insertDataUrl = (dataUrl, evt) ->
    self.dispatchEvent 'imageLoadStarted'
    MAPJS.getDataURIAndDimensions(dataUrl, corsProxyUrl).then ((result) ->
      storeUrl = result.dataUri
      if resourceConverter
        storeUrl = resourceConverter(storeUrl)
      self.dispatchEvent 'imageInserted', storeUrl, result.width, result.height, evt
      return
    ), (reason) ->
      self.dispatchEvent 'imageInsertError', reason
      return
    return

  self.insertFiles = (files, evt) ->
    $.each files, (idx, fileInfo) ->
      if /^image\//.test(fileInfo.type)
        $.when(readFileIntoDataUrl(fileInfo)).done (dataUrl) ->
          self.insertDataUrl dataUrl, evt
          return
      return
    return

  self.insertHtmlContent = (htmlContent, evt) ->
    images = htmlContent.match(/img[^>]*src="([^"]*)"/)
    if images and images.length > 0
      _.each images.slice(1), (dataUrl) ->
        self.insertDataUrl dataUrl, evt
        return
    return

  return

$.fn.imageDropWidget = (imageInsertController) ->
  'use strict'
  @on('dragenter dragover', (e) ->
    if e.originalEvent.dataTransfer
      return false
    return
  ).on 'drop', (e) ->
    dataTransfer = e.originalEvent.dataTransfer
    htmlContent = undefined
    e.stopPropagation()
    e.preventDefault()
    if dataTransfer and dataTransfer.files and dataTransfer.files.length > 0
      imageInsertController.insertFiles dataTransfer.files, e.originalEvent
    else if dataTransfer
      htmlContent = dataTransfer.getData('text/html')
      imageInsertController.insertHtmlContent htmlContent, e.originalEvent
    return
  this
