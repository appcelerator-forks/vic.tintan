require 'colors'
fs     = require 'fs'
path   = require 'path'
btoa   = require 'btoa'
coffee = require 'coffee-script'
exec   = require('child_process').exec
spawn  = require('child_process').spawn
touch  = require 'touch'
rimraf = require 'rimraf'

Tintan = null

compilerMap = (root, rexp, transform = ((i)->i), base = [], map = {})->
  dir = path.join.apply(path, [root].concat(base))
  fs.existsSync(dir) and fs.readdirSync(dir).forEach (f)->
    if fs.statSync(path.join(dir, f)).isDirectory()
      compilerMap(root, rexp, transform, base.concat(f), map)
    else if rexp.test(f)
      map[path.join(dir, f)] = transform(path.join.apply(path, base.concat([f])))
  map

class Coffee

  DEFAULT_OPTIONS =
    src: 'src/coffee'        # directory to take .coffee or .iced files from
    target: 'Resources'      # directory to put .js files into
    ext: '\.(coffee|iced)$'  # extensions to compile
    name: 'compile:coffee'   # name of the compiler task to generate


  init: (tintan, @options = {})->
    @options[k] = v for k,v of DEFAULT_OPTIONS when !@options.hasOwnProperty(k)
    @options.ext = (new RegExp @options.ext) if typeof @options.ext is 'string'
    options = @options

    from = Tintan.$._(options.src)
    target = Tintan.$._(options.target)
    map = @map = compilerMap from, options.ext, (f)-> path.join(target, f).replace(options.ext, '.js')

    compile = @compile
    sources = (s for s of map)
    return false if sources.length == 0
    compiled = (c for s, c of map)

    for s, c of map
      file c, [s], {async: true}, -> compile @prereqs[0], @name, complete

    Tintan.$.onTaskNamespace options.name, (name)->
      desc "Compile coffee-script sources into #{options.target}"
      task name, compiled, ->
        console.log 'compiled'.green + ' coffee-script sources into ' + options.target

    Tintan.$.onTaskNamespace options.name + ':force', ->
      desc "Compile all coffee-script (regardless of mod time) into #{options.target}"
      task 'force', ->
        for source, task of map then do (task) ->
          touch source, {mtime: true}, -> invoke task

    Tintan.$.onTaskNamespace options.name + ':dist', ->
      desc "Compile all coffee-script for distribution (no source maps) into #{options.target}"
      task 'dist', ->
        jake.program.envVars['source_maps'] = false
        invoke "#{options.name}:force"

    Tintan.$.onTaskNamespace options.name + ':clean', ->
      desc "Clean coffee-script produced files from #{options.target}"
      task 'clean', ->
        fs.unlink c for c in compiled

    Tintan.$.onTaskNamespace options.name + ':watch', =>
      watchTask 'watch', 'compile:coffee', ->
        @watchFiles.include [ options.ext ]

    true

  compile: (source, target, cb)=>
    jake.file.mkdirP path.dirname(target)
    c = fs.readFileSync source, 'utf-8'
    try
      conf = Tintan.config()
      iced = conf.envOrGet('iced')
      coffee = require('iced-coffee-script') if iced is true

      if conf.envOrGet('verbose') is true
        console.log('Compiling ' + target + ' with ' + (if iced then 'iced-' else '') + 'coffee-script' )

      if conf.envOrGet('source_maps') is true
        relativeSource = @options.src + source.split(@options.src)[-1..][0]
        compileOpts =
          sourceMap: true
          filename: source
          sourceFiles: ['file://' + process.cwd() + '/' + relativeSource]
          generatedFile: @options.target + target.split(@options.target)[-1..][0]
          runtime: "none"

        jsm = coffee.compile c, compileOpts
        j = jsm.js
        sm = jsm.v3SourceMap

        j =  "#{j}\n"
        j += "//# sourceMappingURL=data:application/json;base64,#{btoa unescape encodeURIComponent sm}\n"
        j += "//# sourceURL=#{relativeSource}"

      else
        j = coffee.compile c, runtime: "none"

      fs.writeFileSync target, j, 'utf-8'

    catch err
      process.stderr.write "Error compiling #{source}\n"
      process.stderr.write err.toString() + "\n"
      fail("Error compiling #{source}\n")
    cb()

  invokeTask: -> invoke @options.name

  invokeClean: -> invoke @options.name + ':clean'


class NodeModules
  DEFAULT_OPTIONS =
    src: 'node_modules'               # directory to take .coffee or .iced files from
    target: 'Resources/node_modules'  # directory to put .js files into
    name: 'compile:node_modules'      # name of the compiler task to generate

  init: (tintan, @options = {})->
    @options[k] = v for k,v of DEFAULT_OPTIONS when !@options.hasOwnProperty(k)
    options = @options

    from           = Tintan.$._(options.src)
    target         = Tintan.$._(options.target)
    package_json   = JSON.parse fs.readFileSync Tintan.$._('package.json'), 'utf-8'
    {dependencies} = package_json

    compile = @compile
    sources = (s for s of dependencies)
    return false if sources.length == 0
    compiled = ((path.join target, s) for s in sources)

    directory target
    for s in sources
      task s, [target], {async: true}, -> compile (path.join from, @name), @prereqs[0], complete

    for c in compiled
      task c, {async: true}, -> rimraf @name, complete

    Tintan.$.onTaskNamespace options.name, (name)->
      desc "Compile dependencies packages into #{options.target}"
      task name, sources, ->
        console.log 'compiled'.green + ' packages into ' + options.target

    Tintan.$.onTaskNamespace options.name + ':clean', ->
      desc "Clean node_modules from #{options.target}"
      task 'clean', compiled, ->
        console.log 'cleaned'.green + ' packages from ' + options.target


  compile: (source, target, cb)=>
    cmd = 'cp -R ' + source + ' ' + target

    try
      conf = Tintan.config()
      if conf.envOrGet('verbose') is true
        console.log('Compiling ' + source + ' to ' + target )

      exec cmd, (err, stdout, stderr) ->
        throw err if err

    catch err
      process.stderr.write "Error compiling #{source}\n"
      process.stderr.write err.toString() + "\n"
      fail("Error compiling #{source}\n")
    cb()

  invokeTask: -> invoke @options.name

  invokeClean: -> invoke @options.name + ':clean'


Compilers =
  coffee: Coffee
  node_modules: NodeModules

module.exports = (tintan)->

  Tintan = tintan.constructor

  compilers = []

  Tintan.$.onTaskNamespace 'compile', (name) ->
    desc 'Compile sources'
    task name, ->
      compiler.invokeTask() for compiler in compilers

  Tintan.$.onTaskNamespace 'compile:dist', ->
    desc 'Compile sources for distribution'
    task 'dist', ->
      invoke "#{compiler.options.name}:dist" for compiler in compilers

  tintan.compile = (lang, args...)->
    Compiler = Compilers[lang]
    fail "Dont know how to compile #{lang}".red unless Compiler
    compiler = new Compiler
    compilers.push compiler if compiler.init.apply compiler, [tintan].concat(args)
