# encoding: utf-8
require "gtk2"

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

  def name
    @user_label.text
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
      md.signal_connect('response') { md.destroy }
      md.show_all
      @warned = true
    end
    @warned = false if minutes > 5
    @user = nil if minutes <= 0
  end

  def show
    show_all
  end
end