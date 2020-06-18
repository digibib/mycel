#encoding: UTF-8
require "em-synchrony/activerecord"
require "./sip2.rb"
require "./config/settings"
#require 'logger'
# initial settings
ActiveRecord::Base.include_root_in_json = false

#ActiveRecord::Base.logger = Logger.new(STDOUT)
#config.log_level = :debug

class Organization < ActiveRecord::Base
  self.table_name = "organization"

  has_many :branches, :dependent => :destroy
  has_many :departments, :through => :branches
  has_one :options, :as => :owner_options
  has_one :admin, :as => :owner_admins, :conditions => "superadmin = 1"

  validates_presence_of :name

  accepts_nested_attributes_for :options

  def init
    self.options ||= Options.new()
  end

  def as_json(*args)
    hash = super()
    hash.merge!(:options => self.options.as_json)
  end

  def options_self_or_inherited
    opt = self.options.as_json
    oh = self.options.opening_hours.as_json
    opt.merge! "opening_hours" => oh
    opt.except("owner_options_id", "owner_options_type", "id")
  end
end


class Options < ActiveRecord::Base
  belongs_to :owner_options, :polymorphic => true
  belongs_to :printers, :foreign_key => "default_printer_id"
  has_one :opening_hours

  accepts_nested_attributes_for :opening_hours

  def as_json(*args)
    hash = super()
    hash.merge!(:opening_hours => self.opening_hours.as_json)
    hash.except("owner_options_id", "owner_options_type", "id")
  end
end


class Branch < ActiveRecord::Base
  belongs_to :organization
  has_many :departments, :dependent => :destroy
  has_many :clients, :through => :departments
  has_many :admins, :as => :owner_admins
  has_one :options, :as => :owner_options, :dependent => :destroy
  has_one :opening_hours, through: :options
  has_many :printers

  validates_presence_of :name

  accepts_nested_attributes_for :options

  after_initialize :init, if: :new_record?

  # scope to optimize api requests
  scope :api_includes, includes(:printers, :organization, options: :opening_hours)


  def init
    self.options ||= Options.new()
  end

  def as_json(*args)
    hash = super()
    hash.merge!(:options => self.options.as_json)
    hash.merge!(:options_inherited => self.organization.options.as_json)
    hash.merge!(:printers => self.printers.as_json)

    hash.except("organization_id")
  end

  def authorized?(admin)
    admin.superadmin? || self.admins.include?(admin)
  end

  def options_self_or_inherited
    opt = {}
    self.options.attributes.each do |k,v|
      if self.options[k]
        opt[k] = v
      else
        opt[k] = self.organization.options.send(k.to_sym)
      end
    end
    oh = self.options.opening_hours.as_json || self.organization.options.opening_hours.as_json
    opt.merge! "opening_hours" => oh
    opt.except("owner_options_id", "owner_options_type", "id")
  end

end

class Department < ActiveRecord::Base
  belongs_to :branch
  has_many :clients, :dependent => :destroy
  has_many :admins, :as => :owner_admins
  has_one :options, :as => :owner_options, :dependent => :destroy

  validates_presence_of :name

  accepts_nested_attributes_for :options

  after_initialize :init, if: :new_record?

  # scope to optimize api requests
  scope :api_includes, includes(options: :opening_hours, :branch => [:organization, :opening_hours])

  def organization
    branch.organization
  end

  def init
    self.options ||= Options.new()
  end

  def as_json(*args)
    hash = super()
    hash.merge!(:options => self.options.as_json)
    hash.merge!(:options_inherited => self.branch.options_self_or_inherited)
    hash.except("organization_id")
  end

  def authorized?(admin)
    admin.superadmin? || self.admins.include?(admin) || self.branch.admins.include?(admin)
  end

  def options_self_or_inherited
    branch = Branch.find(self.branch_id)
    opt = {}
    self.options.attributes.each do |k,v|
      if self.options[k]
        opt[k] = v
      else
        opt[k] = branch.options_self_or_inherited[k]
      end
    end
    oh = self.options.opening_hours.as_json || self.branch.options_self_or_inherited['opening_hours']
    opt.merge! "opening_hours" => oh
    opt.except("owner_options_id", "owner_options_type", "id")
  end
end

