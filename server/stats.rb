#encoding: utf-8
require "sqlite3"

begin
  db = SQLite3::Database.open "logs/stats/stats.db"

  stm = db.prepare "select usertype, count(*) from sessions group by usertype"
  res = stm.execute

  nums = {}
  res.each do |row|
    nums[row[0]] = row[1]
  end
  stm.close if stm

  stm = db.prepare "select usertype, sum((strftime('%s', stop)-strftime('%s', start)))/3600  from sessions group by usertype"
  res = stm.execute

  hours = {}
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

  length = {}
  stm = db.prepare "select usertype, avg((strftime('%s', stop)-strftime('%s', start)))/60.0 from sessions group by usertype"
  res = stm.execute
  res.each do |row|
    length[row[0]] = row[1].round(2)
  end
  stm.close if stm

  stm = db.prepare "select avg(age) from sessions where usertype='LibraryUser'"
  res = stm.execute
  age = 0
  res.each do |row|
    age = row[0].round(2)
  end


rescue SQLite3::Exception => e
      puts "Exception occured"
      puts e
ensure
      stm.close if stm
      db.close if db
end

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
      td.usertype #{nums["LibraryUser"]}
      td.usertype #{nums["GuestUser"]}
      td.usertype #{nums["AnonymousUser"]}
      td.usertype #{nums.values.inject(:+)}
    tr
      td.desc Antall timer bruk
      td.usertype #{hours["LibraryUser"]}
      td.usertype #{hours["GuestUser"]}
      td.usertype #{hours["AnonymousUser"]}
      td.usertype #{hours.values.inject(:+)}
    tr
      td.desc Antall sesjoner per dag, gjennomsnitt*
      td.usertype #{nums["LibraryUser"]/days}
      td.usertype #{nums["GuestUser"]/days}
      td.usertype #{nums["AnonymousUser"]/days}
      td.usertype #{(nums.values.inject(:+)/days).round(2)}
    tr
      td.desc Antall timer bruk per dag, gjennomsnitt*
      td.usertype #{hours["LibraryUser"]/days}
      td.usertype #{hours["GuestUser"]/days}
      td.usertype #{hours["AnonymousUser"]/days}
      td.usertype #{hours.values.inject(:+)/days}
    tr
      td.desc Lengde på sesjon, gjennomsnitt i minutter
      td.usertype #{length["LibraryUser"]}
      td.usertype #{length["GuestUser"]}
      td.usertype #{length["AnonymousUser"]}
      td.usertype #{(length.values.inject(:+)).round(2)}
    tr
      td.desc Alder, gjennomsnitt
      td.usertype #{age}
      td.usertype -
      td.usertype -
      td.usertype #{age}
HERE

#puts table
File.open("views/stats_all.slim", "w") { |f| f.write(table) }