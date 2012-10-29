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

class API < Grape::API
  prefix 'api'
  format :json
  default_format :json

  resource :clients do
    desc "returns all clients, or identifies a client given a MACadress"
    get "/" do
      if params[:mac]
        # identifies the client of a given mac-adress
        client = Client.find_by_hwaddr(params['mac'])
        throw :error, :status => 404,
              :message => "Det finnes ingen klient med MAC-adresse " +
                          "#{params[:mac]}" unless client
        {:client => client.as_json}
      else
        {:clients => Client.all }
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

    desc "creates a new client and returns it"
    post "/" do
      new_client = Client.create(:name => params['name'],
                                 :hwaddr => params['hwaddr'],
                                 :ipaddr => params['ipaddr'])

      throw :error, :status => 400,
            :message => "Manglender og/eller ugyldige parametere" unless new_client.valid?

      {:client => new_client}
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

  end

  resource :users do
    desc "returns all users"
    get "/" do
      {:users => User.all}
    end

    desc "authenticates a user"
    post "/authenticate" do
      throw :error, :status => 400,
            :message => "Manglende parametere" unless params["username"] and params["password"]

      authenticated = false

      # 1. check if user is a guest user in db
      user = User.find_by_username params["username"]
      # 2. find or create libraryuser if not a guest user
      user = LibraryUser.find_or_create_by_username params["username"] unless user
      authenticated = true if user and user.authenticate params["password"]
      # Not OK if user allready logged on
      authenticated = false if user.client
      status 200
      {:authenticated => authenticated, :minutes => user.minutes || nil}
    end

    desc "returns a specific user"
    get "/:id" do
      {:user => User.find(params[:id])}
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
        {:user => user}
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
    desc "return all branchess with attributes and options"
    get "/" do
      {:branches => Branch.all}
    end

    desc "get specific branch"
    get "/:id" do
      {:branch => Branch.find(params[:id]).as_json}
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

end

