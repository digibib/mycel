require './models'
require 'logger'

ActiveRecord::Base.establish_connection(Settings::DB[:production])
logger = Logger.new('./logs/uptime.log')
logger.datetime_format = "%Y-%m-%d %H:%M"

Client.all.each do |client|
  logger.info "id: #{client.id} status: #{client.status(true)}"
end
