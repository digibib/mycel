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
        updates[k] = v if (client.has_attribute?(k) and client.attributes[k].to_s != v)
      end
      if updates.size > 0
        client.update_attributes(updates)
        {:client => client}
      else
        throw :error, :status => 400, :message => "no changes to be made"
      end
    end

  end

end
