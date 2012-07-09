require "em-synchrony/activerecord"

ActiveRecord::Schema.define do
  create_table :organization, :force => true do |t|
    t.string :name, :null => false
  end

  create_table :branches, :force => true do |t|
    t.string :name, :null => false
  end

  create_table :departments, :force => true do |t|
    t.string :name, :null => false
  end
end
