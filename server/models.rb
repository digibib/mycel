require "em-synchrony/activerecord"
require "./sip2.rb"
require "./config/settings"

# initial settings
ActiveRecord::Base.include_root_in_json = false

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
  has_one :opening_hours
  has_many :printer_links
  has_many :printers, through: :printer_links
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
  has_many :admins, :as => :owner_admins
  has_one :options, :as => :owner_options, :dependent => :destroy
  has_many :printers

  validates_presence_of :name

  accepts_nested_attributes_for :options

  after_initialize :init


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

  after_initialize :init

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

  has_one :user, :inverse_of => :client, :autosave => true
  belongs_to :screen_resolution
  has_one :options, :as => :owner_options, :dependent => :destroy

  accepts_nested_attributes_for :options, :screen_resolution

  after_initialize :init

  @@cut_off = 15*60
  scope :connected, -> { where("ts > ?", Time.now - @@cut_off) }
  scope :disconnected, -> { where("ts <= ?", Time.now - @@cut_off) }

  def init
    self.options ||= Options.new()
    self.screen_resolution ||= ScreenResolution.find_or_create_by_resolution "auto"
  end

  def branch
    Department.find(self.department_id).branch
  end

  def occupied?
    self.user
  end

  def connected?
    self.ts.nil? ? false : self.ts > Time.now - @@cut_off
  end

  def log_friendly
    "\"#{self.branch.name}\" \"#{self.department.name}\" \"#{self.name}\" #{self.hwaddr}"
  end

  def options_self_or_inherited
    dept = Department.find(self.department.id)
    opt = {}
    self.options.attributes.each do |k,v|
      if self.options[k]
        opt[k] = v
      else
        opt[k] = dept.options_self_or_inherited[k]
      end
    end
    oh = self.options.opening_hours.as_json || dept.options_self_or_inherited['opening_hours']
    opt.merge! "opening_hours" => oh
    opt.except("owner_options_id", "owner_options_type", "id")
  end

  def as_json
    hash = super()
    hash.merge!(:options => self.options.as_json)
    hash.merge! "screen_resolution" => self.screen_resolution.resolution
    hash.merge!(:options_inherited => self.options_self_or_inherited)
    hash.merge!(:printers => self.department.branch.printers.as_json) # TODO FIX
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
    #return false if c.user
    c.user.log_off if c.user
    self.client = c
  end

  def log_off
    self.client.user = nil if (self.client and self.client.user)
    self.client = nil
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


class Request < ActiveRecord::Base
  default_scope order('ts desc')
end

class Profile < ActiveRecord::Base

end

class Printer < ActiveRecord::Base
  has_one :printer_profile
end

class PrinterProfile < ActiveRecord::Base
  has_many :printers
end
