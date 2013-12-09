require 'settingslogic'

class Settings < Settingslogic
  source File.dirname(__FILE__) + '/config.yml'
end