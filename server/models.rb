require "em-synchrony/activerecord"

# initial settings
ActiveRecord::Base.include_root_in_json = false

class Organization < ActiveRecord::Base
  self.table_name = "organization"

  has_many :branches, :dependent => :destroy
  has_many :departments, :through => :branches
  has_one :options, :as => :owner_options
  has_one :admin, :conditions => "superadmin = 1"

  validates_presence_of :name

  accepts_nested_attributes_for :options

  def init
    self.options ||= Options.new()
  end

  def as_json(*args)
    hash = super()
    hash.merge!(:options => self.options.as_json)
  end

end

class Options < ActiveRecord::Base
  belongs_to :owner_options, :polymorphic => true
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
  has_many :admins
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
    hash.merge!(:options_inherited => self.organization.options.as_json)
    hash.except("organization_id")
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
  has_many :admins
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

  validates_presence_of :name, :hwaddr, :ipaddr
  validates_uniqueness_of :name, :hwaddr, :ipaddr

  has_one :user, :inverse_of => :client, :autosave => true
  has_one :screen_resolution
  has_one :options

  def branch
    Department.find(self.department_id).branch
  end

  def occupied?
    self.user
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

  def log_on(c)
    return false if c.user
    c.user = self
    c.user_id = id
    c.save
  end

  def log_off
    self.client.user_id = nil
    self.client.user = nil
  end

end

class LibraryUser < User
  validates_presence_of :username, :age, :name
  validates :username, :uniqueness => true

  def authenticate(pin)
    pin == true
  end

  def type_short
    'B'
  end
end

class GuestUser < User
  validates_presence_of :username, :password, :age
  validates :username, :uniqueness => true

  def authenticate(password)
    self.password == password
  end

  def type_short
    'G'
  end
end

class AnonymousUser < User
  def type_short
    'A'
  end
end

class Admin < ActiveRecord::Base
  validates_presence_of :username, :password
end

class ScreenResolution < ActiveRecord::Base
  validates_presence_of :resolution
end
