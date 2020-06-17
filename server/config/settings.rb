module Settings
  DEFAULT_MINUTES = 60
  API = {:host => "mycel-api", :port => 9000 }
  WS = {:host => "mycel-server", :port => 9001 }
  SIP2 = {:host => ENV["SIP_HOST"], :port => ENV["SIP_PORT"], :username => ENV["SIP_USER"], :password => ENV["SIP_PASS"]}
  DB = {:test => {:adapter => "sqlite3",
                  :database => ":memory:"},
        :development => {:adapter => "em_mysql2",
                         :database => "mycel",
                         :username => ENV["USERNAME"],
                         :password => ENV["PASSWORD"],
                         :host => "mycel-db",
                         :port => 3306,
                         :pool => 1,
                         :reconnect => false},
        :production => {:adapter => "em_mysql2",
                         :database => "mycel",
                         :username => ENV["USERNAME"],
                         :password => ENV["PASSWORD"],
                         :host => "mycel-db",
                         :port => 3306,
                         :pool => 5,
                         :reconnect => true}}

  # Statistics settings
  FILTER = ["Digitalt Bibliotek"] # Exclude test clients from stats
end