# encoding: utf-8
require "gtk2"

class LogOnWindow < Gtk::Window

  attr_accessor :user, :pin, :clientname

  def initialize(title, clientname)
    super(title)
    @user, @pin = nil
    @clientname = clientname
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
      error = "Du har brukt opp kvoten din for i dag!" if res['minutes'] == 0 and res['authenticated']
    end
    #Gtk.main_quit
    error
  end

end
