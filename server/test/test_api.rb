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
        @dept = Department.create :name => any_string
        @client1 = Client.create(:id => 1, :name => 'client1',
                                 :hwaddr => any_string, :ipaddr => any_string)
        @client2 = Client.create(:id => 2, :name => 'client2',
                                 :hwaddr => "identifyme!", :ipaddr => any_string)
        @dept.clients << @client1
        @dept.clients << @client2
      end

      after do
        @dept.destroy
        @client1.destroy
        @client2.destroy
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
        get "/api/clients/3"
        last_response.status.must_equal 404
      end

      it "identifies client given a corresponding mac adress " do
        get "api/clients/", :mac => "identifyme!"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['client']['id'].must_equal 2
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
        post "/api/users", :username => any_string, :password => any_string,
                          :minutes => any_int, :age => any_int
        last_response.status.must_equal 201
        User.all.count.must_equal num_of_users + 1
        # delete created user so it doesnt interfere with other specs
        new_user = JSON.parse(last_response.body)['user']['id']
        User.find(new_user).destroy
      end
    end

    # describe 'POST /api/users/authenticate' do
    #   before do
    #     @user = GuestUser.create(:username => "rob", :password => "roy",
    #                      :minutes => any_int, :age => any_int)
    #     #NB THIS USER IS TEMPORARY AND LOCAL TO DEICHMANSKE BIBLIOTEK:
    #     #In order to test SIP2-authentication, a local library user with a valid nr and pin must exist
    #     @libuser = LibraryUser.create(:username => "N001965750", :minutes => any_int)
    #   end

    #   after do
    #     @user.destroy
    #     @libuser.destroy
    #   end

    #   it "authenticates a guest user given the correct password" do
    #     post "/api/users/authenticate", :username => "rob", :password => "roy"
    #     last_response.status.must_equal 200
    #     JSON.parse(last_response.body)['authenticated'].must_equal true
    #   end

    #   it "authenticates a libary user given the correct password(PIN)" do
    #     post "/api/users/authenticate", :username => "N001965750", :password => "9999"
    #     last_response.status.must_equal 200
    #     JSON.parse(last_response.body)['authenticated'].must_equal true
    #   end

    #   it "doesn't authenticate libary user given wrong password(PIN)" do
    #     post "/api/users/authenticate", :username => "N001965750", :password => "1234"
    #     last_response.status.must_equal 200
    #     JSON.parse(last_response.body)['authenticated'].must_equal false
    #   end

    #   it "doesn't authenticate guest user given wrong password" do
    #     post "/api/users/authenticate", :username => "rob", :password => "xxy"
    #     last_response.status.must_equal 200
    #     JSON.parse(last_response.body)['authenticated'].must_equal false
    #   end

    # end



    describe 'DELETE /api/users/:id' do

      before do
        @guest = GuestUser.create(:username => any_string, :password => any_string,
                         :minutes => any_int, :age => any_int)
      end

      after do
        @guest.destroy
      end

      it "deletes a given user" do
        num_of_users = User.all.count
        delete "/api/users/#{@guest.id}"
        last_response.status.must_equal 204
        User.all.count.must_equal num_of_users - 1
        assert @quest.nil?
      end
    end

    describe 'PUT /api/users/:id' do

      before do
        @user = GuestUser.create(:username => any_string, :password => any_string,
                         :minutes => 30, :age => any_int)
      end

      after do
        @user.destroy
      end

      it "updates a client with new values suplied by parameters" do
        @user.minutes.must_equal 30
        put "/api/users/#{@user.id}", :minutes => 45
        last_response.status.must_equal 200
        @user.reload
        @user.minutes.must_equal 45
      end

      it "returns the updated user" do
        name_before_update = @user.username
        put "/api/users/#{@user.id}", :username => "new_name"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['user']['username'].must_equal "new_name"
      end

      it "updates nothing if no attributes are changed" do
        put "/api/users/#{@user.id}", :username => @user.username
        last_response.status.must_equal 400
        last_response.body.must_equal "Ingen endringer!"
      end
    end

  end

  describe 'departments' do

    before do
      @org = Organization.create :name => any_string
      @org.options = Options.new
      @branch = Branch.create :name => any_string
      @dept = Department.create :name => any_string
      @hours = OpeningHours.new :monday_opens => '10:00', :monday_closes => '19:00',
                                  :tuesday_opens => '10:00', :tuesday_closes => '19:00',
                                  :wednsday_opens => '10:00', :wednsday_closes => '19:00',
                                  :thursday_opens => '10:00', :thursday_closes => '19:00',
                                  :friday_opens => '10:00', :friday_closes => '19:00',
                                  :saturday_closed => 1,
                                  :sunday_closed => 1
      @dept.options.opening_hours = @hours
      @dept.save
      @branch.departments << @dept
      @org.branches << @branch
      @hours2 = OpeningHours.new :monday_closed => 1, :tuesday_closed => 1,
        :wednsday_closed => 1, :thursday_closed => 1, :friday_closed => 1,
        :saturday_closed => 1, :sunday_closed => 1
      @org.options.opening_hours = @hours2
    end

    after do
      @org.destroy
      @branch.destroy
      @dept.destroy
      @hours.destroy
      @hours2.destroy
    end

    describe 'PUT /api/departments/:id' do
      it "updates opening hours if there are changes " do
        @hours.friday_opens.must_equal '10:00'
        put "/api/departments/#{@dept.id}", :opening_hours => {:friday_opens => '11:00'}
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['department']['options']['opening_hours']['friday_opens'].must_equal '11:00'
      end

      it "updates nothing if there are no changes" do
        put "/api/departments/#{@dept.id}",
          :opening_hours => {:monday_opens => '10:00', :saturday_closed => "1", :monday_closed => false}
        last_response.status.must_equal 400
        last_response.body.must_equal "Ingen endringer!"
      end

      it "updates printer adress and homepage" do
        put "/api/departments/#{@dept.id}",
            :printeraddr => "socket://101.101.101.11", :homepage => "deichman.no"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['department']['options']['printeraddr']
          .must_equal "socket://101.101.101.11"
        JSON.parse(last_response.body)['department']['options']['homepage']
          .must_equal "deichman.no"
      end

      it "inhertis from branch/org if attribute is set to 'inherit'" do
        put "/api/departments/#{@dept.id}", :opening_hours => "inherit"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)['department']['options_inherited']['opening_hours']
          .must_equal @hours2.as_json
      end

      it "creates a new opening-hours if the inehrited one is changed" do
        @dept.options.opening_hours = nil
        @dept.save
        get "/api/departments/#{@dept.id}"
        JSON.parse(last_response.body)['department']['options']['opening_hours']
          .must_equal nil
        put "/api/departments/#{@dept.id}", :opening_hours => {
                                  :monday_opens => '10:00', :monday_closes => '19:00',
                                  :tuesday_opens => '10:00', :tuesday_closes => '19:00',
                                  :wednsday_opens => '10:00', :wednsday_closes => '19:00',
                                  :thursday_opens => '10:00', :thursday_closes => '19:00',
                                  :friday_opens => '10:00', :friday_closes => '19:00',
                                  :saturday_closed => 1,
                                  :sunday_closed => 1}
        last_response.status.must_equal 200
      end

    end
  end
end
