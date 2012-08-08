require "em-synchrony/activerecord"

dbconfig = YAML::load(File.open("config/database.yml"))
ActiveRecord::Base.establish_connection(dbconfig["test"])

load "db/schema.rb"
