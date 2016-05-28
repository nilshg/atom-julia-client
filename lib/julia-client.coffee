commands = require './package/commands'
menu = require './package/menu'
toolbar = require './package/toolbar'

module.exports = JuliaClient =
  misc:       require './misc'
  ui:         require './ui'
  connection: require './connection'
  runtime:    require './runtime'

  activate: (state) ->
    @requireInk =>
      commands.activate @
      x.activate() for x in [menu, @connection, @runtime]
      @ui.activate @connection.client

  requireInk: (fn) ->
    if atom.packages.isPackageLoaded "ink" then fn()
    else
      require('atom-package-deps').install('julia-client')
        .then  -> fn()
        .catch ->
          atom.notifications.addError 'Installing the Ink package failed.',
            detail: 'Julia Client requires the Ink package to run.
                     Please install it manually from the settings view.'
            dismissable: true

  deactivate: ->
    x.deactivate() for x in [commands, menu, toolbar, @connection, @runtime, @ui]

  consumeInk: (ink) ->
    commands.ink = ink
    x.consumeInk ink for x in [@connection, @runtime, @ui]

  consumeStatusBar: (bar) ->
    @runtime.consumeStatusBar bar

  consumeToolBar: (bar) -> toolbar.consumeToolBar bar

  provideClient: -> @connection.client

  config: require './package/config'
  completions: -> require './runtime/completions'
