require "em-synchrony/activerecord"

# set initial settings
ActiveRecord::Base.include_root_in_json = false

class Organization < ActiveRecord::Base
  self.table_name = "organization"

  has_many :branches, :dependent => :destroy
  has_many :departments, :through => :branches
  has_one :opening_hours, :as => :owner_hours
  has_one :admin, :conditions => "superadmin = 1"

  validates_presence_of :name
end

class Branch < ActiveRecord::Base
  belongs_to :organization
  has_many :departments, :dependent => :destroy
  has_many :admins
  has_one :opening_hours, :as => :owner_hours, :dependent => :destroy

  validates_presence_of :name

  def as_json(*args)
    hash = super()
    hash.merge!(:opening_hours => self.opening_hours, :inherited => {
      :opening_hours => self.opening_hours_inherited,
      :age_limit_lower => self.age_limit_lower_inherited,
      :age_limit_higher => self.age_limit_higher_inherited,
      :homepage => self.homepage_inherited,
      :time_limit => self.time_limit_inherited
      })
  end

  def homepage_inherited
    read_attribute(:homepage) || Organization.first.homepage
  end

  def time_limit_inherited
    read_attribute(:time_limit) || Organization.first.time_limit
  end

  def age_limit_lower_inherited
    read_attribute(:age_limit_lower) || Organization.first.age_limit_lower
  end

  def age_limit_higher_inherited
    read_attribute(:age_limit_higher) || Organization.first.age_limit_higher
  end

  def opening_hours_inherited
    self.opening_hours || Organization.first.opening_hours
  end

end

class Department < ActiveRecord::Base
  belongs_to :branch
  has_many :clients, :dependent => :destroy
  has_many :admins
  has_one :opening_hours, :as => :owner_hours, :dependent => :destroy

  validates_presence_of :name

  def as_json(*args)
    hash = super()
    hash.merge!(:opening_hours => self.opening_hours, :inherited => {
      :opening_hours => self.opening_hours_inherited,
      :age_limit_lower => self.age_limit_lower_inherited,
      :age_limit_higher => self.age_limit_higher_inherited,
      :homepage => self.homepage_inherited,
      :time_limit => self.time_limit_inherited
      })
  end

  def time_limit_inherited
    read_attribute(:time_limit) || Branch.find(self.branch_id).time_limit_inherited
  end

  def homepage_inherited
    read_attribute(:homepage) || Branch.find(self.branch_id).homepage_inherited
  end

  def opening_hours_inherited
    self.opening_hours || Branch.find(self.branch_id).opening_hours_inherited
  end

  def age_limit_lower_inherited
    read_attribute(:age_limit_lower) || Branch.find(self.branch_id).age_limit_lower_inherited
  end

  def age_limit_higher_inherited
    read_attribute(:age_limit_higher) || Branch.find(self.branch_id).age_limit_higher_inherited
  end


  def printer_addr
    read_attribute(:printer_addr) || Branch.find(self.branch_id).printer_addr
  end

end

class Client < ActiveRecord::Base
  belongs_to :department

  validates_presence_of :name, :hwaddr, :ipaddr
  validates_uniqueness_of :name, :hwaddr, :ipaddr

  has_one :user, :inverse_of => :client, :autosave => true
  has_one :screen_resolution

  def homepage
    Department.find(self.department_id).homepage
  end

  def branch
    Department.find(self.department_id).branch
  end

  def printer_addr
    Department.find(self.department_id).printer_addr
  end

  def occupied?
    self.user
  end

end

class OpeningHours < ActiveRecord::Base
  belongs_to :owner_hours, :polymorphic => true

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
  validates_presence_of :username, :age
  validates :username, :uniqueness => true

  def type_short
    'B'
  end
end

class GuestUser < User
  validates_presence_of :username, :password, :age
  validates :username, :uniqueness => true

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