class Client < ActiveRecord::Base
  belongs_to :department

  validates_presence_of :name, :hwaddr
  validates_uniqueness_of :name, :hwaddr

  has_one :user, :inverse_of => :client, dependent: :nullify
  belongs_to :screen_resolution
  has_one :options, :as => :owner_options, :dependent => :destroy
  has_one :client_spec, :dependent => :destroy

  has_many :connection_events, :dependent => :destroy
  has_many :logon_events, :dependent => :destroy

  accepts_nested_attributes_for :options, :screen_resolution

  after_initialize :init, if: :new_record?

  @@cut_off = 15*60 # determines when the client is flagged as disconnected
  scope :connected, -> { where("ts > ?", Time.now - @@cut_off) }
  scope :disconnected, -> { where("ts <= ?", Time.now - @@cut_off) }

  # optimized scope for the inventory page
  scope :inventory_view, includes(:user, :client_spec, :options, department: :branch)


  def init
    self.options ||= Options.new()
    self.screen_resolution ||= ScreenResolution.find_or_create_by_resolution "auto"
  end

  def branch
    department.branch
  end

  def occupied?
    user.present?
  end

  def connected?
    ts.blank? ? false : ts > Time.now - @@cut_off
  end


  def status
    if occupied?
      'occupied'
    elsif ts.nil?
      'unseen'
    elsif connected?
      'available'
    else
      'disconnected'
    end
  end


  # called when api receives a keep_alive signal from a client
  def update_timestamp
    if !connected?
      ConnectionEvent.generate_offline_event(id, ts)
      update_attributes(online_since: Time.now)
    end

    touch(:ts)
  end

  # called from the periodic timer in server.rb
  # note that this does not check to see if current user and previous user
  # are the same for on-going connections, and thus does not yield a correct
  # count for # of total logins.
  def update_logon_events
    has_active_event = logon_events.present? && logon_events.last.present? && logon_events.last.ended.blank?
    has_active_user = user.present?

    if has_active_event && !has_active_user
      event = logon_events.last
      event.ended = Time.now
      event.save
    elsif !has_active_event && has_active_user
      LogonEvent.new({client_id: id}).save
    end
  end

  def log_friendly
    "\"#{self.branch.name}\" \"#{self.department.name}\" \"#{self.name}\" #{self.hwaddr}"
  end

  def options_self_or_inherited
    dept = department #Department.find(self.department.id)
    opt = {}
    self.options.attributes.each do |k,v|
      if self.options[k]
        opt[k] = v
      else
        opt[k] = dept.options_self_or_inherited[k]
      end
    end
    begin
      oh = self.options.opening_hours.as_json || dept.options_self_or_inherited['opening_hours']
      opt.merge! "opening_hours" => oh
    rescue Exception => e
      STDERR.puts e.message
    end
    opt.except("owner_options_id", "owner_options_type", "id")
  end

  def as_json
    hash = super()
    hash.merge!(:options => self.options.as_json)
    hash.merge! "screen_resolution" => self.screen_resolution.resolution
    hash.merge!(:options_inherited => self.options_self_or_inherited)
    hash.merge!(:printers => self.department.branch.printers)
  end
end

