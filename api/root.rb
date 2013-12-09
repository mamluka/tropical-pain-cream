require 'grape'

require_relative 'settings'

class Root < Grape::API

  require_relative 'fromstack/formstack'

  mount FormStack
end
