#encoding: utf-8
require "sqlite3"
require "em-synchrony/activerecord"
require "./models"
require "./config/settings"

def template(nums, hours, days, length, length_total, age)
table = <<HERE
table.stats
  thead
    tr
      td.desc
      td.usertype B
      td.usertype G
      td.usertype A
      td.usertype Samlet
  tbody
    tr
      td.desc Antall sesjoner
      td.usertype #{nums["LibraryUser"] || '-'}
      td.usertype #{nums["GuestUser"] || '-'}
      td.usertype #{nums["AnonymousUser"] || '-'}
      td.usertype #{nums.values.compact.inject(:+) || '-'}
    tr
      td.desc Antall timer bruk
      td.usertype #{hours["LibraryUser"] || '-'}
      td.usertype #{hours["GuestUser"] || '-'}
      td.usertype #{hours["AnonymousUser"] || '-'}
      td.usertype #{hours.values.compact.inject(:+) || '-'}
    tr
      td.desc Antall sesjoner per dag, gjennomsnitt*
      td.usertype #{nums["LibraryUser"] ? nums["LibraryUser"]/days : '-'}
      td.usertype #{nums["GuestUser"] ? nums["GuestUser"]/days : '-'}
      td.usertype #{nums["AnonymousUser"] ? nums["AnonymousUser"]/days : '-'}
      td.usertype #{nums.values.comact.length >= 1 ? (nums.values.compact.inject(:+)/days).round(2) : '-' }
    tr
      td.desc Antall timer bruk per dag, gjennomsnitt*
      td.usertype #{hours["LibraryUser"] ? hours["LibraryUser"]/days : '-'}
      td.usertype #{hours["GuestUser"] ? hours["GuestUser"]/days : '-'}
      td.usertype #{hours["AnonymousUser"] ? hours["AnonymousUser"]/days : '-'}
      td.usertype #{hours.values.compact.length >= 1 ? hours.values.compact.inject(:+)/days : '-'}
    tr
      td.desc Lengde på sesjon, gjennomsnitt i minutter
      td.usertype #{length["LibraryUser"] || '-'}
      td.usertype #{length["GuestUser"] || '-'}
      td.usertype #{length["AnonymousUser"] || '-'}
      td.usertype #{length_total || '-'}
    tr
      td.desc Alder, gjennomsnitt
      td.usertype #{age || '-'}
      td.usertype -
      td.usertype -
      td.usertype #{age || '-'}
HERE
  table
end

db = SQLite3::Database.open "logs/stats/stats.db"

stm = db.prepare "select usertype, count(*) from sessions group by usertype"
res = stm.execute

nums = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
res.each do |row|
  nums[row[0]] = row[1]
end
stm.close if stm

stm = db.prepare "select usertype, sum((strftime('%s', stop)-strftime('%s', start)))/3600  from sessions group by usertype"
res = stm.execute

hours = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
res.each do |row|
  hours[row[0]] = row[1]
end
stm.close if stm


stm = db.prepare "select count (distinct date(start)) from sessions"
res = stm.execute
days = 1
res.each do |row|
  days = row[0]
end
stm.close if stm

length = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
stm = db.prepare "select usertype, avg((strftime('%s', stop)-strftime('%s', start)))/60.0 from sessions group by usertype"
res = stm.execute
res.each do |row|
  length[row[0]] = row[1].round(2)
end
stm.close if stm


stm = db.prepare "select avg((strftime('%s', stop)-strftime('%s', start)))/60.0 from sessions"
res = stm.execute
length_total=0
res.each do |row|
  length_total = row[0].round(2)
end
stm.close if stm

stm = db.prepare "select avg(age) from sessions where usertype='LibraryUser'"
res = stm.execute
age = 0
res.each do |row|
  age = row[0].round(2)
end

stm.close if stm


table = template(nums, hours, days, length, length_total, age)
File.open("views/stats_all.slim", "w") { |f| f.write(table) }

ActiveRecord::Base.establish_connection(Settings::DB[:production])


