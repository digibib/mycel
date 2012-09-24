import("shared")

config['channel'] = EM::Channel.new
config['channels'] = Hash.new{ |h,k| h[k] = EM::Channel.new }