class OpeningHours < ActiveRecord::Base
  belongs_to :options

  validate :hours_or_closed_flag_must_be_present,
           :opening_hours_cant_be_later_than_closing_hours

  #TODO refactor theese ugly validations!

  def hours_or_closed_flag_must_be_present
    days = %w(monday tuesday wednsday thursday friday saturday sunday)
    all_fields = []
    days.each { |d| all_fields << [d+'_opens', d+'_closes', d+'_closed'] }
    for triple in all_fields
      if ((self.send(triple[0].to_sym).blank? || self.send(triple[1].to_sym).blank?) & (self.send(triple[2].to_sym).blank?))
        errors.add("opening hours or closed flag", "can't be blank")
      end
    end
  end

  def opening_hours_cant_be_later_than_closing_hours
    days = %w(monday tuesday wednsday thursday friday saturday sunday)
    day_pairs = []
    days.each { |d| day_pairs << [d+'_opens', d+'_closes'] }
    for pair in day_pairs
      if self.send(pair[0].to_sym).blank? || self.send(pair[1].to_sym).blank?
        next
      end
      t1 = self.send(pair[0].to_sym)
      t2 = self.send(pair[1].to_sym)
      errors.add("openings hours", "cant be later than closing hours") if t1 > t2
    end
  end

  def attributes_formatted
    # needed for comparing json-request for changes
    att = {}
    attributes.each  do |k,v|
      if v.class == Time
        att[k] = v.strftime('%H:%M')
      elsif v.class == Fixnum
        att[k] = v.to_s #because Json converts integers to strings??
      else
        att[k] = v
      end
    end
    att
  end

  def as_json(*args)
    hash = super()
    hash.except("options_id")
  end

  #TODO: find a more elegant solution to this repeitiveness:
  #TODO: Get the Time::DEFAULT_FORMATS(:default => '%H:%M') to work..

  def monday_opens
    read_attribute(:monday_opens).strftime('%H:%M') if read_attribute(:monday_opens)
  end

  def monday_closes
    read_attribute(:monday_closes).strftime('%H:%M') if read_attribute(:monday_closes)
  end

  def tuesday_opens
    read_attribute(:tuesday_opens).strftime('%H:%M') if read_attribute(:tuesday_opens)
  end

  def tuesday_closes
    read_attribute(:tuesday_closes).strftime('%H:%M') if read_attribute(:tuesday_closes)
  end

  def wednsday_opens
    read_attribute(:wednsday_opens).strftime('%H:%M') if read_attribute(:wednsday_opens)
  end

  def wednsday_closes
    read_attribute(:wednsday_closes).strftime('%H:%M') if read_attribute(:wednsday_closes)
  end

  def thursday_opens
    read_attribute(:thursday_opens).strftime('%H:%M') if read_attribute(:thursday_opens)
  end

  def thursday_closes
    read_attribute(:thursday_closes).strftime('%H:%M') if read_attribute(:thursday_closes)
  end

  def friday_opens
    read_attribute(:friday_opens).strftime('%H:%M') if read_attribute(:friday_opens)
  end

  def friday_closes
    read_attribute(:friday_closes).strftime('%H:%M') if read_attribute(:friday_closes)
  end

  def saturday_opens
    read_attribute(:saturday_opens).strftime('%H:%M') if read_attribute(:saturday_opens)
  end

  def saturday_closes
    read_attribute(:saturday_closes).strftime('%H:%M') if read_attribute(:saturday_closes)
  end

  def sunday_opens
    read_attribute(:sunday_opens).strftime('%H:%M') if read_attribute(:sunday_opens)
  end

  def sunday_closes
    read_attribute(:sunday_closes).strftime('%H:%M') if read_attribute(:sunday_closes)
  end
end

class User < ActiveRecord::Base
  validates_presence_of  :minutes

  belongs_to :client, :inverse_of => :user, :autosave => true

  def self.logged_on
    where("client_id IS NOT NULL")
  end

  def self.inactive
    where("client_id IS NULL")
  end

  def name
    read_attribute(:name) || self.username || "Anonym_"+self.id.to_s
  end

  def username
    read_attribute(:username) || "Anonym_"+self.id.to_s
  end

  def log_on(c)
    c.user = self unless c.user and c.user == self
  end

  def log_off
    self.client.user = nil if client and client.user
  end

  def as_json(*args)
    hash = super()
    hash.merge!(:type => self.type_short)
    hash.except("password")
  end

end

class LibraryUser < User
  validates_presence_of :username #, :age, :name, hm need to authenticate w sip2 first!
  validates :username, :uniqueness => true

  def authenticate(pin)
    msg = formMessage(self.username, pin)

    sip2client = DGClient.new
    result = sip2client.send_message msg
    authorized = result.match /(?<=\|CQ)(.)(?=\|)/
    bdate = result.match /(?<=\|PB)(.*?)(?=\|)/
    name = result.match /(?<=\|AE)(.*?)(?=\|)/

    if name[0].strip().empty? #invalid username(cardnr)
      false
    else
      now = Time.now.utc.to_date
      begin
        dob = Time.strptime(bdate[0], "%Y%m%d")
      rescue ArgumentError
        # When user is stored with invalid date,
        # set arbitrary date as not to get an invalid user
        # TODO use age=0 as unknown age?
        dob = Time.strptime("1980-01-01", "%Y-%m-%d")
      end
      age = now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
      self.age = age
      self.name = name[0]
      self.minutes ||= Settings::DEFAULT_MINUTES
      save
      authorized[0] == 'Y'
    end
  end

  def type_short
    'B'
  end

  def age_log
    self.age
  end

  def log_friendly
    "LibraryUser[#{self.id}], #{self.age}"
  end
end

class GuestUser < User
  validates_presence_of :username, :password, :age
  validates :username, :uniqueness => true

  def authenticate(password)
    self.password == password
  end

  def age_log
    "#{self.age > 15 ? 'adult' : 'child'}"
  end

  def type_short
    'G'
  end

  def log_friendly
    "GuestUser[#{self.id}], #{self.age > 15 ? 'adult' : 'child'}"
  end
