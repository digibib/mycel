#encoding: UTF-8
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

    if params['age'] == 'adult'
      age = 20
    else
      age = 10
    end
    begin
      guest = GuestUser.create!(:username => params['username'], :password => params['password'],
        :age => age, :minutes => params['minutes'])
      [200, {}, 'Brukeren "' + guest.username + '" er opprettet.']
    rescue ActiveRecord::RecordInvalid
      [400, {}, 'Brukeren "' + params['username'] + '" finnes allerede. Velg et annet brukernavn']
    rescue Exception => e
      puts e.class # TODO log this!
      puts e
      [500, {}, 'Noe gikk galt. Brukeren ble ikke lagret.']
    end
  end
end


class SaveClientOptions < Goliath::API

  def response(env)
    puts params.to_s
    begin
      client = Client.find(params['client_id'])
      client.update_attributes!(:shorttime => params['shorttime'],
                                :screen_resolution_id => params['screenres'])
      [200, {}, 'Innstilliger lagret.']
    rescue Exception => e
      puts e.class # TODO log this!
      puts e
      [500, {}, 'Server error: endringene ble ikke lagret']
    end

  end
end

class SaveOpeningHours < Goliath::API
  def response(env)
    puts params.to_s
    hours_old = OpeningHours.find(params['opening_hours_id'])

    hours_new = OpeningHours.new(
      :monday_opens => params['monday_opens'], :monday_closes => params['monday_closes'],
      :tuesday_opens => params['tuesday_opens'], :tuesday_closes => params['tuesday_closes'],
      :wednsday_opens => params['wednsday_opens'], :wednsday_closes => params['wednsday_closes'],
      :thursday_opens => params['thursday_opens'], :thursday_closes => params['thursday_closes'],
      :friday_opens => params['friday_opens'], :friday_closes => params['friday_closes'],
      :saturday_opens => params['saturday_opens'], :saturday_closes => params['saturday_closes'],
      :sunday_opens => params['sunday_opens'], :sunday_closes => params['sunday_closes'],
      :monday_closed => params['monday_closed'], :tuesday_closed => params['tuesday_closed'],
      :wednsday_closed => params['wednsday_closed'], :thursday_closed => params['thursday_closed'],
      :friday_closed => params['friday_closed'], :saturday_closed => params['saturday_closed'],
      :sunday_closed => params['sunday_closed'], :minutes_before_closing => params['minutes_before_closing'])

    # Check if something has changed
    old_h = hours_old.attributes
    new_h = hours_new.attributes

    # remove the attributes whe're not comapring:
    ["id", "owner_hours_id", "owner_hours_type"].each do |e|
      old_h.delete(e)
      new_h.delete(e)
    end

    if old_h == new_h
      [200, {}, 'Ingen endringer!']
    else
      begin
        hours_new.save!
        dept = Department.find(params['department_id']).opening_hours = hours_new
        dept.save
        [200, {}, 'OK! Åpningstider lagret.']
      rescue ActiveRecord::RecordInvalid
        [400, {}, 'Feil i skjemaet: Du kan ikke stenge før du har åpnet!']
      end
    end
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
      when '/saveopeninghours'
        SaveOpeningHours.new.call(env)
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
        [200, {}, slim(:department, :locals => {:department => dept, :screen_res => ScreenResolution.all })]
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
