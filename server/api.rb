#encoding: UTF-8
require "grape"
require "set"

# TODO put utility functions into module for mixin when API is finalized

# utility function to check if there are changes in a suplied hash of attributes
def changes?(hash_pre, hash_post)
  hash_pre.merge(hash_post) != hash_pre
end

# utility function to return attributes that are updates on model, and discard
# the attributes with no changes, returns false if no updates
def find_updates(model, attributes)
  updates = {}
  attributes.each do |k,v|
    updates[k] = v if model.has_attribute?(k) and model.attributes[k].to_s != v
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
    desc "returns all clients"
    get "/" do
      {:clients => Client.all }
    end

    desc "returns individual client"
    get "/:id" do
     {:client => Client.find(params[:id])}
    end

    desc "creates a new client and returns it"
    post "/" do
      new_client = Client.create(:name => params['name'], :hwaddr => params['hwaddr'],
                   :ipaddr => params['ipaddr'])

      throw :error, :status => 400,
            :message => "missing parameters" unless new_client.valid?

      {:client => new_client}
    end

    desc "updates an existing client and returns the updated version"
    put "/:id" do
      client = Client.find(params[:id])
      updates = find_updates client, params

      throw :error, :status => 400, :message => "Ingen endringer!" unless updates

      client.update_attributes(updates)
      {:client => client}
    end

  end

  resource :users do
    desc "returns all users"
    get "/" do
      {:users => User.all}
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
            :message => "Missing or wrong parameters" unless new_user.valid?

      {:user => new_user}
    end

    desc "deletes a user"
    delete "/:id" do
      User.find(params[:id]).destroy
      {}
    end

    desc "updates a user"
    put "/:id" do
      user = User.find(params[:id])
      updates = find_updates user, params

      throw :error, :status => 400, :message => "Ingen endringer!" unless updates

      user.update_attributes(updates)
      {:user => user}
    end
  end

  resource :departments do
    desc "return all departments with attributes and options"
    get "/" do
      {:departments => Department.all}
    end

    desc "get specific department"
    get "/:id" do
      {:department => Department.find(params[:id])}
    end

    desc "update department options"
    put "/:id" do
      dept = Department.find(params[:id])
      changes = nil

      updates = find_updates dept, params.except(:options)
      if updates
        dept.update_attributes(updates)
        changes = true
      end

      options_updates = find_updates dept.options, params[:options].except(:opening_hours)
      if options_updates
        dept.options.update_attributes(options_updates)
        changes = true
        params[:options].delete :opening_hours if params[:options][:opening_hours] == "inherit"
      end

      # TODO refactor this:
      # if params[:options][:opening_hours] and changes? dept.options_self_or_inherited.opening_hours.attributes_formatted, prepare_params(params[:options][:opening_hours])
      #   if dept.options.opening_hours
      #     dept.options.opening_hours.update_attributes(params[:options][:opening_hours])
      #     throw :error, :status => 400,
      #       :message => "Du kan ikke stenge før du har åpnet!" if dept.options.opening_hours.errors.size > 0
      #     changes = true
      #   else
      #     hours = OpeningHours.create params[:options][:opening_hours]
      #     throw :error, :status => 400,
      #       :message => "Du kan ikke stenge før du har åpnet!" unless hours.valid?
      #     dept.options.opening_hours = hours
      #     changes = true
      #   end
      # end

      throw :error, :status => 400,
            :message => "Ingen endringer!" unless changes

      {:department => dept}
    end
  end

  resource :branches do
    desc "return all branchess with attributes and options"
    get "/" do
      {:branches => Branch.all}
    end

    desc "get specific branch"
    get "/:id" do
      {:branch => Branch.find(params[:id])}
    end

    desc "update branch options"
    put "/:id" do
      branch = Branch.find(params[:id])
      changes = nil

      updates = find_updates branch, params
      if updates
        branch.update_attributes(updates)
        changes = true
        params.delete :opening_hours if params[:opening_hours] == "inherit"
      end

      # TODO refactor this:
      if params[:opening_hours] and changes? branch.opening_hours_inherited.attributes_formatted, prepare_params(params[:opening_hours])
        if branch.opening_hours
          branch.opening_hours.update_attributes(params[:opening_hours])
          throw :error, :status => 400,
            :message => "Du kan ikke stenge før du har åpnet!" if branch.opening_hours.errors.size > 0
          changes = true
        else
          hours = OpeningHours.create params[:opening_hours]
          throw :error, :status => 400,
            :message => "Du kan ikke stenge før du har åpnet!" unless hours.valid?
          branch.opening_hours = hours
          changes = true
        end
      end

      throw :error, :status => 400,
            :message => "Ingen endringer!" unless changes

      {:branch => branch}
    end
  end

end

