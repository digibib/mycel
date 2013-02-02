require "em-synchrony/activerecord"
require "./config/settings"

ActiveRecord::Base.establish_connection(Settings::DB[:test])

load "db/schema.rb"