end

class AnonymousUser < User
  def age_log
    'unknown'
  end

  def type_short
    'A'
  end

  def log_friendly
    "AnonymousUser[#{self.id}], unknown"
  end
end

class Admin < ActiveRecord::Base
  validates_presence_of :username, :password

  # method returns an array of which departments the admin has access to
  def allowed_departments
    if self.owner_admins_type == 'Department'
      return [self.owner_admins_id]
    elsif self.owner_admins_type == 'Branch'
      return Branch.find(self.owner_admins_id).departments.collect { |d| d.id }
    else
      return Department.all.collect { |d| d.id }
    end
  end
end

class ScreenResolution < ActiveRecord::Base
  validates_presence_of :resolution
  has_one :client
end

# When a client that is not registered in the database tries to connect to
# mycel, its registered with its MAC address as a request. The sole purpose
# of this class is to allow quick registration of new clients via the UI.
class Request < ActiveRecord::Base
  default_scope order('ts desc')
end

# Boot profiles for pixiecore. Currently not in use.
class Profile < ActiveRecord::Base

end

class Printer < ActiveRecord::Base
  belongs_to :printer_profile
  belongs_to :branch
  has_many :options, class_name: "Options", foreign_key: "default_printer_id", dependent: :nullify

  # scope to optimize api requests
  scope :api_includes, includes(:options)

  # does any branch or affiliate have this printer set as their default?
  def has_subscribers
    options.size > 0
  end
end


class PrinterProfile < ActiveRecord::Base
  has_many :printers, dependent: :destroy
end

class ClientSpec < ActiveRecord::Base
  belongs_to :client
end


