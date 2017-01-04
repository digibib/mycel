#encoding: UTF-8
require "grape"

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
  is_new = form_data["id"].nil? || form_data["id"].empty?

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
        foo = 42
        bootparams = Settings::PXE_UNREGISTERED_CLIENT.clone
        bootparams[:message] %= {referenceID: foo}
        bootparams.to_json
      elsif client.shorttime
        Settings::PXE_SEARCHSTATION.to_json
      else
        Settings::PXE_WORKSTATION.to_json
      end
    end
  end


  resource :keep_alive do
    desc "receives live signal from clients"
    get "/" do
      if params[:mac].present?
        mac = params[:mac]
        client = Client.find_by_hwaddr(mac)
        client.touch(:ts) if client.present?
      end
    end

  end


  resource :requests do
    desc "returns all requests"
    get "/" do
      {:requests => Request.all}
    end

    desc "deletes an existing request and returns status"
    delete "/:id" do
      requires_superadmin
      delete("Request", params[:id])
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


  resource :clients do
    desc "returns all clients, or identifies a client given a MACadress, or registers new request by MAC address"
    get "/" do
      if params[:mac]
        mac = params[:mac]
        client = Client.find_by_hwaddr(mac)
        if client.nil?
          ip = env['REMOTE_ADDR']
          request = Request.find_by_hwaddr(mac)
          if request.nil?
            request = Request.create(:hwaddr => mac, :ipaddr => ip)
            throw :error, :status => 400,
            :message => "Manglende og/eller ugyldige parametere" unless request.valid?
            request.save
            status 404
            # {"Klienten er ikke registrert i systemet. Kontakt admin med kode #{request.id}"}
          else
            request.touch(:ts)
            status 404
            # {"Klienten er ikke registrert i systemet. Kontakt admin med kode #{request.id}"}
          end

        else
          status 200
          {:client => client.as_json}
        end
      else
        clients = []
        Client.all.each do |client|
          branch_id = {"branch_id" => client.branch.id, "is_connected" => client.connected?}
          clients << client.attributes.merge(branch_id)
        end
        status 200
        {:clients => clients }
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
      client.attributes = client.attributes.merge(updates){|key, oldval, newval| key == "id" ? oldval : newval }

      # missing keys typically represent unchecked checkboxes. these are set to false.
      missing_keys = client.attributes.keys.select {|key| !form_data.key?(key) }
      missing_keys.each do |key|
        client.attributes = {key.to_sym => false}
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
        {:departments => Department.all}
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

        throw :error, :status => 400,
        :message => "Ingen endringer!" unless changes

        # persist the changes:
        dept.options.opening_hours.save if dept.options.opening_hours
        dept.options.save
        {:department => dept.as_json}
      end
    end

    resource :branches do
      desc "return all branches with attributes and options"
      get "/" do
        {:branches => Branch.all}
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

        throw :error, :status => 400,
        :message => "Ingen endringer!" unless changes

        # persist the changes:
        branch.options.opening_hours.save if branch.options.opening_hours
        branch.options.save
        {:branch => branch.as_json}
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
