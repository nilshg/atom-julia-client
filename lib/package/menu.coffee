{CompositeDisposable} = require 'atom'

module.exports =
  activate: ->
    @subs = new CompositeDisposable
    # Package submenu
    @subs.add atom.menu.add [{
      label: 'Packages',
      submenu: @menu
    }]

    # App Menu
    if atom.config.get 'julia-client.enableMenu'
      @subs.add = atom.menu.add @menu
      # TODO: find a less hacky way to do this
      menu = atom.menu.template.pop()
      atom.menu.template.splice 3, 0, menu

  deactivate: ->
    @subs.dispose()

  menu: [{
    label: 'Julia'
    submenu: [
      {label: 'Start Julia', command: 'julia-client:start-julia'}
      {label: 'Stop Julia', command: 'julia-client:kill-julia'}
      {label: 'Interrupt Julia', command: 'julia-client:interrupt-julia'}
      {label: 'Open Terminal', command: 'julia-client:open-a-repl'}
      {
        label: 'Working Directory'
        submenu: [
          {label: 'Current File\'s Folder', command: 'julia-client:work-in-file-folder'}
          {label: 'Current Project\'s Folder', command: 'julia-client:work-in-project-folder'}
          {label: 'Home Folder', command: 'julia-client:work-in-home-folder'}
        ]
      }

      {type: 'separator'}

      {label: 'Evaluate', command: 'julia-client:evaluate'}
      {label: 'Evaluate All', command: 'julia-client:evaluate-all'}
      {label: 'Open Console', command: 'julia-client:open-console'}
      {label: 'Clear Console', command: 'julia-client:clear-console'}

      {type: 'separator'}

      {label: 'Open Startup File', command: 'julia:open-startup-file'}
      {label: 'Open Julia Home', command: 'julia:open-julia-home'}
      {label: 'Open Package in New Window...', command: 'julia:open-package-in-new-window'}

      {type: 'separator'}

      {label: 'Settings...', command: 'julia-client:settings'}
    ]
  }]