#-------------------------------------------------------------------------
class ClientEvent < ActiveRecord::Base
  belongs_to :client
  scope :omit_reboots, -> { where("not (HOUR(started) IN (3,4) AND TIMESTAMPDIFF(MINUTE,started, ended) < 120)") }


  # representation of the event for use in html title attribrutes. quick and dirty.
  def to_title(is_ongoing = false)
    duration = ended - started
    hours = (duration/3600).to_i
    hrs = hours > 0 ? "#{hours}t" : ""
    minutes = "#{((duration%3600)/60).to_i}m"

    duration_string = "#{hrs}#{minutes}"

    if [3,4].include?(started.hour) && [3,4].include?(ended.hour) && started.mday == ended.mday
      ""
    else
      label = is_ongoing ? 'Vært offline i' : 'Varighet'
      started_string = started.strftime('%e/%m %H:%M')
      ended_string = started.mday == ended.mday ? ended.strftime('%H:%M') : ended.strftime('%e/%m %H:%M')


      "#{label}: #{duration_string} Periode: #{started_string}-#{ended_string}\n"
    end
  end


  def self.create_occupied_series(client_id, no_of_days = 3)
    client = Client.find(client_id)

    now = Time.now

    period_start = now - no_of_days.days
    period_duration = no_of_days * 3600 * 1000 * 24

    events =
    ClientEvent.omit_reboots
    .where(client_id: client_id)
    .where("ended >= '#{period_start}'")
    .order('started asc')

    data = []

    # adds event if client has been down for the entire duration of the period
    if events.size == 0 && (client.ts.nil? || client.ts < period_start)
      data << {start: period_start, end: now, type: 'offline', titlestamp: client.ts}
    end

    # adds recorded events
    events.each do |event|
      started = event.started < period_start ? period_start : event.started
      type = event.is_a?(ConnectionEvent) ? 'offline' : 'occupied'
      ended = event.ended || now
      data << {start: started, end: ended, type: type}
    end

    # adds event if client has been online during period but is currently offline
    if !client.connected? && (data.size > 0)
      start = client.ts < period_start ? period_start : client.ts
      data << {start: start, end: now, type: 'offline'}
    end


    {period_start: period_start, period_duration: period_duration, events: data}.to_json
  end

  # TODO move this somewhere proper
  # converts opening schedule to an array of hashes
  def self.get_opening_hours_array(department)
    schedule = department.options.opening_hours || department.branch.options.opening_hours || department.branch.organization.options.opening_hours

    opening_hours = []
    wdays = %w[sunday monday tuesday wednsday thursday friday saturday]
    wdays.each do |wday|
      opens = schedule["#{wday}_opens"]
      closes = schedule["#{wday}_closes"]
      interval = closes && opens ? (closes - opens) / 60 : 0
      opening_hours << {opens: opens, closes: closes, interval: interval}
    end

    opening_hours
  end

  def self.get_downtime_in_minutes(client, period_start, period_end, last = false)
    events = client.connection_events.where("ended >= '#{period_start}' and started <= '#{period_end}'")

    total_downtime = 0

    # sets downtime if client has been down for the entire duration of the period
    if events.size == 0 && (client.ts.nil? || client.ts < period_start)
      total_downtime += period_end - period_start
    end

    # adds downtime from finished events
    events.each do |event|
      ended = event.ended > period_end ? period_end : event.ended
      started = event.started < period_start ? period_start : event.started
      total_downtime += (ended - started)
    end


    # adds downtime if client has been online during period but is currently offline
    if last && events.size > 0 && !client.connected?
      total_downtime += period_end - client.ts
    end

    total_downtime / 60
  end


  def self.get_occupied_time_in_minutes(client, period_start, period_end)
    events = client.logon_events.where("ended >= '#{period_start}' and started <= '#{period_end}'")

    # adds time from finished events
    occupied_time = events.inject(0) {|sum, event| sum + (event.ended - event.started) }

    #add time from unfinished session
    if client.occupied?
      cur_event = client.logon_events.last
      occupied_time += Time.now - cur_event.started if cur_event.present? && cur_event.ended.blank?
    end

    occupied_time / 60
  end

  # calculates number of minutes(?) the department has been open during the period
  # note: this does not factor in any changes in the opening schedule
  def self.get_accumulated_opening_time(schedule, period_start, period_end)
    result = 0
    tmp_date = period_start

    while tmp_date <= period_end
      result += schedule[tmp_date.wday][:interval]
      tmp_date = tmp_date + 1.day
    end

    result
  end


  def self.create_branch_stats(branch, no_of_days = 3)
    period_end = Time.now
    period_start = period_end - no_of_days.days

    results = []

    branch.departments.each do |department|
      dept_results = {name: department.name}
      client_results = []

      opening_hours = get_opening_hours_array(department)
      total = get_accumulated_opening_time(opening_hours, period_start, period_end)

      department.clients.each do |client|
        client_results << client_stats_by_percent(client, opening_hours, period_start, period_end, total)
      end

      results << dept_results.merge(clients: client_results)
    end

    results
  end


  def self.create_client_stats(client, no_of_days = 3)
    period_end = Time.now
    period_start = period_end - no_of_days.days

    opening_hours = get_opening_hours_array(client.department)
    total = get_accumulated_opening_time(opening_hours, period_start, period_end)

    events = []

    if !client.connected?
      temp_event = ConnectionEvent.new(client_id: client.id, started: client.ts, ended: Time.now)
      events << temp_event.to_title(true)
      events << "---------------"
    end

    client.connection_events.where("started >= '#{period_start}'").order("started DESC").each do |event|
      events << event.to_title
    end

    {downtime_events: events}.merge(client_stats_by_percent(client, opening_hours, period_start, period_end, total))
  end


  def self.client_stats_by_percent(client, opening_hours, period_start, period_end, total)
    occupied_time = get_occupied_time_in_minutes(client, period_start, period_end)
    occupied_time_percent = ((occupied_time * 100) / total).to_i

    tmp_date = period_start
    downtime = 0

    while tmp_date <= period_end
      oh = opening_hours[tmp_date.wday]
      opens = oh[:opens]
      closes = oh[:closes]

      if opens && closes
        opens = Time.new(tmp_date.year, tmp_date.month, tmp_date.day, opens.hour, opens.min, 0, 0)
        closes = Time.new(tmp_date.year, tmp_date.month, tmp_date.day, closes.hour, closes.min, 0, 0)
        is_last = (tmp_date + 1.day) >= period_end
        downtime += get_downtime_in_minutes(client, opens, closes, is_last)
      end

      tmp_date = tmp_date + 1.day
    end

    uptime_percent = 100 - ((downtime * 100) / total).to_i
    {client_id: client.id, client_name: client.name, occupied_time_percent: occupied_time_percent, uptime_percent: uptime_percent}
  end
end


class ConnectionEvent < ClientEvent
  def self.generate_offline_event(client_id, client_ts)
    event = create(client_id: client_id, started: client_ts, ended: Time.now)
  end

end

class LogonEvent < ClientEvent

end
