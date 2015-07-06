ChemistryView = require './chemistry-view'
{CompositeDisposable} = require 'atom'
Chemist = require('./chemist')

module.exports = Chemistry =
  chemistryView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @chemistryView = new ChemistryView(state.chemistryViewState)
    @modalPanel = atom.workspace.addRightPanel(item: @chemistryView.getElement(), visible: true)

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:toggle': => @toggle()

    chemist = window.chemist = new Chemist atom.project.getPaths()
    @subscriptions.add atom.project.onDidChangePaths (projectPaths) => chemist.loadProject(projectPaths)
    @subscriptions.add atom.workspace.observePaneItems (paneItem) => chemist.loadItem(paneItem)
    @subscriptions.add atom.workspace.observeActivePaneItem (paneItem) => chemist.tab(paneItem)
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:draw': => chemist.activate()
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:save': => chemist.save()
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:select': => chemist.select()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @chemistryView.destroy()

  serialize: ->
    chemistryViewState: @chemistryView.serialize()

  toggle: ->
    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()
