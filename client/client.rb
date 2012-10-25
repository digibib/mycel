#encoding: UTF-8
require "json"
require "net/http"
require "em-ws-client"
require "yaml"
require "./login.rb"
require "./loggedin.rb"

CONFIG = YAML::load(File.open("client.yml"))
MAC = %x[cat '/sys/class/net/eth0/address'].strip

if not MAC
  puts "Fatal error: Could not retreive MAC-address of client."
  puts "This is needed for identifying the client."
  exit 0
end

uri = URI("http://#{CONFIG['api']['host']}:#{CONFIG['api']['port']}/api/clients/?mac="+MAC)
res = nil

until res
  begin
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(CONFIG['api']['username'], CONFIG['api']['password'])
    res = http.request(request)
  rescue Exception => e
    puts "Error connecting to Mycel server: "
    puts e
    for i in 1..5
      printf "retrying in %d seconds..\n", 6-i
      sleep 1
    end
  end
end

client = JSON.parse(res.body)['client']

# do local mods before login
# set screen resolution
# client['screen_resolution']
if client['screen_resolution'] != "auto"
  display = %x[/usr/bin/xrandr | /bin/grep -e " connected [^(]" | /usr/bin/awk '{print $1}']
  %x[/usr/bin/xrandr --output #{display} --mode #{client['screen_resolution']} ]
end

# set firefox homepage
#client['options_inherited']['homepage']
  escaped_homepage = client['options_inherited']['homepage'].gsub('/', '\/')
  %x[/bin/sed -i 's/user_pref("browser.startup.homepage",.*/user_pref("browser.startup.homepage","#{escaped_homepage}");/' $HOME/.mozilla/firefox/*.default/prefs.js]

# set local printer (using sudo without password, needs sudoers.d rule)
if client['options_inherited']['printeraddr']
  %x[/usr/bin/sudo -n /usr/sbin/lpadmin -p skranken -v #{client['options_inherited']['printeraddr']} ]
end


while true
  LogOn = LogOnWindow.new "LogOn", client['name']
  LogOn.show
  Gtk.main

  EM.run do
    ws = EM::WebSocketClient.new "ws://#{CONFIG['ws']['host']}:#{CONFIG['ws']['port']}/subscribe/clients/#{client['id']}"
    channel = EM::Channel.new
    LoggedIn = LoggedInWindow.new client['name'], LogOn.user
    LoggedIn.show

    ws.onopen do
      msg = {:action => "log-on", :client => client['id'], :user => LogOn.user}
      ws.send_message JSON.generate msg
    end

    ws.onmessage do |msg, binary|
      message = JSON.parse(msg)
      puts message
      case message["status"]
        when "logged-on"
          LoggedIn.set_name_label(message['user']['name'])
          LoggedIn.set_time(message["user"]["minutes"])
        when "ping"
            LoggedIn.set_time(message["user"]["minutes"]) if message["user"]["name"] == LoggedIn.name
        when "logged-off"
          EM.stop
      end
    end

    sid = channel.subscribe { |msg|
      msg = {:action => "log-off", :client => client['id'], :user => LogOn.user}
      ws.send_message JSON.generate msg
    }

    give_tick = proc {
      Gtk::main_iteration_do(blocking=false)
      sleep(0.01)
      EM.next_tick(give_tick)
      if LoggedIn.user.nil?
        channel.push("log-off")
        LoggedIn.user = "logging-off"
      end
      }
    give_tick.call

  end

  LoggedIn.destroy unless LoggedIn.destroyed?
  LogOn = nil
end
