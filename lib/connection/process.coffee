{Emitter} =     require 'atom'
child_process = require 'child_process'
net =           require 'net'
path =          require 'path'
fs =            require 'fs'

client = require './client'

{exit} = client.import 'exit'

module.exports = jlprocess =

  activate: ->
    @cmds = atom.commands.add 'atom-workspace',
      'julia-client:kill-julia': => @killJulia()
      'julia-client:interrupt-julia': => @interruptJulia()
    @emitter = new Emitter

  deactivate: ->
    @cmds.dispose()

  bundledExe: ->
    res = path.dirname atom.config.resourcePath
    p = path.join res, 'julia', 'bin', @executable()
    if fs.existsSync p then p

  executable: ->
    if process.platform is 'win32' then 'julia.exe' else 'julia'

  isBundled: -> !!@bundledExe()

  packageDir: (s...) ->
    packageRoot = path.resolve __dirname, '..', '..'
    resourcePath = atom.config.resourcePath
    if path.extname(resourcePath) is '.asar' and packageRoot.indexOf(resourcePath) is 0
        packageRoot = path.join("#{resourcePath}.unpacked", 'node_modules', 'julia-client')
    path.join packageRoot, s...

  script: (s...) -> @packageDir 'script', s...

  withWorkingDir: (fn) ->
    paths = atom.workspace.project.getDirectories()
    # default to HOME as working dir for julia
    wd = process.env.HOME || process.env.USERPROFILE
    if paths.length > 0
      # use the first open project folder (or its parent folder for files) if
      # it is valid
      fs.stat paths[0].path, (err, stats) =>
        if not err?
          if stats.isFile()
            wd = path.dirname paths[0].path
          else
            wd = paths[0].path
        fn wd

  jlpath: ->
    p = atom.config.get("julia-client.juliaPath")
    if p == '[bundle]' then p = @bundledExe()
    p

  checkPath: (p) ->
    new Promise (resolve, reject) =>
      # check whether path exists
      fs.stat p, (err, stats) =>
        if not err
          # and is a file
          if stats.isFile() then resolve(); return
          # if it isn't, look for a file called `julia(.exe)`
          fs.readdir p, (err, files) =>
            if err or files.indexOf(@executable()) < 0 then reject(); return
            newpath = path.join p, @executable()
            # check whether that file is no directory
            fs.stat newpath, (err, fstats) =>
              # change the `Julia Path` setting to that new path and carry on
              if not fstats.isFile() then reject(); return
              atom.config.set 'julia-client.juliaPath', newpath
              resolve()
        # fallback to calling `which` or `where` on the path
        else
          which = if process.platform is 'win32' then 'where' else 'which'
          proc = child_process.spawn which, [p]
          proc.on 'exit', (status) ->
            if status is 0 then resolve() else reject()

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

    @checkPath(@jlpath())
      .then =>
        @spawnJulia port, =>
          @proc.on 'exit', (code, signal) =>
            @emitter.emit 'stderr', "Julia has stopped"
            if not @useWrapper then @emitter.emit 'stderr', ": #{code}, #{signal}"
            @proc = null
            client.cancelBoot()
          @proc.stdout.on 'data', (data) =>
            text = data.toString()
            if text then @emitter.emit 'stdout', text
            if text and @pipeConsole then console.log text
          @proc.stderr.on 'data', (data) =>
            text = data.toString()
            if text then @emitter.emit 'stderr', text
            if text and @pipeConsole then console.info text
      .catch =>
        @jlNotFound @jlpath()
        client.cancelBoot()

  spawnJulia: (port, fn) ->
    @withWorkingDir (workingdir) =>
      if process.platform is 'win32' and atom.config.get("julia-client.enablePowershellWrapper")
        @useWrapper = parseInt(child_process.spawnSync("powershell",
                                                      ["-NoProfile", "$PSVersionTable.PSVersion.Major"])
                                            .output[1].toString()) > 2
        if @useWrapper
          @getFreePort =>
            @proc = child_process.spawn("powershell",
                                        ["-NoProfile", "-ExecutionPolicy", "bypass",
                                         "& \"#{@script "spawnInterruptible.ps1"}\"
                                         -cwd \"#{workingdir}\"
                                         -port #{port}
                                         -wrapPort #{@wrapPort}
                                         -jlpath \"#{@jlpath()}\"
                                         -boot \"#{@script 'boot.jl'}\""])
            fn()
          return
        else
          @emitter.emit 'stdout', "PowerShell version < 3 encountered. Running without wrapper (interrupts won't work)."
      @proc = child_process.spawn(@jlpath(), ["-i", @script("boot.jl"), port], cwd: workingdir)
      fn()

  getFreePort: (fn) ->
    server = net.createServer()
    server.listen 0, '127.0.0.1', =>
      @wrapPort = server.address().port
      server.close()
      fn()

  onStdout: (f) -> @emitter.on 'stdout', f
  onStderr: (f) -> @emitter.on 'stderr', f

  require: (f) ->
    if not @proc
      atom.notifications.addError "There's no Julia process running.",
        detail: "Try starting one by evaluating something."
    else
      f()

  interruptJulia: ->
    @require =>
      if client.isConnected() and client.isWorking()
        if @useWrapper
          @sendSignalToWrapper('SIGINT')
        else
          @proc.kill('SIGINT')

  killJulia: ->
    if client.isConnected() and not client.isWorking()
      exit()
    else
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
