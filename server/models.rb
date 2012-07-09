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
    if not self.read_attribute(:homepage)
      return Branch.find(self.branch_id).homepage
    end
    read_attribute(:homepage)
  end
end

class Client < ActiveRecord::Base
  belongs_to :department

  validates_presence_of :name, :hwaddr

  def homepage
    if not self.read_attribute(:homepage)
      return Department.find(self.department_id).homepage
    end
    read_attribute(:homepage)
  end
end