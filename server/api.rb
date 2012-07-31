require "grape"

class API < Grape::API
  prefix 'api'
  format :json

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
      if new_client.valid?
        {:client => new_client}
      else
        throw :error, :status => 400, :message => "missing parameters"
      end
    end

    desc "updates an existing client and returns the updated version"
    put "/:id" do
      client = Client.find(params[:id])
      updates = {}
      params.each do |k,v|
        updates[k] = v if client.has_attribute?(k) and client.attributes[k].to_s != v
      end
      if updates.size > 0
        client.update_attributes(updates)
        {:client => client}
      else
        throw :error, :status => 400, :message => "Ingen endringer!"
      end
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
      if new_user.valid?
        {:user => new_user}
      else
        throw :error, :status => 400, :message => "Missing or wrong parameters"
      end
    end

    desc "deletes a user"
    delete "/:id" do
      User.find(params[:id]).destroy
      {}
    end

    desc "updates a user"
    put "/:id" do
      user = User.find(params[:id])
      updates = {}
      params.each do |k,v|
        updates[k] = v if user.has_attribute?(k) and user.attributes[k].to_s != v
      end
      if updates.size > 0
        user.update_attributes(updates)
        {:user => user}
      else
        throw :error, :status => 400, :message => "Ingen endringer!"
      end
    end

  end
end
