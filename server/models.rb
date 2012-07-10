require "em-synchrony/activerecord"

class Organization < ActiveRecord::Base
  self.table_name = "organization"
  
  has_many :branches, :dependent => :destroy
  has_many :departments, :through => :branches
  has_one :opening_hours

  validates_presence_of :name
end

class Branch < ActiveRecord::Base
  belongs_to :organization
  has_many :departments, :dependent => :destroy
  has_one :opening_hours

  validates_presence_of :name
end

class Department < ActiveRecord::Base
  belongs_to :branch
  has_many :clients, :dependent => :destroy
  has_one :opening_hours

  validates_presence_of :name

  def homepage
    read_attribute(:homepage) || Branch.find(self.branch_id).homepage
  end
end

class Client < ActiveRecord::Base
  belongs_to :department

  validates_presence_of :name, :hwaddr

  def homepage
    read_attribute(:homepage) || Department.find(self.department_id).homepage
  end
end