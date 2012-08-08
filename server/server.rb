#encoding: UTF-8
require "em-synchrony/activerecord"
require "goliath"
require 'goliath/rack/templates'
require "slim"
require "cgi"
require_relative "models"
require_relative "api"

dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig[Goliath.env.to_s])

class Server < Goliath::API
  use Goliath::Rack::Params          # parse & merge query and body parameters
  include Goliath::Rack::Templates   # serve templates from /views

  use(Rack::Static,
      :root => Goliath::Application.app_path('public'),
      :urls => ['/favicon.ico', '/css', '/js', '/img'])

  # get access to organization object
  @@org = Organization.first

  def response(env)
    path = CGI.unescape(env['PATH_INFO']).split('/')
    # TODO: refactor this ugly routing!!
    case path.length
    when 0    # matches /
      [200, {}, slim(:index)]
    when 2    # matches /branch
      if @@org.branches.find_by_name(path[1])
        [200, {}, slim(:branch, :locals => {:branch => Branch.find_by_name(path[1])})]
              # or matches /ws for websocket communication:
      elsif path[1] == 'ws'
        super(env)
      elsif path[1] == 'users'
        [200, {}, slim(:users, :locals => {:users => User.all})]
      elsif path[1] == 'branches'
        [200, {}, slim(:branches)]
      elsif path[1] == 'statistics'
        [200, {}, slim(:statistics)]
      else    # matches non-existing branch
        raise Goliath::Validation::NotFoundError
      end
    when 3    # matches /branch/department
      if @@org.branches.find_by_name(path[1])
        # TODO: tidy up this
        if (dept = @@org.branches.find_by_name(path[1]).departments.find_by_name(path[2]))
        [200, {}, slim(:department, :locals => {:department => dept, :screen_res => ScreenResolution.all })]
        else  # matches non-existing department
          raise Goliath::Validation::NotFoundError
        end
      elsif path[1] == 'api' # Dispatch api-calls to grape
        #raise Goliath::Validation::UnauthorizedError unless env['REMOTE_ADDR'] == "127.0.0.1"
        API.call(env)
      else    # matches non-existing branch and/or department
        raise Goliath::Validation::NotFoundError
      end
    when 4
      if path[1] == 'api' # Dispatch api-calls to grape
        #raise Goliath::Validation::UnauthorizedError unless env['REMOTE_ADDR'] == "127.0.0.1"
        API.call(env)
      else
        raise Goliath::Validation::NotFoundError
      end
    else      # matches everything else
      raise Goliath::Validation::NotFoundError
    end
  end
end
