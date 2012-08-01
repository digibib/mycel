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

class SaveOpeningHours < Goliath::API
    # TODO updatattributes instead of new object if it exists!
  def response(env)
    puts params.to_s

    # delete opening hours and inherit if all fields are blank
    if params['missing_fields'] == "14"
      puts "all clear!!"
      Department.find(params['department_id']).opening_hours = nil
      return [200, {}, 'Arver instillinger..']
    end

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
        dept = Department.find(params['department_id'])
        dept.opening_hours = hours_new
        dept.save
        [200, {'new_hours_id'=>dept.hours.id.to_s}, 'OK! Åpningstider lagret.']
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
    path = CGI.unescape(env['PATH_INFO']).split('/')

    case path.length
    when 0    # matches /
      [200, {}, slim(:index)]
    when 2    # matches /branch
      if @@org.branches.find_by_name(path[1])
        [200, {:branch => path[1]}, "filial"]
              # or matches /ws for websocket communication:
      elsif path[1] == 'ws'
        super(env)
      elsif path[1] == 'users'
        [200, {}, slim(:users, :locals => {:users => User.all})]
      elsif path[1] == 'branches'
        [200, {}, slim(:branches)]
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
        API.call(env)
      else    # matches non-existing branch and/or department
        raise Goliath::Validation::NotFoundError
      end
    when 4
      if path[1] == 'api' # Dispatch api-calls to grape
        API.call(env)
      else
        raise Goliath::Validation::NotFoundError
      end
    else      # matches everything else
      raise Goliath::Validation::NotFoundError
    end
  end
end
