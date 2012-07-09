require "mysql2"
require "yaml"

dbconfig = YAML::load(File.open("config/database.yml"))

environment :test do
  ActiveRecord::Base.establish_connection(dbconfig["test"])
end


