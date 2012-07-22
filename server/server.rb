require "em-synchrony/activerecord"
require "goliath"
require 'goliath/rack/templates'
require "slim"
require "./models"
require "cgi"

dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig[Goliath.env.to_s])

class SaveUser < Goliath::API

  def response(env)
    puts params.to_s
    puts params['username']
    puts params['password']
    puts params['age']
    puts params['minutes']

    if params['age'] == 'adult'
      age = 20
    else
      age = 10
    end

    newuser = User.create(:name => params['username'], :password => params['password'],
      :age => age, :minutes => params['minutes'])

    [200, {}, 'Brukeren #{newuser.name} lagret.']
  end
end


class SaveClientOptions < Goliath::API

  def response(env)
    puts params.to_s
    [200, {}, 'user saved']
  end
end

class Server < Goliath::API
  use Goliath::Rack::Params          # parse & merge query and body parameters
  include Goliath::Rack::Templates   # serve templates from /views

  use(Rack::Static,
      :root => Goliath::Application.app_path('public'),
      :urls => ['/favicon.ico', '/css', '/js', '/img'])

  # get access to organization object
  @@org = Organization.first

  def response(env)
    # (not to elegant) URL-routing:
    # I will try to implement this in Grape, as soon as I find out how
    # to serve template views from Grape endpoints
    if env['REQUEST_METHOD'] == 'POST'
      puts "its a post!"
      case env['PATH_INFO']
      when '/saveuser'
        SaveUser.new.call(env)
      when '/saveclientoptions'
        SaveClientOptions.new.call(env)
      else
        raise Goliath::Validation::BadRequestError
      end
    end

    path = CGI.unescape(env['PATH_INFO']).split('/')
    case path.length
    when 0    # matches /
      [200, {}, slim(:index, :locals => {:org => @@org})]
    when 2    # matches /branch
      if @@org.branches.find_by_name(path[1])
        [200, {:branch => path[1]}, "filial"]
              # or matches /ws for websocket communication:
      elsif path[1] == 'ws'
        super(env)
      else    # matches non-existing branch
        raise Goliath::Validation::NotFoundError
      end
    when 3    # matches /branch/department
      if @@org.branches.find_by_name(path[1])
        # TODO: tidy up this
        if (dept = @@org.branches.find_by_name(path[1]).departments.find_by_name(path[2]))
        [200, {}, slim(:department, :locals => {:department => dept})]
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
