# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
set :output, "logs/cron.log"

#env :PATH, '~/.rvm/bin:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin'
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end

# clear users table at midnight
every 1.day, :at => '00:00' do
  rake "delete_users"
end

# Learn more: http://github.com/javan/whenever
