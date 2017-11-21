#encoding: UTF-8
require "grape"
require 'resolv'

require_relative 'config/pxe_settings.rb'

# TODO put utility functions into module for mixin when API is finalized

# utility function to check if there are changes in a suplied hash
def changes?(hash_pre, hash_post)
  hash_pre.merge(hash_post) != hash_pre
end

# utility function to return attributes that are updates on model, and discard
# the attributes with no changes, returns false if no updates
# if attribute is set to "inherit", the attribute is set to nil
def find_updates(model, attributes)
  updates = {}
  attributes.each do |k,v|
    updates[k] = v if model.has_key? k and model[k].to_s != v
    updates[k] = nil if v == "inherit"
    updates[k] = nil if v == ""
  end
  return false if updates.empty?
  updates
end

# utility function, converts 1 to true and 0 to false
# needed for proper checking of something has been changed
def prepare_params (params)
  ret = {}
  params.each do |k,v|
    case v
    when "", "null"
      ret[k.to_s] = nil
    when 0, "false", "0"
      ret[k.to_s] = false
    when 1, "true", "1"
      ret[k.to_s] = true
    else
      ret[k.to_s] = v
    end
  end
  ret
end


def requires_superadmin
  admin = Admin.find_by_username(env['admin'])
  if !(admin && admin.superadmin?)
    redirect '/'
  end
end

def create_logstring(item)
  if item.defined?('name')
    name = item.name
  elsif item.defined?('username')
    name = item.username
  else
    name = "Ukjent navn"
  end


  "#{item.classs.name}: navn: #{name} id: #{item.id}"
end

def delete(class_name, id)
  klazz = class_name.constantize

  item = klazz.find(id)
  if item.destroy
    status 200
    {message: "OK. Slettet."}
  else
    throw :error, :status => 400,
    :message => item.errors.empty? ? "Ukjent feil" : item.errors.full_messages.to_sentence
  end
end


def create(class_name, params)
  klazz = class_name.constantize

  form_data = params[:form_data].to_hash
  is_new = form_data["id"].nil? || form_data["id"].empty? || form_data["id"] == '0'

  item = is_new ? klazz.new : klazz.find(form_data["id"])

  # select only the keys from params present in attributes
  updates = form_data.select {|key| item.attributes.keys.include?(key) }
  item.attributes = item.attributes.merge(updates){|key, oldval, newval| key == "id" ? oldval : newval }

  if item.save
    status 200
    {message: "OK. Lagret.", id: item.id}
  else
    message = item.errors.empty? ? "Ukjent feil" : item.errors.full_messages.to_sentence
    throw :error, :status => 400,
    :message => message
  end

end


