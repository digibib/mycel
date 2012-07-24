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