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
            @logger.info "Users logged on: #{Client.joins(:user).count}, Total clients: #{Client.count}"
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

dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig[Goliath.env.to_s])

class Server < Goliath::WebSocket
  plugin Goliath::Plugin::TimeManager

  def on_open(env)
    path = env['PATH_INFO'].split('/')
    env['type'] = path[2]
    env['id'] = path[3] || ""

    env['subscription'] = env.channels[env['type']+'/'+env['id']].subscribe { |m| env.stream_send(m) }
    #env.logger.debug("env.channels: #{env.channels}")
  end

  def on_close(env)
    env.channels[env['type']+'/'+env['id']].unsubscribe(env['subscription'])
    #env.logger.debug("env.channels: #{env.channels}")

    # Log off manually if the client was unintentionally disconnected
    if env['user']
      Fiber.new do
        if env['user'].client
          env.logger.error("#{env['user'].log_friendly}, disconnected from: #{env['user'].client.log_friendly}")
          env.logger.info("#{env['user'].log_friendly}, logged off: #{env['user'].client.log_friendly}")
          env['user'].log_off
          EM.cancel_timer(env['timer']) if env['timer']
        end
      end.resume
    end

  end

  def on_message(env, message)
    msg = JSON.parse(message)
    #env.logger.debug("WS MESSAGE: #{msg}")

    Fiber.new do
      user = User.find_by_username msg["user"]
      client = Client.find msg["client"]

      case msg['action']
        when 'log-on'
          #NB must be authenticated! i.e user object must exist
          user.log_on client
          user.save
          env['user'] = user

          env['timer'] = EM.add_periodic_timer(30) do
            Fiber.new do
              user.reload
              env['timer'].cancel if user.client.nil?

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

          env.logger.info("#{user.log_friendly}, logged on: #{client.log_friendly}")

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
          EM.cancel_timer(env['timer'])

          env.logger.info("#{user.log_friendly}, logged off: #{client.log_friendly}")

          broadcast = JSON.generate({:status => "logged-off",
                                     :client => {:id => client.id},
                                     :user => {:name => user.name,
                                               :id => user.id,
                                               :minutes => user.minutes}})

          env.channels['departments/'+client.department.id.to_s] << broadcast
          env.channels['clients/'+client.id.to_s] << broadcast
          env.channels['users/'] << broadcast
          env['user'] = nil
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