#encoding: UTF-8
require "gtk2"
require "json"
require "net/http"
require "em-ws-client"
require "yaml"

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

if res.code == '404'
  puts res.message
  puts "exiting.."
  exit 0
else
  client = JSON.parse(res.body)['client']
end

class LogOnWindow < Gtk::Window
  attr_accessor :user, :pin, :clientname

  def initialize(title, clientname)
    super(title)
    @user, @pin = nil
    @clientname = clientname
    puts @clientname
    build_gui
    fullscreen
    self.keep_above = true
  end

  def show
    show_all
  end

  private

  def build_gui
    logo = Gtk::Image.new "logo.png"

    button = Gtk::Button.new "Logg in"
    frame_label = "Logg deg på [ " + @clientname + " ]"
    frame = Gtk::Frame.new frame_label
    frame.label_xalign = 0.5

    userlabel = Gtk::Label.new "Lånenummer/brukernavn"
    userlabel.set_alignment 1, 0.5
    pinlabel = Gtk::Label.new "PIN-kode/passord"
    pinlabel.set_alignment 1, 0.5
    table = Gtk::Table.new 3, 2, false
    table.row_spacings = 7
    table.column_spacings = 5

    vbox = Gtk::VBox.new false, 20
    @userentry = Gtk::Entry.new
    @userentry.max_length = 10
    @userentry.set_size_request 150, 23
    @pinentry = Gtk::Entry.new
    @pinentry.set_size_request 150, 23
    @pinentry.max_length = 10
    @pinentry.visibility = false # password-mode
    table.attach userlabel, 0, 1, 0, 1
    table.attach @userentry, 1, 2, 0, 1
    table.attach pinlabel, 0, 1, 1, 2
    table.attach @pinentry, 1, 2, 1, 2
    table.attach button, 1, 2, 2, 3

    error = Gtk::Label.new
    vbox.pack_start_defaults logo
    vbox.pack_start_defaults table
    vbox.pack_end_defaults error
    vbox.set_border_width 20

    frame.add vbox

    center_align = Gtk::Alignment.new 0.5, 0.5, 0,0
    center_align.add frame
    add center_align

    button.signal_connect "clicked" do
      @user = @userentry.text
      @pin = @pinentry.text

      if invalid?
        error.set_markup "<span foreground='red'>%s</span>" % invalid?
        error.show
      else
        destroy
        # TODO authenticate here!
        Gtk.main_quit
      end
    end

    signal_connect("key_press_event") do |widget, event|
      if event.keyval == Gdk::Keyval::GDK_Return
        @user = @userentry.text
        @pin = @pinentry.text

        if invalid?
           error.set_markup "<span foreground='red'>%s</span>" % invalid?
           error.show
        else
           destroy
           Gtk.main_quit
        end
      end
    end

    signal_connect("delete_event") do |widget, event|
      true # don't allow to close window
    end
  end

  def invalid?
    error = nil
    if @pin != "" and @user == ""
      error = "Skriv inn lånenummer/brukernavn"
      @userentry.grab_focus
    elsif @user != "" and @pin == ""
      error = "Skriv inn PIN-kode/passord"
      @pinentry.grab_focus
    elsif @pin == "" and @user == ""
      error = "Skriv inn lånenummer/brukernavn og PIN/passord"
      @userentry.grab_focus
    else
      uri = URI("http://#{CONFIG['api']['host']}:#{CONFIG['api']['port']}/api/users/authenticate")
      begin
        http = Net::HTTP.new(uri.host, uri.port)
        request = Net::HTTP::Post.new(uri.request_uri)
        request.set_form_data('username'=>@user, 'password'=>@pin)
        request.basic_auth(CONFIG['api']['username'], CONFIG['api']['password'])
        res = http.request(request)
        res = JSON.parse(res.body)
      rescue Exception => e
        puts e
      end
      error = "Feil lånenummer/brukernavn eller PIN/passord" unless res['authenticated']
    end
    #Gtk.main_quit
    error
  end

end

while true
  LogOn = LogOnWindow.new "LogOn", client['name']
  LogOn.show
  Gtk.main


  class LoggedInWindow < Gtk::Window
    attr_accessor :user
    def initialize(title, user)
      super(title)
      @user = user
      @warned = false
      self.resizable = false
      self.keep_above = true
      set_type_hint Gdk::Window::TypeHint::MENU
      set_size_request(180, 120)

      # position window in lower right corner, 50 px from screen edges
      set_gravity Gdk::Window::GRAVITY_SOUTH_WEST
      move (Gdk.screen_width - size[0] - 50), (Gdk.screen_height - size[1] - 50)

      @user_label = Gtk::Label.new @user
      minutes = 60
      @time_left = Gtk::Label.new
      @time_left.set_markup "<span size='xx-large'>%d min igjen</span>" % minutes

      button = Gtk::Button.new "Logg ut"

      box = Gtk::VBox.new false, 5
      box.set_border_width 5
      box.pack_start_defaults @user_label
      box.pack_start_defaults @time_left
      box.pack_start_defaults button
      add box

      button.signal_connect "clicked" do
        @user = nil
        destroy
      end

      signal_connect "delete_event" do
        # don't destroy window when x button is clicked
        true
      end
    end

    def set_name_label(name)
      @user_label.text = name
    end

    def set_time(minutes)
      minutes <= 5 ? bg = 'yellow' : bg = '#e0e0e0'
      @time_left.set_markup "<span background='#{bg}' size='xx-large'>#{minutes} min igjen</span>"
      if minutes <= 5 and not @warned
        md = Gtk::MessageDialog.new(self,
                    Gtk::Dialog::DESTROY_WITH_PARENT, Gtk::MessageDialog::WARNING,
                    Gtk::MessageDialog::BUTTONS_OK, "Du blir logget av om #{minutes} minutter. Husk å lagre det du jobber med!")
        md.set_type_hint Gdk::Window::TypeHint::MENU
        md.set_gravity Gdk::Window::GRAVITY_CENTER
        md.move(Gdk.screen_width/2, Gdk.screen_height/2)
        md.run
        md.destroy
        @warned = true
      end
      @warned = false if minutes > 5
      @user = nil if minutes == 0
    end

    def show
      show_all
    end
  end

  # authenticate using sip2 - skip for now

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
            LoggedIn.set_time(message["user"]["minutes"])
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
end

puts "quit"

=begin
1. get mac-adress
2. get client id from api
3. get username+password
4. authenticate (guestuser from db, libraryuser usingsip2)
5. log on
6. ws eventmachine loop
7. back to 3
=end