#encoding: UTF-8
require "goliath"
require 'goliath/rack/templates'
require "em-synchrony/activerecord"
require "mysql2"
require "slim"
require "cgi"
require "./models"
require "./api"

dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig[Goliath.env.to_s])
Slim::Engine.set_default_options :pretty => true

class Server < Goliath::API
  include Goliath::Rack::Templates
  use Goliath::Rack::Params
  use(Rack::Static,
      :root => Goliath::Application.app_path('public'),
      :urls => ['/favicon.ico', '/css', '/js', '/img'])
  @@org = Organization.first

  def response(env)
    #TODO debug SQL queries & optimize
    #ActiveRecord::Base.logger = env.logger if Goliath.env.to_s == "development

    path = CGI.unescape(env['PATH_INFO']).split('/')
    if path[1] == 'api'
      API.call(env)
    else
      # check if cookie present
      if env.respond_to?(:HTTP_COOKIE)
        cookie = env.HTTP_COOKIE
      else
        cookie = "mycellogin=none"
      end

      # find current admin from cookie
      if cookie.match(/mycellogin/)
        env['admin'] = cookie.scan(/mycellogin=(\w+)/)[0][0]
      else
        env['admin'] = "none"
      end

      if env['admin'] == "none"
        if path[1] == 'setadmin'
          [200, {'Set-Cookie' => ["mycellogin=#{env.params['admin']}"]}, slim(:index)]
        else
          [401, {'Set-Cookie' => ["mycellogin=none"]}, slim(:login)]
        end
      else
        case path.length
        when 0    # matches /
          [200, {}, slim(:index)]
        when 2    # matches {branches}|users|statistics
          if @@org.branches.find_by_name(path[1])
            branch = Branch.find_by_name(path[1])
            if branch.authorized?(Admin.find_by_username(env['admin']))
              [200, {}, slim(:branch, :locals => {:branch => branch})]
            else
              [401, {}, slim(:forbidden)]
            end
          elsif path[1] == 'users'
            [200, {}, slim(:users, :locals => {:users => User.all})]
          elsif path[1] == 'branches'
            [200, {}, slim(:branches,
                           :locals => {:admin => Admin.find_by_username(env['admin'])})]
          elsif path[1] == 'statistics'
            [200, {}, slim(:statistics)]
          elsif path[1] == 'loggout'
            [200, {'Set-Cookie' => ["mycellogin=none"]}, slim(:login)]
          else    # matches non-existing branch
            raise Goliath::Validation::NotFoundError
          end
        when 3    # matches {branches}/{departments}
          if @@org.branches.find_by_name(path[1])
            if (dept = @@org.branches.find_by_name(path[1]).departments.find_by_name(path[2]))
              if dept.authorized?(Admin.find_by_username(env['admin']))
                [200, {}, slim(:department, :locals => {:department => dept, :screen_res => ScreenResolution.all })]
              else
                [401, {}, slim(:forbidden)]
              end

            else  # matches non-existing department
              raise Goliath::Validation::NotFoundError
            end
          else    # matches non-existing branch and/or department
            raise Goliath::Validation::NotFoundError
          end
        else      # matches everything else
          raise Goliath::Validation::NotFoundError
        end

      end
    end
  end

end