require "em-synchrony/activerecord"

class Organization < ActiveRecord::Base
  self.table_name = "organization"
  has_many :branches
end

class Branch < ActiveRecord::Base
  belongs_to :organization
  has_many :departments
end

class Department < ActiveRecord::Base
  belongs_to :branch
end