for b in Branch.all
  puts "Generating stats for: #{b.name}"
  constraint = "where branch='#{b.name}'"

  stm = db.prepare "select usertype, count(*) from sessions #{constraint} group by usertype"
  res = stm.execute

  nums = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
  res.each do |row|
    nums[row[0]] = row[1]
  end
  stm.close if stm

  stm = db.prepare "select usertype, sum((strftime('%s', stop)-strftime('%s', start)))/3600 from sessions #{constraint} group by usertype"
  res = stm.execute

  hours = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
  res.each do |row|
    hours[row[0]] = row[1]
  end

  stm.close if stm

  stm = db.prepare "select count (distinct date(start)) from sessions #{constraint}"
  res = stm.execute
  days = 1
  res.each do |row|
    days = row[0]
  end
  stm.close if stm

  length = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
  stm = db.prepare "select usertype, avg((strftime('%s', stop)-strftime('%s', start)))/60.0  from sessions #{constraint} group by usertype"
  res = stm.execute
  res.each do |row|
    length[row[0]] = row[1].round(2)
    length[row[0]] = length[row[0]].round(2) if row[1].round(2)
  end
  stm.close if stm

  stm = db.prepare "select avg((strftime('%s', stop)-strftime('%s', start)))/60.0 from sessions #{constraint}"
  res = stm.execute
  length_total=0
  res.each do |row|
    length_total = row[0]
  end
  length_total = length_total.round(2) if length_total
  stm.close if stm

  stm = db.prepare "select avg(age) from sessions #{constraint} and usertype='LibraryUser'"
  res = stm.execute
  age = 0
  res.each do |row|
    age = row[0]
  end
  age = age.round(2) if age

  table = template(nums, hours, days, length, length_total, age)

  File.open("views/stats_b_#{b.id}.slim", "w") { |f| f.write(table) }
  puts "OK"

  b.departments.each do |d|
    puts "Generating stats for: #{b.name} - #{d.name}"
    constraint = "where branch='#{b.name}' and department='#{d.name}'"

    stm = db.prepare "select usertype, count(*) from sessions #{constraint} group by usertype"
    res = stm.execute

    nums = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
    res.each do |row|
      nums[row[0]] = row[1]
    end
    stm.close if stm

    stm = db.prepare "select usertype, sum((strftime('%s', stop)-strftime('%s', start)))/3600 from sessions #{constraint} group by usertype"
    res = stm.execute

    hours = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
    res.each do |row|
      hours[row[0]] = row[1]
    end
    stm.close if stm

    stm = db.prepare "select count (distinct date(start)) from sessions #{constraint}"
    res = stm.execute
    days = 1
    res.each do |row|
      days = row[0] || 1
    end
    stm.close if stm

    length = {'LibraryUser'=>nil, 'GuestUser'=>nil, 'AnonymousUser'=>nil}
    stm = db.prepare "select usertype, avg((strftime('%s', stop)-strftime('%s', start)))/60.0  from sessions #{constraint} group by usertype"
    res = stm.execute
    res.each do |row|
      length[row[0]] = row[1].round(2)
      length[row[0]] = length[row[0]].round(2) if row[1].round(2)
    end
    stm.close if stm

    length_total=0
    stm = db.prepare "select avg((strftime('%s', stop)-strftime('%s', start)))/60.0 from sessions #{constraint}"
    res = stm.execute
    res.each do |row|
      length_total = row[0]
    end
    length_total = length_total.round(2) if length_total
    stm.close if stm

    stm = db.prepare "select avg(age) from sessions #{constraint} and usertype='LibraryUser'"
    res = stm.execute
    age = 0
    res.each do |row|
      age = row[0]
    end
    age = age.round(2) if age
    stm.close if stm
    table = template(nums, hours, days, length, length_total, age)

    File.open("views/stats_b_#{b.id}_d_#{d.id}.slim", "w") { |f| f.write(table) }
    puts "OK"
  end
end

stm.close if stm
db.close if db

