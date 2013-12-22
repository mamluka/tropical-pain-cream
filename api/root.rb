require 'grape'

class Root < Grape::API

  require_relative 'fromstack/formstack'
  require 'mail'

  Mail.defaults do
    delivery_method :smtp,
                    :address => 'smtp.gmail.com',
                    :port => 587,
                    :domain => 'gmail.com',
                    :authentication => :plain,
                    :user_name => 'david.mazvovsky@gmail.com',
                    :password => '095300acb',
                    :enable_starttls_auto => true
  end

  $settings = YAML.load File.read(File.dirname(__FILE__) +'/config.yml')

  mount FormStack
end
