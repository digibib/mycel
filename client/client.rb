#encoding: UTF-8
require "gtk2"
require "json"
require "net/http"
require "em-ws-client"

# NOTE: The following method of getting the MAC-adress works on debian-based
#       linux, but I'm not sure it works whith every system.
#       This fetches address of eth0; make sure to fetch the right eth (or wlan)
#       if the client has several network connections
client_address = %x[cat '/sys/class/net/eth0/address'].strip

if not client_address
  puts "Fatal error: Could not retreive MAC-address of client."
  puts "This is needed for identifying the client."
  exit 0
end

uri = URI('http://localhost:9000/api/identify/'+client_address)
res = nil

until res
  begin
    res = Net::HTTP.get_response(uri)
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

    userlabel = Gtk::Label.new "Lånenummer"
    userlabel.set_alignment 1, 0.5
    pinlabel = Gtk::Label.new "PIN-kode"
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
    @pinentry.max_length = 4
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
      error = "Skriv inn ditt lånenummer"
      @userentry.grab_focus
    elsif @user != "" and @pin == ""
      error = "Skriv inn PIN-koden din"
      @pinentry.grab_focus
    elsif @pin == "" and @user == ""
      error = "Skriv inn lånenummer og PIN-kode"
      @userentry.grab_focus
    end
    error
  end

end

LogOn = LogOnWindow.new "LogOn", client['name']
LogOn.show
Gtk.main

puts LogOn.user, LogOn.pin


class LoggedInWindow < Gtk::Window
  def initialize(title, user)
    super(title)

    @user = user
    self.resizable = false
    self.keep_above = true
    set_type_hint Gdk::Window::TypeHint::MENU
    set_size_request(180, 120)

    # position window in lower right corner, 50 px from screen edges
    set_gravity Gdk::Window::GRAVITY_SOUTH_WEST
    move (Gdk.screen_width - size[0] - 50), (Gdk.screen_height - size[1] - 50)

    user = Gtk::Label.new @user
    minutes = 60
    time_left = Gtk::Label.new
    time_left.set_markup "<span size='xx-large'>%d min igjen</span>" % minutes

    button = Gtk::Button.new "Logg ut"

    box = Gtk::VBox.new false, 5
    box.set_border_width 5
    box.pack_start_defaults user
    box.pack_start_defaults time_left
    box.pack_start_defaults button
    add box

    button.signal_connect "clicked" do
      destroy
      Gtk.main_quit
    end

    signal_connect "delete_event" do
      # don't destroy window when x button is clicked
      true
    end
  end

  def show
    show_all
  end
end

LoggedIn = LoggedInWindow.new client['name'], LogOn.user
LoggedIn.show

# authenticate using sip2 - skip for now
EM.run do
  give_tick = proc { Gtk::main_iteration_do(blocking=false); EM.next_tick(give_tick); }
  give_tick.call
end