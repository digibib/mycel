require "em-synchrony/activerecord"
require "goliath"
require 'goliath/rack/templates'
require "slim"
require "./models"


dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig["development"]) #TODO Goliath env

class Server < Goliath::API
  include Goliath::Rack::Templates
  @@org = Organization.first

  use(Rack::Static,
      :root => Goliath::Application.app_path('public'),
      :urls => ['/favicon.ico', '/css', '/js', '/img'])
  use ::Rack::Reloader, 0 if Goliath.dev?

  def response(env)
    [200, {}, slim(:index, :locals => {:title =>@@org.name})]
  end
end