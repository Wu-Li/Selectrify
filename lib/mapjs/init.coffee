$.fx.off = true
$ ->
  bgc = $('atom-text-editor').css('background-color')
  try $('<style>.mapjs-node{background-color:' + bgc + ';}</style>').appendTo(laboratory)
  $('#queryBox').bind 'input', (evt) ->
    chemist.cursor.text = @innerText
  $('#queryBox').on 'keypress', (evt) ->
    if evt.ctrlKey and evt.charCode = 13
      chemist.select();

MAPJS.init = (idea)->
  container = $("#laboratory")
  if !idea
    idea = MAPJS.content
      title: "Selectrify"
  mapModel = new (MAPJS.MapModel)(MAPJS.DOMRender.layoutCalculator, [])
  imageInsertController = new (MAPJS.ImageInsertController)('http://localhost:4999?u=')
  container.domMapWidget console, mapModel, false, imageInsertController
  $('body').mapToolbarWidget mapModel
  $('body').attachmentEditorWidget mapModel
  $('[data-mm-action=\'export-image\']').click ->
    MAPJS.pngExport(idea).then (url) ->
      window.open url, '_blank'
      return
    return
  mapModel.setIdea idea
  $('#linkEditWidget').linkEditWidget mapModel
  $('.arrow').click ->
    $(this).toggleClass 'active'
    return
  imageInsertController.addEventListener 'imageInsertError', (reason) ->
    console.log 'image insert error', reason
    return
  container.on 'drop', (e) ->
    dataTransfer = e.originalEvent.dataTransfer
    e.stopPropagation()
    e.preventDefault()
    if dataTransfer and dataTransfer.files and dataTransfer.files.length > 0
      fileInfo = dataTransfer.files[0]
      if /\.mup$/.test(fileInfo.name)
        oFReader = new FileReader

        oFReader.onload = (oFREvent) ->
          mapModel.setIdea MAPJS.content(JSON.parse(oFREvent.target.result))
          return

        oFReader.readAsText fileInfo, 'UTF-8'
    return
  return mapModel
