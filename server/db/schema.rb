require "em-synchrony/activerecord"

ActiveRecord::Schema.define do
  create_table :organization, :force => true do |t|
    t.string :name, :null => false
    t.string :homepage
  end

  create_table :branches, :force => true do |t|
    t.string :name, :null => false
    t.string :homepage
    t.string :printeraddr
    t.integer :organization_id
  end

  create_table :departments, :force => true do |t|
    t.string :name, :null => false
    t.string :homepage
    t.string :printeraddr
    t.integer :branch_id
  end

  create_table :clients, :force => true do |t|
    t.string :name, :null => false
    t.string :hwaddr, :null => false
    t.string :ipaddr, :null => false
    t.boolean :guest_adult, :default => false
    t.boolean :guest_child, :default => false
    t.integer :age_lower
    t.integer :age_higher
    t.string :homepage
    t.string :printeraddr
    t.integer :department_id
  end

  create_table :opening_hours, :force => true do |t|
    t.time :monday_opens #null = 'closed'
    t.time :monday_closes
    t.time :tuesday_opens
    t.time :tuesday_closes
    t.time :wednsday_opens
    t.time :wednsday_closes
    t.time :thursday_opens
    t.time :thursday_closes
    t.time :friday_opens
    t.time :friday_closes
    t.time :saturday_opens
    t.time :saturday_closes
    t.time :sunday_opens
    t.time :sunday_closes
  end
end
