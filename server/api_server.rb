#encoding: UTF-8
require "goliath"
require 'goliath/rack/templates'
require "em-synchrony/activerecord"
require "mysql2"
require "slim"
require "cgi"
require "./models"
require "./api"
require "./config/settings"


ActiveRecord::Base.establish_connection(Settings::DB[Goliath.env.to_sym])
Slim::Engine.set_default_options :pretty => true

Goliath::Request.log_block = proc do |env, response, elapsed_time|
  params = env[Goliath::Request::RACK_INPUT].string+env[Goliath::Request::QUERY_STRING]
  params = '**hidden**' if env[Goliath::Request::REQUEST_PATH].match(/authenticate/)
  params = '**hidden**' if env[Goliath::Request::REQUEST_PATH].match(/admins/)

  # Logging format:
  # response.status | request.IP | request.method | request.path | response.length(bytes) | response.time(ms)
  env[Goliath::Request::RACK_LOGGER].info "%s %s %s %s%s %s %.2f" % [
      response.status,
      env['HTTP_X_FORWARDED_FOR'] || env["REMOTE_ADDR"] || "-",
      env[Goliath::Request::REQUEST_METHOD],
      env[Goliath::Request::REQUEST_PATH],
      params.empty? ? "" : "?"+params,
      response.headers['Content-Length'].nil? ? "0" : response.headers['Content-Length'],
      elapsed_time
    ]
end
class Server < Goliath::API
  include Goliath::Rack::Templates
  use Goliath::Rack::Params
  use(Rack::Static,
      :root => Goliath::Application.app_path('public'),
      :urls => ['/favicon.ico', '/css', '/js', '/img'])
  @@org = Organization.first

  def set_admin(env)
     # check if cookie present
     if env['HTTP_COOKIE']
       cookie = env['HTTP_COOKIE']
     else
       cookie = "mycellogin=none"
     end

     # find current admin from cookie
     if cookie.match(/mycellogin/)
       env['admin'] = cookie.scan(/mycellogin=(\w+)/).last[0]
     else
       env['admin'] = "none"
     end
   end


   def response(env)
     #TODO debug SQL queries & optimize
     #ActiveRecord::Base.logger = env.logger if Goliath.env.to_s == "development

     path = CGI.unescape(env['PATH_INFO']).split('/')
     set_admin(env)

    if path[1] == 'api'
      env['HTTP_CONNECTION'] = 'close' if path[2] == 'keep_alive'
      API.call(env)
    else
      if env['admin'] == "none"
        if path[1] == 'setadmin'
          [200, {'Set-Cookie' => ["mycellogin=#{env.params['admin']}"]}, slim(:index, :locals => {:screen_res => ScreenResolution.all,
            :admin => Admin.find_by_username(env.params['admin'])})]
        else
          [401, {'Set-Cookie' => ["mycellogin=none"]}, slim(:login)]
        end
      else
        case path.length
        when 0    # matches /
          [200, {}, slim(:index, :locals => {:screen_res => ScreenResolution.all,
            :admin => Admin.find_by_username(env['admin'])})]
        when 2    # matches {branches}|users|statistics
          if @@org.branches.find_by_name(path[1])
            branch = Branch.find_by_name(path[1])
            if branch.authorized?(Admin.find_by_username(env['admin']))
              [200, {}, slim(:branch, :locals => {:branch => branch})]
            else
              [401, {}, slim(:forbidden)]
            end
          elsif path[1] == 'statistics'
            [200, {}, slim(:statistics)]
          elsif path[1] == 'inventory'
            [200, {}, slim(:inventory, locals: {admin: Admin.find_by_username(env['admin']), branches: Branch.order(:name).all})]
          elsif path[1] == 'i' || path[1] == 'beta' || path[1] == 'filial' || path[1] == 'clients' || path[1] == 'users'
            adm = Admin.find_by_username(env['admin'])
            level = adm.owner_admins_type.safe_constantize.find(adm.owner_admins_id)

            bid = params['bid'].present? ? params['bid'].to_i : Organization.first.branches.first.id
            selected_id = level.is_a?(Organization) ? bid : nil

            [200, {}, slim(:branch_ui, locals: {admin: adm, level: level, selected_id: selected_id})]
          elsif path[1] == 'branch_stats'
            [200, {}, slim(:branch_stats, layout: false, locals: {branch: Branch.find(params['id'])})]
          elsif path[1] == 'client_stats'
            no_of_days = params['no_of_days'].present? && params['no_of_days'].to_i || 7
            [200, {}, slim(:client_stats, layout: false, locals: {client: Client.find(params['id']), no_of_days: no_of_days})]
          elsif path[1] == 'chart'
            [200, {}, slim(:chart, layout: false, locals: {branches: Branch.order(:name).all})]
          elsif path[1] == 'wstest'
            [200, {}, slim(:wstest)]
          elsif path[1] == 'admin'
            admin = Admin.find_by_username(env['admin'])
            if admin.respond_to?(:superadmin?) and admin.superadmin?
              [200, {}, slim(:admin, locals: {:screen_res => ScreenResolution.all})]
            else
              [401, {}, slim(:forbidden)]
            end
          elsif path[1] == 'loggout'
            [200, {'Set-Cookie' => ["mycellogin=none"]}, slim(:login)]
          else    # matches non-existing branch
            raise Goliath::Validation::NotFoundError
          end
        when 3    # matches {branches}/{departments}
          if @@org.branches.find_by_name(path[1])
            if (dept = @@org.branches.find_by_name(path[1]).departments.find_by_name(path[2]))
              if dept.authorized?(Admin.find_by_username(env['admin']))
                [200, {}, slim(:department, :locals => {:department => dept,
                  :screen_res => ScreenResolution.all})]
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
