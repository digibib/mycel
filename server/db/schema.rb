require "em-synchrony/activerecord"

ActiveRecord::Schema.define do
  create_table :organization, :force => true do |t|
    t.string :name, :null => false
    t.string :homepage

    t.integer :owner_hours_id
  end

  create_table :branches, :force => true do |t|
    t.string :name, :null => false
    t.string :homepage
    t.string :printeraddr

    t.integer :organization_id
    t.integer :owner_hours_id
  end

  create_table :departments, :force => true do |t|
    t.string :name, :null => false
    t.string :homepage
    t.string :printeraddr

    t.integer :branch_id
    t.integer :owner_hours_id
  end

  create_table :clients, :force => true do |t|
    t.string :name, :null => false
    t.string :hwaddr, :null => false
    t.string :ipaddr, :null => false
    t.boolean :shorttime, :default => false
    t.string :printeraddr

    t.integer :screen_resolution_id, :default => 1
    t.integer :department_id
  end

  create_table :opening_hours, :force => true do |t|
    t.boolean :monday_closed, :default => false
    t.time :monday_opens
    t.time :monday_closes
    t.boolean :tuesday_closed, :default => false
    t.time :tuesday_opens
    t.time :tuesday_closes
    t.boolean :wednsday_closed, :default => false
    t.time :wednsday_opens
    t.time :wednsday_closes
    t.boolean :thursday_closed, :default => false
    t.time :thursday_opens
    t.time :thursday_closes
    t.boolean :friday_closed, :default => false
    t.time :friday_opens
    t.time :friday_closes
    t.boolean :saturday_closed, :default => false
    t.time :saturday_opens
    t.time :saturday_closes
    t.boolean :sunday_closed, :default => false
    t.time :sunday_opens
    t.time :sunday_closes

    t.integer :owner_hours_id
    t.string :owner_hours_type
  end

  create_table :admins, :force => true do |t|
    t.boolean :superadmin, :default => false
    t.string :username, :null => false
    t.string :password, :null => false
    t.string :email
  end

  create_table :users, :force => true do |t|
    t.string :username
    t.string :password
    t.integer :minutes
    t.integer :age

    t.string :type
    t.timestamps
  end

  create_table :screen_resolutions, :force => true do |t|
    t.string :resolution
  end
end
