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
user => user (Library card number) or guest username

client
======
client => client (MAC address)

action
======
"log-on"
"log-off"
"adjust-minutes" + "minutes" => integer (positive adds, negative substracts)
"authenticate" + "PIN" => 4 numbers (as string)
"send-message" + "message"
"subscribe" => when the web views (interface) connects

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
{:client => "00:44:ab:3a:e3:05", :action => "send-message",
 :message => "The library closes in 10 minutes!" You will be logged out in 5 minutes.}
=end

class Server < Goliath::WebSocket
  #Channels:
  # One for each client  env.channels['client-mac']
  # One for all clients  env.channels['all']
  # One for department   env.channels['dept-id'] (id = nr from db)
  # One for branch       env.channels['branch-id']

  def on_open(env)
    env.logger.info("WS OPEN")
    #env['subscription'] = env.channel.subscribe { |m| env.stream_send(m) }
    # timer = EM::PeriodicTimer.new 10 do
    #   env.channel << "ping"
    # end
  end

  def on_message(env, msg)
    message = JSON.parse(msg)

    # wrap in fiber
    Fiber.new do

      # get user & client objects
      user = User.find_by_username message["user"]
      client = Client.find_by_hwaddr message["client"]

      case message["action"]
        when "subscribe"
          env.logger.info "deptartment #{message['department']} connected and subscribed"
          env.channels['dept-'+message['department'].to_s].subscribe { |m| env.stream_send(m) }
        when "authenticate"
          # 1. check db
          # 2. sip2
          # 3. create user object if success
        when "log-on"
          #NB must be authenticated first! (i.e. user object must be present)
          return unless user and client

          user.log_on client
          user.save

          env.logger.info "User: #{user.username} logs on to client: #{client.name}"
          #subscribe the channels: client, department
          env.channels[client.hwaddr].subscribe { |m| env.stream_send(m) }
          env.channels['dept-'+client.department.id.to_s].subscribe { |m| env.stream_send(m) }
          # broadcast message
          message = {:status => "logged-on", :client => client.id, :user => user.username}
          env.channels['dept-'+client.department.id.to_s] << JSON.generate(message)

        when "log-off"
         user.log_off
         user.save

         env.logger.info "User: #{user.username} logs off client: #{client.name}"
         # broadcast message
         message = JSON.generate({:status => "logged-off", :client => client.id, :user => user.username})
         env.channels['dept-'+client.department.id.to_s] << message
         env.channels[message["client"]] << message
         #env.channels[message["client"]].unsubscribe(sid)
      end

    end.resume
  end

  def on_close(env)
    env.logger.info("WS CLOSED")
    #env.channel.unsubscribe(env['subscription'])
  end

  def on_error(env, error)
    env.logger.error error
  end

  def response(env)
    super(env)
  end
end