class API < Grape::API
  prefix 'api'
  format :json
  default_format :json

  # stub implementation of pixiecore support for possible future use. unfinished.
  resource :pxe do
    desc "Verifies mac address and returns boot parameters for client machines"
    get "/v1/boot/:mac" do

      mac = params['mac']
      client = Client.find_by_hwaddr(mac)

      if client.nil?
        mock_id = 42
        bootparams = PXESettings::PXE_UNREGISTERED_CLIENT.clone
        bootparams[:message] %= {referenceID: mock_id}
        bootparams.to_json
      elsif client.shorttime
        PXESettings::PXE_SEARCHSTATION.to_json
      else
        PXESettings::PXE_WORKSTATION.to_json
      end
    end
  end


  resource :keep_alive do
    desc "receives live signal from clients"
    get "/" do
      if params[:mac].present?
        mac = params[:mac]
        client = Client.find_by_hwaddr(mac)
        if client.present?
          if not client.connected?
            client.generate_offline_event
            client.update_attributes(online_since: Time.now)
          end

          client.touch(:ts)
        end
      end
      status 200
      [200, {'Connection' => "close"}, {message: "OK"}]
    end
  end


  resource :requests do
    desc "returns all requests"
    get "/" do
      {:requests => Request.all}
    end

    desc "deletes a specific request and returns status"
    delete "/:id" do
      requires_superadmin
      delete("Request", params[:id])
    end
  end

  resource :profiles do
    desc "returns all profiles"
    get "/" do
      {:profiles => Profile.all}
    end

    desc "returns a specific profile"
    get "/:id" do
      {:profile => Profile.find(params[:id]).as_json}
    end

    desc "creates or updates profile and returns status"
    post "/" do
      requires_superadmin
      create("Profile", params)
    end

    desc "deletes an existing profile and returns status"
    delete "/:id" do
      requires_superadmin
      delete("Profile", params[:id])
    end

  end


  resource :printer_profiles do
    desc "returns all printer profiles"
    get "/" do
      {:printer_profiles => PrinterProfile.all}
    end

    desc "returns a specific printer profile"
    get "/:id" do
      {:printer_profile => PrinterProfile.find(params[:id]).as_json}
    end

    desc "creates or updates printer profile and returns status"
    post "/" do
      requires_superadmin
      create("PrinterProfile", params)
    end

    desc "deletes an existing printer profile and returns status"
    delete "/:id" do
      requires_superadmin
      delete("PrinterProfile", params[:id])
    end

  end

  resource :printers do
    desc "returns all printers"
    get "/" do
      printers = []
      Printer.api_includes.all.each do |printer|
        printers << printer.attributes.merge({has_subscribers: printer.has_subscribers })
      end

      {:printers => printers}
    end

    desc "returns a specific printer"
    get "/:id" do
      {:printer => Printer.find(params[:id]).as_json}
    end

    desc "creates or updates printer and returns status"
    post "/" do
      requires_superadmin
      create("Printer", params)
    end

    desc "deletes an existing printer and returns status"
    delete "/:id" do
      requires_superadmin
      delete("Printer", params[:id])
    end

  end


  resource :admins do
    desc "returns all admins"
    get "/" do
      requires_superadmin
      {:admins => Admin.all}
    end

    desc "creates or updates administrator account and returns status"
    post "/" do
      requires_superadmin
      create("Admin", params)
    end

    desc "deletes an existing administrator and returns status"
    delete "/:id" do
      requires_superadmin
      delete("Admin", params[:id])
    end


    desc "authenticates admin"
    post "/login" do
      admin = Admin.where(:username=>params[:username]).first
      throw :error, :status => 401,
      :message => "Feil brukernavn eller passord" unless admin and admin.password == params[:password]
      status 200
      {:login => true}
    end
  end


  resource :client_specs do
    desc "updates hardware info for client"
    post "/" do
      mac = params[:mac]
      begin
        client = Client.find_by_hwaddr(mac)
      rescue ActiveRecord::RecordNotFound
        throw :error, :status => 404,
        :message => "Det finnes ingen klient med mac #{params[:mac]}"
      end


      spec = ClientSpec.find_by_client_id(client.id) || ClientSpec.new(client_id: client.id)

      updates = params.select {|key| spec.attributes.keys.include?(key) }
      # updates.each{ |_,v| v.slice!("\n") } # remove newline chars from string, push later when at office TODO
      spec.attributes = spec.attributes.merge(updates)

      spec.save if spec.changed?
    end

    desc "returns all client_specs"
    get "/" do
      clients = []
      Client.inventory_view.all.each do |client|
        # build title attribute string containing latest offline events
        events = ""
        client.connection_events.order("started DESC").each do |event|
          events = events + event.to_title
        end

        downtimes = ClientEvent.create_downtime_series(client.id)

        # merge attributes and return
        h = {status: client.status, branch_id: client.branch.id, branch_name: client.branch.name,
           specs: client.client_spec, title: events, downtimes: downtimes}
        clients << client.attributes.merge(h)
      end

      status 200
      {data: clients }
    end


    # TODO experimental and currently not in use. doesnt particularly belong under
    # this resource. can be removed.
    desc "returns a timeline chart series for the client"
    get "/chart/timeline/:client_id" do
      clients = Client.where(id: params[:client_id])
      series = []
      clients.each do |client|
        data = []

        client.connection_events.each do |event|
          data << [(event.started.to_time.to_r * 1000).round, 0]
          data << [(event.started.to_time.to_r * 1000).round, 1]
          data << [(event.ended.to_time.to_r * 1000).round, 1]
          data << [(event.ended.to_time.to_r * 1000).round, 0]
        end

        series << {name: client.name, data: data }
      end

      {series: series}.to_json
    end


    # TODO move to client?
    desc "returns a uptime series for the client"
    get "/chart/uptime/:client_id" do
      no_of_days = 12
      duration = 12.days.to_i / 60

      origin = Time.now - no_of_days.days
      period_start = origin.strftime('%Y-%m-%d %H:%M:%S')

      client = Client.find(params[:client_id])

      events =
        ClientEvent.where(client_id: params[:client_id])
        .where("ended >= '#{period_start}'")
        .order('started asc')

      if events.size == 0
        starting_status = client.connected?
      else
        starting_status = events.first.started <= period_start
      end

      data = []
      events.each do |event|
        data << {start: event.started, end: event.ended}
      end

      unless client.connected?
        # add extra event, start = client.ts, end: now
        # ending_status: client.connected?
      end

      {starting_status: starting_status, period_start: period_start, origin: origin, duration: duration, data: data}.to_json
    end



    desc "returns a pie chart series for the client_specs"
    get "/chart/pie/:type" do
      case params[:type]
      when "cpu"
        resource = 'cpu_family'
        title = 'Prosessor'
      when "ram"
        resource = 'ram'
        title = 'Minne'
      end

      names = ClientSpec.pluck(resource.to_sym)
      names = names.map {|name| name.to_s.split("\n")} # TODO work towards removing this

      freq = Hash.new(0)
      names.each {|name| freq[name] += 1 }
      data = freq.map {|key, value| {name: key, y: (value)}}

      status 200
      {series: [{name: title, colorByPoint: true, data: data}]}.to_json
    end


    desc "returns a bar chart series for the client_specs"
    get "/chart/bar/:type" do
      status_map = {unseen: {label: 'Usett', color: 'black'}, disconnected: {label: 'Frakoblet', color: 'red'},
       available: {label: 'Ledig', color: 'blue'}, occupied: {label: 'Opptatt', color: 'green'}}

      # Tally status for all clients and order by branch
      counts_by_branch = {}
      Client.inventory_view.all.each do |client|
        branch_name = client.department.branch.name
        counts_by_branch[branch_name] ||= status_map.keys.each_with_object({}) {|key, hsh| hsh[key] = 0}
        counts_by_branch[branch_name][client.status.to_sym] += 1
      end

      # Flatten to a single level hash to in order to create the series data
      counts_by_status = {}
      status_map.keys.each do |status|
        counts_by_status[status] = counts_by_branch.sort.map {|_, counts| counts[status]}
      end

      # Final transformation and return
      series = counts_by_status.map {|key, data| {name: status_map[key][:label], data: data, color: status_map[key][:color]}}
      categories = counts_by_branch.sort.map {|branch_name, _| branch_name}

      status 200
      {series: series, categories: categories}
    end
  end

  resource :clients do
    desc "returns all clients, or identifies a client given a MACadress, or registers new request by MAC address"
    get "/" do
      if params[:mac]
        mac = params[:mac]
        client = Client.find_by_hwaddr(mac)
        if client.nil?
          ip = env['REMOTE_ADDR']

          begin
            dns = Resolv.getname(ip)
          rescue
            dns = 'Not resolved'
          end

          request = Request.find_by_hwaddr(mac)
          if request.nil?
            request = Request.create(:hwaddr => mac, :ipaddr => ip, :hostname => dns)
            throw :error, :status => 400,
            :message => "Manglende og/eller ugyldige parametere" unless request.valid?
            request.save
            status 404
            {:message => "Klienten er ikke registrert i systemet. Kontakt admin med kode #{request.id}"}
          else
            request.touch(:ts)
            status 404
            {:message => "Klienten er ikke registrert i systemet. Kontakt admin med kode #{request.id}"}
          end

        else
          status 200
          {:client => client.as_json}
        end
      else
        clients = []
        Client.includes(department: :branch).all.each do |client|
          attribs =
          { branch_id: client.department.branch_id,
            is_connected: client.connected?,
            status: client.status,
            offline_events: ClientEvent.create_downtime_series(client.id),
            user: client.user
          }

          clients << client.attributes.merge(attribs)
        end
        status 200
        {clients: clients }
      end
    end


    desc "returns individual client"
    get "/:id" do
      begin
        {:client => Client.find(params[:id]).as_json}
      rescue ActiveRecord::RecordNotFound
        throw :error, :status => 404,
        :message => "Det finnes ingen klient med id #{params[:id]}"
      end
    end

    desc "creates or updates client and returns operation status"
    post "/" do
      requires_superadmin

      form_data = params[:form_data].to_hash
      client = form_data["id"].present? ? Client.find(form_data["id"]) : Client.new

      # select only the keys from params present in client.attributes
      updates = form_data.select {|key| client.attributes.keys.include?(key) }
      client.attributes = client.attributes.merge(updates){|key, oldval, newval| (key == "id" || key == "ts") ? oldval : newval }

      # missing keys typically represent unchecked checkboxes. these are set to false.
      missing_keys = client.attributes.keys.select {|key| !form_data.key?(key) }
      missing_keys.each do |key|
        client.attributes = {key.to_sym => false} unless key == "ts" # except timestamp
      end

      if client.save
        Request.find(form_data["request_id"]).destroy if form_data["request_id"].present?
        status 200
        {message: "OK. Lagret."}
      else
        message = client.errors.empty? ? "Ukjent feil" : client.errors.full_messages.to_sentence
        throw :error, :status => 400,
        :message => message
      end
    end

    desc "updates an existing client and returns the updated version"
    put "/:id" do
      client = Client.find(params[:id])
      changes = false

      # select only the keys from params present in client.attributes
      updates = params.select { |k| client.attributes.keys.include?(k) }
      client.attributes = client.attributes.merge(updates)

      if params[:screen_resolution_id]
        changes = true if client.screen_resolution.id != params[:screen_resolution_id]
        client.screen_resolution = ScreenResolution.find(params[:screen_resolution_id])
      end

      throw :error, :status => 400,
      :message => "Ingen endringer!" unless client.changed? || changes

      client.save
      {:client => client}
    end

    desc "deletes an existing client and returns status"
    delete "/:id" do
      requires_superadmin
      delete("Client", params[:id])
    end
  end

  resource :users do
    desc "returns all users"
    get "/" do
      {:users => User.all.as_json}
    end

    get '/search/by_username/:query_string' do
      results = LibraryUser.inactive.where("name LIKE ?", "%#{params[:query_string]}%").pluck(:name)
      results << GuestUser.inactive.where("username LIKE ?", "%#{params[:query_string]}%").pluck(:username)
      results.flatten.to_json
    end

    get '/search/closest_match' do
      query = params[:query]

      user = LibraryUser.find_by_username(query) || GuestUser.find_by_name(query)
      user = LibraryUser.inactive.where("name LIKE ?", "%#{query}%").first unless user
      user = GuestUser.inactive.where("username LIKE ?", "%#{query}%").first unless user

      user.to_json
    end

    desc "authenticates a user"
    post "/authenticate" do
      throw :error, :status => 400,
      :message => "Manglende parametere" unless params["username"] and params["password"]

      message = "Feil lånenummer/brukernavn eller PIN/passord"
      authenticated = false

      # 1. check if user is a guest user in db
      user = User.find_by_username params["username"]
      # 2. find or create libraryuser if not a guest user
      user = LibraryUser.find_or_create_by_username params["username"] unless user
      authenticated = true if user and user.authenticate params["password"]

      # 3. Not OK if user allready logged on another client
      authenticated = false if user.client

      status 401
      status 200 if authenticated
      {:authenticated => authenticated, :minutes => user.minutes || 0,
        :age => user.age || 0, :message => message, :type => user.type_short || "N"}
      end

      desc "returns a specific user"
      get "/:id" do
        {:user => User.find(params[:id]).as_json}
      end

      desc "creates a new guest user"
      post "/" do
        new_user = GuestUser.create(:username => params["username"],
        :password => params["password"], :minutes => params["minutes"],
        :age => params["age"])

        throw :error, :status => 400,
        :message => "Manglende og/eller ugyldige parametere" unless new_user.valid?

        {:user => new_user}
      end

      desc "deletes a user"
      delete "/:id" do
        begin
          User.find(params[:id]).destroy
          {:user => "deleted"}
        rescue ActiveRecord::RecordNotFound
          throw :error, :status => 404,
          :message => "Det finnes ingen bruker med id #{params[:id]}"
        end
        status 204
      end

      desc "updates a user"
      put "/:id" do
        begin
          user = User.find(params[:id])

          # select only the keys from params present in user.attributes
          updates = params.select { |k| user.attributes.keys.include?(k) }
          user.attributes = user.attributes.merge(updates)

          throw :error, :status => 400,
          :message => "Ingen endringer!" unless user.changed?

          user.save
          {:user => user.as_json}
        rescue ActiveRecord::RecordNotFound
          throw :error, :status => 404,
          :message => "Det finnes ingen bruker med id #{params[:id]}"
        end
      end
    end

    resource :departments do
      desc "return all departments with attributes and options"
      get "/" do
        {:departments => Department.api_includes.all.as_json}
      end

      desc "get specific department"
      get "/:id" do
        {:department => Department.find(params[:id]).as_json}
      end

      desc "create or update department (without options) and returns status"
      post '/' do
        requires_superadmin
        create("Department", params)
      end

      desc "delete department (without options) and returns status"
      delete '/:id' do
        requires_superadmin
        delete("Department", params[:id])
      end



      desc "update department options"
      put "/:id" do
        dept = Department.find(params[:id])
        changes = false

        updates = find_updates dept.options_self_or_inherited, params.except(:opening_hours)
        if updates
          dept.options.attributes = updates
          changes = true if dept.options.changed?
        end

        if params[:opening_hours] == "inherit"
          changes = true unless dept.options.opening_hours.nil?
          dept.options.opening_hours = nil
          params.delete :opening_hours
        end

        if params[:opening_hours]
          # update current opening hours
          if dept.options.opening_hours
            dept.options.opening_hours.attributes = params[:opening_hours]
            changes = true if dept.options.opening_hours.changed?
          else # create new opening hours
            dept.options.opening_hours = OpeningHours.create params[:opening_hours]
            changes = true
          end
          throw :error, :status => 400,
          :message => "Du kan ikke stenge før du har åpnet!" unless dept.options.opening_hours.valid?
        end

        # At the risk of collapsing the universe: trying to save unchanged object
        # will no longer result in a thrown error...
        #throw :error, :status => 400,
        #:message => "Ingen endringer!" unless changes

        # persist the changes:
        dept.options.opening_hours.save if dept.options.opening_hours
        dept.options.save
        {:department => dept.as_json, :message => "OK. Lagret."}
      end
    end


    resource :branches do
      desc "return all branches with attributes and options"
      get "/" do
        {:branches => Branch.api_includes.all.as_json}
      end

      desc "get specific branch"
      get "/:id" do
        {:branch => Branch.find(params[:id]).as_json}
      end

      desc "create or update branch (without options) and returns status"
      post '/' do
        requires_superadmin
        create("Branch", params)
      end

      desc "delete branch (without options) and returns status"
      delete '/:id' do
        requires_superadmin
        delete("Branch", params[:id])
      end

      desc "update branch options"
      put "/:id" do
        branch = Branch.find(params[:id])
        changes = false

        updates = find_updates branch.options_self_or_inherited, params.except(:opening_hours)
        if updates
          branch.options.attributes = updates
          changes = true if branch.options.changed?
        end

        if params[:opening_hours] == "inherit"
          changes = true unless branch.options.opening_hours.nil?
          branch.options.opening_hours = nil
          params.delete :opening_hours
        end

        if params[:opening_hours]
          # update current opening hours
          if branch.options.opening_hours
            branch.options.opening_hours.attributes = params[:opening_hours]
            changes = true if branch.options.opening_hours.changed?
          else # create new opening hours
            branch.options.opening_hours = OpeningHours.create params[:opening_hours]
            changes = true
          end
          throw :error, :status => 400,
          :message => "Du kan ikke stenge før du har åpnet!" unless branch.options.opening_hours.valid?
        end

        #throw :error, :status => 400,
        #:message => "Ingen endringer!" unless changes

        # persist the changes:
        branch.options.opening_hours.save if branch.options.opening_hours
        branch.options.save
        {:branch => branch.as_json, :message => "OK. Lagret."}
      end
    end

    resource :organization do
      desc "return the organization with attributes and options"
      get "/" do
        {:organization => Organization.first.as_json}
      end

      desc "update the organization options"
      put "/:id" do
        org = Organization.first
        changes = false

        updates = find_updates org.options_self_or_inherited, params.except(:opening_hours)
        if updates
          org.options.attributes = updates
          changes = true if org.options.changed?
        end

        if params[:opening_hours] == "inherit"
          changes = true unless org.options.opening_hours.nil?
          org.options.opening_hours = nil
          params.delete :opening_hours
        end

        if params[:opening_hours]
          # update current opening hours
          if org.options.opening_hours
            org.options.opening_hours.attributes = params[:opening_hours]
            changes = true if org.options.opening_hours.changed?
          else # create new opening hours
            org.options.opening_hours = OpeningHours.create params[:opening_hours]
            changes = true
          end
          throw :error, :status => 400,
          :message => "Du kan ikke stenge før du har åpnet!" unless org.options.opening_hours.valid?
        end

        throw :error, :status => 400,
        :message => "Ingen endringer!" unless changes

        # persist the changes:
        org.options.opening_hours.save if org.options.opening_hours
        org.options.save
        {:organization => org.as_json}
      end
    end
  end
