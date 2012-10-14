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

# This plugin adjusts the time left for all users currently logged on.
# It's called every minute and substracts 1 minute from the users time
module Goliath
  module Plugin
    class TimeManager
      def initialize(port, config, status, logger)
        @logger = logger
      end

      def run
        EM.add_periodic_timer(60) do
          Fiber.new do
            @logger.info "Number of users logged on: #{Client.joins(:user).count}"
            for user in User.joins(:client).readonly(false).all
              user.minutes -= 1
              user.save
            end
          end.resume
        end
      end
    end
  end
end

# TODO move this to config files
dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig[Goliath.env.to_s])

class Server < Goliath::WebSocket
  plugin Goliath::Plugin::TimeManager

  def on_open(env)
    path = env['PATH_INFO'].split('/')
    env['type'] = path[2]
    env['id'] = path[3] || ""

    env['subscription'] = env.channels[env['type']+'/'+env['id']].subscribe { |m| env.stream_send(m) }
    env.logger.info("WS OPEN")
    #env.logger.debug("env.channels: #{env.channels}")
  end

  def on_close(env)
    env.channels[env['type']+'/'+env['id']].unsubscribe(env['subscription'])
    env.logger.info("WS CLOSED")
    #env.logger.debug("env.channels: #{env.channels}")
  end

  def on_message(env, message)
    msg = JSON.parse(message)
    env.logger.info("WS MESSAGE: #{msg}")

    Fiber.new do
      user = User.find_by_username msg["user"]
      client = Client.find msg["client"]

      case msg['action']
        when 'log-on'
          #NB must be authenticated! i.e user object must exist
          user.log_on client
          user.save

          timer = EM.add_periodic_timer(30) do
            Fiber.new do
              user.reload
              timer.cancel if user.client.nil?

              broadcast = JSON.generate({:status => "ping",
                                         :client => {:id => client.id},
                                         :user => {:name => user.name,
                                                   :id => user.id,
                                                   :minutes => user.minutes}})

              env.channels['clients/'+client.id.to_s] << broadcast
              env.channels['departments/'+client.department.id.to_s] << broadcast
              env.channels['users/'] << broadcast
            end.resume
          end

          env.logger.info("User: #{user.name} logged on client: #{client.name}")

          broadcast = JSON.generate({:status => "logged-on",
                                     :client => {:id => client.id,
                                                 :name => client.name,
                                                 :department => client.department.name,
                                                 :branch => client.department.branch.name},
                                     :user => {:name => user.name,
                                               :id => user.id,
                                               :minutes => user.minutes,
                                               :type => user.type_short}})

          env.channels['departments/'+client.department.id.to_s] << broadcast
          env.channels['clients/'+client.id.to_s] << broadcast
          env.channels['users/'] << broadcast
        when 'log-off'
          user.log_off
          user.save
          EM.cancel_timer(timer)

          env.logger.info("User: #{user.name} logged off client: #{client.name}")

          broadcast = JSON.generate({:status => "logged-off",
                                     :client => {:id => client.id},
                                     :user => {:name => user.name,
                                               :id => user.id,
                                               :minutes => user.minutes}})

          env.channels['departments/'+client.department.id.to_s] << broadcast
          env.channels['clients/'+client.id.to_s] << broadcast
          env.channels['users/'] << broadcast
      end
    end.resume
  end

  def on_error(env, error)
    env.logger.error error
  end

  def response(env)
    super(env)
  end
end