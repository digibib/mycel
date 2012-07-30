#encoding: UTF-8
require "helpers/active_record"
require "minitest/autorun"
require "clean_test/any"
require "./models"
require "./api"
require "rack/test"

describe API do
  include Rack::Test::Methods
  include Clean::Test::Any

  def app
    API
  end

  describe 'clients' do

    describe 'GET /api/clients' do

      before do
        @client1 = Client.create(:id => 1, :name => 'client1',
                                 :hwaddr => any_string, :ipaddr => any_string)
        @client2 = Client.create(:id => 2, :name => 'client2',
                                 :hwaddr => any_string, :ipaddr => any_string)
      end

      it "lists all the clients" do
        get "/api/clients"
        last_response.status.must_equal 200
        response = JSON.parse(last_response.body)
        response["clients"].length.must_equal 2
        response["clients"].must_be_instance_of Array
        response["clients"][0]['name'].must_equal 'client1'
        response["clients"][1]['name'].must_equal 'client2'
      end

      it "can access individual clients" do
        get "/api/clients/2"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)["client"].wont_be_instance_of Array
        JSON.parse(last_response.body)['client']['name'].must_equal "client2"
      end

      it "cannot acces non-existing clients" do
        get "/api/client/3"
        last_response.status.must_equal 404
      end
    end

    describe 'POST /api/clients' do
      it "creates a new client" do
        num_of_clients_before_post = Client.all.count
        post "/api/clients", :name => any_string, :ipaddr => any_string,
                              :hwaddr => any_string
        last_response.status.must_equal 201
        Client.all.count.must_equal num_of_clients_before_post + 1
      end

      it "doesn't create a new client if required parameters are missing" do
        num_of_clients_before_post = Client.all.count
        post "/api/clients", :name => any_string
        last_response.status.must_equal 400
        Client.all.count.must_equal num_of_clients_before_post
      end

      it "returns the created client" do
        post "/api/clients", :name => 'nju_client', :ipaddr => any_string,
                             :hwaddr => any_string
        last_response.status.must_equal 201
        JSON.parse(last_response.body)['client']['name'].must_equal "nju_client"
      end
    end

    describe 'PUT /api/clients/:id' do

      before do
        @client_updatable = Client.create(:name => any_string,
                                          :ipaddr => 'ip.1', :hwaddr => any_string)
      end

      after do
        @client_updatable.destroy
      end

      it "updates a client with new values suplied by parameters" do
        @client_updatable.ipaddr.must_equal 'ip.1'
        put "/api/clients/#{@client_updatable.id}", :ipaddr => 'ip.2'
        last_response.status.must_equal 200
        @client_updatable.reload
        @client_updatable.ipaddr.must_equal 'ip.2'
      end

      it "returns the updated client" do
        name_before_update = @client_updatable.name
        put "/api/clients/#{@client_updatable.id}", :name => "new_name"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['client']['name'].must_equal "new_name"
      end

      it "updates nothing if no attributes are changed" do
        put "/api/clients/#{@client_updatable.id}", :name => @client_updatable.name
        last_response.status.must_equal 400
        last_response.body.must_equal "Ingen endringer!"
      end
    end

  end

  describe 'users' do

    describe 'GET /api/users' do

      before do
        @guest = GuestUser.create(:username => any_string, :password => any_string,
                         :minutes => any_int, :age => any_int)
        @named_guest = GuestUser.create(:username => "Franz", :password => any_string,
                         :minutes => any_int, :age => any_int)
      end

      after do
        @guest.destroy
        @named_guest.destroy
      end

      it "fetches all the users" do
        num_of_users = User.all.count
        get "/api/users"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['users'].count.must_equal num_of_users
      end

      it "returns specific user" do
        user = User.find_by_username('Franz')
        get "/api/users/#{user.id}"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['user']['username'].must_equal "Franz"
      end
    end

    describe 'POST /api/users' do
      it "creates a new user" do
        num_of_users = User.all.count
        post "api/users", :username => any_string, :password => any_string,
                          :minutes => any_int, :age => any_int
        last_response.status.must_equal 201
        User.all.count.must_equal num_of_users + 1
        # delete created user so it doesnt interfere with other specs
        new_user = JSON.parse(last_response.body)['user']['id']
        User.find(new_user).destroy
      end

    end

  end
end
