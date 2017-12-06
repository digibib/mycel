#encoding: UTF-8
require 'goliath'
require 'goliath/websocket'
require 'goliath/rack/templates'
require "em-synchrony/activerecord"
require "mysql2"
require "./models"
require "./api"
require "./config/settings"

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
            Client.all.each do |client|
              client.update_logon_events
            end
          end.resume
        end

        EM.add_periodic_timer(60) do
          Fiber.new do
            # log format: type  active-users                 num-clients
            @logger.info "stats #{Client.joins(:user).count} #{Client.count}"
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

ActiveRecord::Base.establish_connection(Settings::DB[Goliath.env.to_sym])

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
          user = env['user']
          client = env['user'].client
          env.logger.info("event #{user.type} #{user.id} #{user.age_log} disconnect #{client.log_friendly}")

          broadcast = JSON.generate({:status => "logged-off",
                                     :client => {:id => client.id,
                                                 :dept_id => client.department.id},
                                     :user => {:name => user.name,
                                               :username => user.username,
                                               :id => user.id,
                                               :minutes => user.minutes,
                                               :type => user.type_short}})

          env.channels['departments/'+client.department.id.to_s] << broadcast
          env.channels['users/'] << broadcast
          env.channels['branches/'] << broadcast

          env['user'].log_off if env['user']
          env.logger.info("event #{user.type} #{user.id} #{user.age_log} log-off #{client.log_friendly}")
          EM.cancel_timer(env['timer']) if env['timer']
        end
      end.resume
    end

  end

      def on_message(env, message)
        msg = JSON.parse(message)
        #env.logger.debug("WS MESSAGE: #{msg}")
        Fiber.new do
          begin
            env['client'] ||= Client.find msg["client"]
            if msg["user"] == "Anonym"
              env['user'] ||= env['client'].user || AnonymousUser.create(:minutes=>env['client'].options_self_or_inherited['shorttime_limit'])
            else
              env['user'] ||= User.find_by_username msg["user"]
            end
          rescue Exception => e
            env['user'] = nil
            env.logger.error(e.message)
            #env.logger.error(e.backtrace)
            env.logger.error("trying to find this user: #{msg['user']}")
          end


      if env['user'] && env['client']
        if msg['status'] == "cmd-output"
          # stub implementation for remote command execution over WS commented out
          # env.channels['admin/1'] << msg.to_json
        end

        case msg['action']
          when 'log-on'
            #NB must be authenticated! i.e user object must exist
            client = env['client']
            user = env['user']
            user.log_on client
            #user.save

            env['timer'] = EM.add_periodic_timer(30) do
              Fiber.new do
                user.reload
                env['timer'].cancel if user.client.nil?

                broadcast = JSON.generate({:status => "ping",
                                           :client => {:id => client.id,
                                                       :dept_id => client.department.id},
                                           :user => {:name => user.name,
                                                     :username => user.username,
                                                     :id => user.id,
                                                     :minutes => user.minutes,
                                                     :type => user.type_short}})

                env.channels['clients/'+client.id.to_s] << broadcast
                env.channels['departments/'+client.department.id.to_s] << broadcast
                env.channels['users/'] << broadcast
              end.resume
            end

            # log format:    type    who          who-id   who-age         actionS    where
            env.logger.info("event #{user.type} #{user.id} #{user.age_log} log-on #{client.log_friendly}")

            broadcast = JSON.generate({:status => "logged-on",
                                       :client => {:id => client.id,
                                                   :dept_id => client.department.id,
                                                   :name => client.name,
                                                   :department => client.department.name,
                                                   :branch => client.department.branch.name},
                                       :user => {:name => user.name,
                                                 :username => user.username,
                                                 :id => user.id,
                                                 :minutes => user.minutes,
                                                 :type => user.type_short}})

            env.channels['departments/'+client.department.id.to_s] << broadcast
            env.channels['clients/'+client.id.to_s] << broadcast
            env.channels['users/'] << broadcast
            env.channels['branches/'] << broadcast
          when 'log-off'
            user = env['user']
            client = env['client']
            user.log_off
            #user.save
            EM.cancel_timer(env['timer'])
            # log format:    type    who          who-id   who-age         action    where
            env.logger.info("event #{user.type} #{user.id} #{user.age_log} log-off #{client.log_friendly}")

            broadcast = JSON.generate({:status => "logged-off",
                                       :client => {:id => client.id,
                                                   :dept_id => client.department.id},
                                       :user => {:name => user.name,
                                                 :username => user.username,
                                                 :id => user.id,
                                                 :minutes => user.minutes,
                                                 :type => user.type_short}})

            env.channels['departments/'+client.department.id.to_s] << broadcast
            env.channels['clients/'+client.id.to_s] << broadcast
            env.channels['users/'] << broadcast
            env.channels['branches/'] << broadcast

            env['user'] = nil
          end
          # begins highly unsafe code, commented out for now
        else
          case msg['status']
          when 'cmd'
            # env.channels['clients/245'] << msg.to_json
          when 'cmd-output'
            #
          else
            #
          end
          # highly unsafe code ends
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
