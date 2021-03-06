fs = require 'fs'


foundJavaHome = ->
  java_home = process.env.JAVA_HOME
  unless java_home and fs.existsSync java_home
    console.warn "Error: JAVA_HOME not set.  Will not be able to compile!"
    return
  true


module.exports = (tintan)->
  Tintan = tintan.constructor

  namespace 'distribute', ->

    if Tintan.appXML().targets 'android'
      desc 'Build final android distribution package for upload to marketplace'
      task 'android', ['compile:dist'], {async: true}, ->
        return unless foundJavaHome()

        conf = Tintan.config()
        android_avd = process.env.AVD
        android_avd or= conf.envOrGet('android_avd')

        # builder.py <command> <project_name> <sdk_dir> <project_dir> <app_id> [key] [password] [alias] [dir] [avdid] [avdskin] [avdabi]
        Tintan.$.tipy ['android', 'builder.py'], 'distribute',
          Tintan.appXML().name(), Tintan.$.android_home(), process.cwd(), Tintan.appXML().id(),
          conf.envOrGet('keystore'), conf.envOrGet('storepass'),
          conf.envOrGet('key_alias'), Tintan.$._('./'),
          Tintan.$.android_version(), android_avd,
          complete

    if Tintan.appXML().targets 'android'
      desc 'Build android package with default debug keystore for upload to TestFlight'
      task 'tf-android', ['compile'], {async: true}, ->
        return unless foundJavaHome()

        android_avd = process.env.AVD
        android_avd or= Tintan.config().envOrGet('android_avd')

        Tintan.$.tipy ['android', 'builder.py'], 'distribute',
          Tintan.appXML().name(), Tintan.$.android_home(), process.cwd(), Tintan.appXML().id(),
          '~/.android/debug.keystore', 'android', 'androiddebugkey', Tintan.$._('./'),
          Tintan.$.android_version(), android_avd,
          complete


    if Tintan.$.os is 'osx'
      if Tintan.appXML().targets 'ipad'
        desc 'Build final ipad distribution package for upload to marketplace'
        task 'ipad', ['compile:dist'], {async: true}, ->
          Tintan.$.tipy ['iphone', 'builder.py'], 'distribute',
            Tintan.$.ios_version(), process.cwd(), Tintan.appXML().id(), Tintan.appXML().name(),
            'ipad', 'retina',
            complete

      if Tintan.appXML().targets 'iphone'
        desc 'Build final iphone distribution package for upload to marketplace'
        task 'iphone', ['compile:dist'], {async: true}, ->
          Tintan.$.tipy ['iphone', 'builder.py'], 'distribute',
            Tintan.$.ios_version(), process.cwd(), Tintan.appXML().id(), Tintan.appXML().name(),
            'iphone', 'retina',
            complete
