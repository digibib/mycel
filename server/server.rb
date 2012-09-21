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

=begin
WS JSON PROTOCOL:

user
======
user => user (Library card number)

client
======
client => client (MAC address)

action
======
"log-on"
"log-off"
"adjust-minutes" + "minutes" => integer (positive adds, negative substracts)
"authenticate" + "PIN" => 4 numbers (as string)

status
======
"logged-in"
"logged-out"
"authenticated"
"not-authenticated"
"bad-request" => malformed, or missing parameters

Examples:
{:user => "N00123456", :action => "authenticate", :pin => "1234"}
{:user => "N03456784", :client => "00:44:ab:3a:e3:05", :action => "log-on"}
{:user => "N03456784", :client => "00:44:ab:3a:e3:05",
 :action => "adjust-minutes", :minutes => 10}
=end

class Server < Goliath::WebSocket

  def on_open(env)
    env.logger.info("WS OPEN")
    env['subscription'] = env.channel.subscribe { |m| env.stream_send(m) }
    timer = EM::PeriodicTimer.new 10 do
      env.channel << "ping"
    end
  end

  def on_message(env, msg)
    message = JSON.parse(msg)

    case message["action"]
      when "log-on"
        env.logger.info "User: #{message['user']} logs on to client: #{message['client']}"
      when "log-off"
       env.logger.info "User: #{message['user']} logs off client: #{message['client']}"
       env.channel << JSON.generate({:status => "logged-off"})
    end

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
