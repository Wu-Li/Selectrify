ChemistryView = require './chemistry-view'
{CompositeDisposable} = require 'atom'
Chemist = require('./chemist')
root.Datacule = Datacule = require('./datacule')

module.exports = Chemistry =
  chemistryView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @chemistryView = new ChemistryView(state.chemistryViewState)
    @modalPanel = atom.workspace.addRightPanel(item: @chemistryView.getElement(), visible: true)

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:toggle': => @toggle()

    chemist = window.chemist = new Chemist('chemistry')
    @subscriptions.add atom.workspace.observePaneItems (paneItem) =>
      if paneItem?.getPath?()? and paneItem.getTitle()?.split('.').pop() == 'coffee'
        if paneItem.getTitle() == 'coffeescript.coffee' then return
        chemist.loadItem(paneItem)
    @subscriptions.add atom.workspace.observeActivePaneItem (paneItem) =>
      if paneItem?.getPath?()? and paneItem.getTitle()?.split('.').pop() == 'coffee'
        if paneItem.getTitle() == 'coffeescript.coffee' then return
        chemist.tab(paneItem)
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:draw': => chemist.draw()
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:save': => chemist.save()
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:select': => chemist.select()
    @subscriptions.add atom.commands.add 'atom-workspace', 'chemistry:trace': => chemist.trace()

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
