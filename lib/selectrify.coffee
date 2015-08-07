SelectrifyView = require './selectrify-view'
{CompositeDisposable} = require 'atom'
Chemist = require('./chemist')

module.exports = Selectrify =
  selectrifyView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @selectrifyView = new SelectrifyView(state.selectrifyViewState)
    @modalPanel = atom.workspace.addRightPanel(item: @selectrifyView.getElement(), visible: true)

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'selectrify:toggle': => @toggle()

    chemist = window.chemist = new Chemist atom.project.getPaths()
    @subscriptions.add atom.project.onDidChangePaths (projectPaths) => chemist.loadProject(projectPaths)
    @subscriptions.add atom.workspace.observeTextEditors (paneItem) => chemist.loadItem(paneItem)
    @subscriptions.add atom.workspace.observeActivePaneItem (paneItem) => chemist.tab(paneItem)
    @subscriptions.add atom.commands.add 'atom-workspace', 'selectrify:draw': => chemist.activate()
    @subscriptions.add atom.commands.add 'atom-workspace', 'selectrify:get': => chemist.get()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @selectrifyView.destroy()

  serialize: ->
    selectrifyViewState: @selectrifyView.serialize()

  toggle: ->
    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
