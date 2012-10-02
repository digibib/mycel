# Mycel
Mycel is a client/server network system for monitoring and administering publicly available computers. It is currently being developed for use at the Oslo Public Library ([Deichmanske bibliotek]).

The clients are intended to be used library patrons, who log on using their library card number and personal code. Guest users can also be allowed if clients are configured so.

## Architecture
![Mycel architecture](docs/architecture.png)
###Server
The server is composed of two [Goliath] processes:

1. A websocket server handling log on/off requests from the clients, adjusting the time spent by users, as well as broadcasting this information to the clients and web administration interface.

2. An API server implemented using [Grape], exposing the database via a REST/JSON. The API is used by the web interface to store and retrieve configuration settings.

###Database
The database keeps track of how the library is organized hierarchicaly in branches, departments and clients, as well as users and which user is logged on to which client. Most settings are configurable at all levels (organization -> branch -> department -> client). If a given setting is not set, it is inherited from the parent level in the hierarchy.

The user table is reset every day, and only anonymized information is logged for statistical purposes.

###Clients



## Installation Instructions
The system is quite easy to set up. Both server and client are (currently) written in Ruby.

### Database
Mycel is written and tested with MySQL. To compile the mysql2 gem you will need the development headers:

```sudo apt-get install libmysqlclient-dev```

If you want to use a different database, it's vital that you choose one with asynchronous drivers. PostgreSQL is also known to work with Goliath using the em_postgresql adapter.

### Server
The server is written using the asynchronous web server framework [Goliath]. It provides its own server. To get it up running, simply do a bundle install and, start and deamonize the server using:

```ruby server.rb -d -e production -p 9001```

This is the server communicating with the clients via WebSockets. In addition, the API-server is running as a separate process. All updates on you make on clients, users and options in the web interface, are made by calling the API underneath. This server is also responsible for serving the web interface views. Start the API with:

```ruby api_server.rb -d -e production'-p 9000```

Goliath is not tied to any particular Ruby, but recommended is MRI Ruby 1.9.3.

**Server configuration**
Most of the options can be configured in the web-based administration interface. The remaining settings (SIP2 server address and so on) can be found in `config/server.rb`

### Clients
Mycel is being developed and tested on clients running lubuntu 11.10 and 12.04, but any system capable of running GTK-based applications should work.

The client is written in Ruby, so obviously you should have Ruby installed. Development is done on version 1.9.3. Simply run bundle install and the client should be good to go. You may have to install some development headers in order to compile the gtk2-gem. On Debian-based systems you can try

```sudo apt-get install libgtk2.0-dev```

Note: when I got the system stable and running, I plan to rewrite the client in a compiled language like C or Go. At our Library most clients are thin clients with Linux images loaded in RAM at start up, and we therefore want the images to be as small and efficient as possible.

## Technical Documentation
Kommer etterhvert...



**What happens when the socket connection is lost?**

**Troubleshooting**


  [Deichmanske bibliotek]: http://deichman.no
  [Goliath]: https://github.com/postrank-labs/goliath/
  [Grape]: https://github.com/intridea/grape


