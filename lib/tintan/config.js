// Generated by CoffeeScript 1.6.3
(function() {
  module.exports = function(tintan) {
    var Tintan, config_options;
    Tintan = tintan.constructor;
    config_options = [];
    namespace('config', function() {
      if (jake.program.taskNames[0].split(':').length < 2) {
        config_options.push('config:all');
      }
      desc('Initialize options to default values');
      task('init', function() {
        return Tintan.config().init();
      });
      desc('Configure all options');
      task('all', function() {
        return Tintan.config().promptForAll();
      });
      desc('Show value of all options');
      task('display', function() {
        return Tintan.config().display();
      });
      desc('Set a particular value. Usage: config:set option=[value|default]');
      return task('set', function() {
        return Tintan.config().set(jake.program.envVars);
      });
    });
    desc('Configure Tintan');
    return task('config', config_options);
  };

}).call(this);

/*
//@ sourceMappingURL=config.map
*/
