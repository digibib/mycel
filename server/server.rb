#encoding: UTF-8
require 'goliath'
require 'goliath/websocket'
require 'goliath/rack/templates'
require "em-synchrony/activerecord"
require "mysql2"
require "slim"
require "cgi"
require "./models"
require "./api"

# TODO move this to config files
dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig[Goliath.env.to_s])

class Server < Goliath::WebSocket

  def on_open(env)
    env.logger.info("WS OPEN")
    env['subscription'] = env.channel.subscribe { |m| env.stream_send(m) }
    timer = EM::PeriodicTimer.new 1 do
      env.channel << "ping"
    end
  end

  def on_message(env, msg)
     env.logger.info JSON.parse(msg)

    #env.channel << msg
  end

  def on_close(env)
    env.logger.info("WS CLOSED")
    env.channel.unsubscribe(env['subscription'])
    timer.cancel
  end

  def on_error(env, error)
    env.logger.error error
  end

  def response(env)
    super(env)
  end
end
