#encoding: UTF-8
require "helpers/active_record"
require "minitest/autorun"
require "clean_test/any"
require "./models"
require "./api"
require "rack/test"

describe API do
  include Rack::Test::Methods

  def app
    API
  end

  describe API do
    describe 'GET /api/clients' do
      it "lists all the clients" do
        get "/api/clients"
        last_response.status.must_equal 200
      end
    end

  end

end
