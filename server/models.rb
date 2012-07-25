require "em-synchrony/activerecord"

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

  def homepage
    read_attribute(:homepage) || Organization.find(self.organization_id).homepage
  end

  def opening_hours
    read_attribute(:opening_hours) || Organization.find(self.organization_id).opening_hours
  end

end

class Department < ActiveRecord::Base
  belongs_to :branch
  has_many :clients, :dependent => :destroy
  has_many :admins
  has_one :opening_hours, :as => :owner_hours, :dependent => :destroy

  validates_presence_of :name

  def homepage
    read_attribute(:homepage) || Branch.find(self.branch_id).homepage
  end

  def opening_hours
    read_attribute(:opening_hours) || Branch.find(self.branch_id).opening_hours
  end

  def printer_addr
    read_attribute(:printer_addr) || Branch.find(self.branch_id).printer_addr
  end

end

class Client < ActiveRecord::Base
  belongs_to :department

  validates_presence_of :name, :hwaddr
  validates_uniqueness_of :name, :hwaddr, :ipaddr

  has_one :user
  has_one :screen_resolution

  def homepage
    Department.find(self.department_id).homepage
  end

  def printer_addr
    Department.find(self.department_id).printer_addr
  end

end

class OpeningHours < ActiveRecord::Base
  belongs_to :owner_hours, :polymorphic => true

  validate :hours_or_closed_flag_must_be_present,
           :opening_hours_cant_be_later_than_closing_hours

  #TODO refactor theese ugly validations!

  def hours_or_closed_flag_must_be_present
    days = %w(monday tuesday wednsday thursday friday sunday)
    all_fields = []
    days.each { |d| all_fields << [d+'_opens', d+'_closes', d+'_closed'] }
    for triple in all_fields
      if ((self.send(triple[0].to_sym).blank? || self.send(triple[1].to_sym).blank?) & (self.send(triple[2].to_sym).blank?))
        errors.add("opening hours or closed flag", "can't be blank")
      end
    end
  end

  def opening_hours_cant_be_later_than_closing_hours
    days = %w(monday tuesday wednsday thursday friday sunday)
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

end

class User < ActiveRecord::Base
  validates_presence_of  :minutes
end

class LibraryUser < User
  validates_presence_of :username, :age
  validates :username, :uniqueness => true
end

class GuestUser < User
  validates_presence_of :username, :password, :age
  validates :username, :uniqueness => true
end

class AnonymousUser < User
end

class Admin < ActiveRecord::Base
  validates_presence_of :username, :password
end

class ScreenResolution < ActiveRecord::Base
  validates_presence_of :resolution
end