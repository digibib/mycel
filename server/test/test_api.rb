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
        @client1 = Client.create(:id => 1, :name => 'client1', :hwaddr => any_string, :ipaddr => any_string)
        @client2 = Client.create(:id => 2, :name => 'client2', :hwaddr => any_string, :ipaddr => any_string)
      end

      it "lists all the clients" do
        get "/api/clients"
        last_response.status.must_equal 200
        JSON.parse(last_response.body)["clients"].length.must_equal 2
        JSON.parse(last_response.body)["clients"].must_be_instance_of Array
        JSON.parse(last_response.body)["clients"][0]['name'].must_equal 'client1'
        JSON.parse(last_response.body)["clients"][1]['name'].must_equal 'client2'
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

    # describe 'POST /api/clients' do
    #   it "creates a new client" do
    #     post "/api/clients"
    #     last_response.status.must_equal 201
    #   end
    # end

  end
end
