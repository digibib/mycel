# encoding: utf-8
require "gtk2"

class ShortWindow < Gtk::Window

  attr_accessor :user, :clientname, :time_limit, :button,:user

  def initialize(title, clientname, time_limit)
    super(title)
    @clientname = clientname
    @time_limit = time_limit
    @user = "Anonym"
    build_gui
    fullscreen
    self.keep_above = true
    periodic
  end

  def show
    show_all
  end

  private

  def periodic
    waiting = true
    n = 10

    GLib::Timeout.add_seconds(1) do
      if not destroyed?
        if n == 0
          @button.sensitive = true
          waiting = false
          @button.label = "\nStart\n"
          false
        end
        if waiting
          @button.label = "\nDu kan starte om #{n} sek.\n"
          n -= 1
        end
        true
      end
    end
  end

  def build_gui
    logo = Gtk::Image.new "logo.png"

    @button = Gtk::Button.new "\nDu kan starte om 10 sek.\n"
    @button.sensitive = false
    frame_label = "Logg deg på [ " + @clientname + " ]"
    frame = Gtk::Frame.new frame_label
    frame.label_xalign = 0.5

    infolabel = Gtk::Label.new
    s = "Dette er en korttidsmaskin\nMaks #{@time_limit} minutter!"
    infolabel.set_markup "<span foreground='red'>#{s}</span>"
    infolabel.set_alignment 0.5, 0.5

    vbox = Gtk::VBox.new false, 20

    vbox.pack_start_defaults logo
    vbox.pack_start_defaults infolabel
    vbox.pack_end_defaults @button
    vbox.set_border_width 20

    frame.add vbox

    center_align = Gtk::Alignment.new 0.5, 0.5, 0,0
    center_align.add frame
    add center_align

    @button.signal_connect "clicked" do
      destroy
      Gtk.main_quit
    end

    signal_connect("delete_event") do |widget, event|
      true # don't allow to close window
    end
  end

end

# t = ShortWindow.new "LogOn", "testklient", 15
# t.show


# waiting = true
# n = 9

# GLib::Timeout.add_seconds(1) do
#   if waiting
#     t.button.label = "\nDu kan starte om #{n} sek.\n"
#     n -= 1
#   end
#   if n == 0
#     t.button.sensitive = true
#     waiting = false
#     t.button.label = "\nStart\n"
#     false
#   end
#   true
# end

# Gtk.main