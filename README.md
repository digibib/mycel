# Mycel
Mycel is a client/server network system for monitoring and administering publicly available computers. It is currently being developed for use at the Oslo Public Library ([Deichmanske bibliotek]).

The clients are intended to be used library patrons, who log on using their library card number and personal code. Guest users can also be allowed if clients are configured so.


## Installation Instructions
The system is quite easy to set up. Both server and client is written in Ruby.

### Client
Mycel is being developed and tested on clients running lubuntu 11.10 and 12.04, but any system capable of running GTK-based applications should work.

The client is written in Ruby, so obviously you should have Ruby installed. Development is done on version 1.9.3. Simply run bundle install and the client should be good to go. You may have to install some development headers in order to compile the gtk2-gem. On Debian-based systems you can try
    sudo apt-get install libgtk2.0-dev

Also development libraries for mysql client is needed for server
    sudo apt-get install libmysqlclient-dev
    
### Server
The server is written using the asynchronous web server framework [Goliath]. It provides its own server. To get it up running, simply do a bundle install and, start the server using:
    ruby mycel.rb -e production

Goliath is not tied to any particular Ruby, but recommended is MRI Ruby 1.9.3.

**Server configuration**
Most of the options can be configured in the web-based administration interface. The remaining configuration (SIP2 server adresse and so on) is done in `config/organization.yaml`

## Technical Documentation
Kommer etterhvert...

**Schematic overview**

**What happens when the socket connection is lost?**

**Troubleshooting**


  [Deichmanske bibliotek]: http://deichman.no
  [Goliath]: https://github.com/postrank-labs/goliath/
  
    
