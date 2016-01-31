child_process = require 'child_process'
net =           require 'net'
path =          require 'path'
fs =            require 'fs'

client = require './client'
{console: cons} = require '../ui'

module.exports = jlprocess =

  activate: ->
    @cmds = atom.commands.add 'atom-workspace',
      'julia-client:kill-julia': => @killJulia()
      'julia-client:interrupt-julia': => @interruptJulia()

  deactivate: ->
    @cmds.dispose()

  bundledExe: ->
    res = path.dirname atom.config.resourcePath
    exe = if process.platform is 'win32' then 'julia.exe' else 'julia'
    p = path.join res, 'julia', 'bin', exe
    if fs.existsSync p then p

  packageDir: (s...) ->
    packageRoot = path.resolve __dirname, '..', '..'
    resourcePath = atom.config.resourcePath
    if path.extname(resourcePath) is '.asar' and packageRoot.indexOf(resourcePath) is 0
        packageRoot = path.join("#{resourcePath}.unpacked", 'node_modules', 'julia-client')
    path.join packageRoot, s...

  script: (s...) -> @packageDir 'script', s...

  workingDir: ->
    paths = atom.workspace.project.getDirectories()
    if paths.length == 1 and fs.statSync(paths[0].path).isDirectory()
      paths[0].path
    else
      process.env.HOME || process.env.USERPROFILE

  jlpath: ->
    p = atom.config.get("julia-client.juliaPath")
    if p == '[bundle]' then p = @bundledExe()
    p

  checkPath: (path) ->
    new Promise (resolve) ->
      fs.exists path, (exists) ->
        if exists
          resolve true
        else
          which = if process.platform is 'win32' then 'where' else 'which'
          proc = child_process.spawn which, [path]
          proc.on 'exit', (status) ->
            resolve status == 0

  jlNotFound: (path) ->
    atom.notifications.addError "Julia could not be found.",
      detail: """
      We tried to launch Julia from:
      #{path}

      This path can be changed in the settings.
      """
      dismissable: true

  start: (port) ->
    return if @proc?
    client.booting()

    @checkPath(@jlpath()).then (exists) =>
      if not exists
        @jlNotFound @jlpath()
        client.cancelBoot()
        return

      @spawnJulia port, cons, =>
        @proc.on 'exit', (code, signal) =>
          cons.c.err "Julia has stopped"
          if not @useWrapper then cons.c.err ": #{code}, #{signal}"
          cons.c.input() unless cons.c.isInput
          @proc = null
          client.cancelBoot()
        @proc.stdout.on 'data', (data) =>
          text = data.toString()
          if text then cons.c.out text
          if text and @pipeConsole then console.log text
        @proc.stderr.on 'data', (data) =>
          text = data.toString()
          if text then cons.c.err text
          if text and @pipeConsole then console.info text

  spawnJulia: (port, cons, fn) ->
    if process.platform is 'win32' and atom.config.get("julia-client.enablePowershellWrapper")
      @useWrapper = parseInt(child_process.spawnSync("powershell",
                                                    ["-NoProfile", "$PSVersionTable.PSVersion.Major"])
                                          .output[1].toString()) > 2
      if @useWrapper
        # get a random port between 1000 and 20_000; this may not be free, of course,
        # but hopefully not very often
        @getFreePort =>
          @proc = child_process.spawn("powershell",
                                      ["-NoProfile", "-ExecutionPolicy", "bypass",
                                       "& \"#{@script "spawnInterruptible.ps1"}\"
                                        -cwd \"#{@workingDir()}\"
                                        -port #{port}
                                        -wrapPort #{@wrapPort}
                                        -jlpath \"#{@jlpath()}\"
                                        -boot \"#{@script 'boot.jl'}\""])
          fn()
      else
        cons.c.out "PowerShell version < 3 encountered. Running without wrapper (interrupts won't work)."
    @proc = child_process.spawn(@jlpath(), [@script("boot.jl"), port], cwd: @workingDir())
    fn()

  getFreePort: (fn) ->
    server = net.createServer()
    server.listen 0, 'localhost', =>
      @wrapPort = server.address().port
      server.close()
      fn()

  # TODO: make 'kill' try to exit gracefully first

  require: (f) ->
    if not @proc
      atom.notifications.addError "There's no Julia process running.",
        detail: "Try starting one by evaluating something."
    else
      f()

  interruptJulia: ->
    @require =>
      if @useWrapper
        @sendSignalToWrapper('SIGINT')
      else
        @proc.kill('SIGINT')

  killJulia: ->
    @require =>
      if @useWrapper
        @sendSignalToWrapper('KILL')
      else
        @proc.kill()

  sendSignalToWrapper: (signal) ->
    wrapper = net.connect(port: @wrapPort)
    wrapper.setNoDelay()
    wrapper.write(signal)
    wrapper.end()

client.onDisconnected ->
  if jlprocess.useWrapper and jlprocess.proc
    jlprocess.proc.kill()
