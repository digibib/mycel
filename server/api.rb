require "grape"

class API < Grape::API
  prefix 'api'
  format :json

  resource 'organization' do
  end

  resource 'branches' do
  end

  resource 'departmentes' do
  end

  resource 'clients' do
    get "/" do
      {"clients" => "plenty"}
    end
  end

  resource 'users' do
  end

  namespace 'options' do
    resource 'opening_hours' do
    end
  end

end
