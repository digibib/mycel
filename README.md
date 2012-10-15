# Mycel
Mycel is a client/server network system for monitoring and administering publicly available computers. It is currently being developed for use at the Oslo Public Library ([Deichmanske bibliotek]).

The clients are intended to be used library patrons, who log on using their library card number and personal code. Guest users can also be allowed if clients are configured so.

## Architecture
![Mycel architecture](https://github.com/digibib/mycel/raw/develop/docs/architecture.png)
###Server
The server is composed of two [Goliath] processes:

1. A websocket server handling log on/off requests from the clients, adjusting the time spent by users, as well as broadcasting this information to the clients and web administration interface.

2. An API server implemented using [Grape], exposing the database via a REST/JSON. This process is also serving the HTML views. The API is used by the web interface to store and retrieve configuration settings. It is also used to identify the clients and authenticate users before they connect to the WebSocket server. 

###Database
The database keeps track of how the library is organized hierarchicaly in branches, departments and clients, as well as users and which user is logged on to which client. Most settings are configurable at all levels (organization -> branch -> department -> client). If a given setting is not set, it is inherited from the parent level in the hierarchy.

The user table is reset every day, and only anonymized information is stored for statistical purposes.

###Clients
WRITEME


## Installation and setup
The system is quite easy to set up. Both server and client are (currently) written in Ruby.

### Database
Mycel is written and tested with MySQL. To compile the mysql2 gem you will need the development headers:

```sudo apt-get install libmysqlclient-dev```

If you want to use a different database, it's vital that you choose one with asynchronous drivers. PostgreSQL is also known to work with Goliath using the [em_postgresql] adapter.

### Server
The server is written using the asynchronous web server framework [Goliath]. It provides its own server. To get it up running, simply do a bundle install and, start and deamonize the server using:

```ruby server.rb -d -e production -p 9001```

This is the server communicating with the clients via WebSockets. In addition, the API-server is running as a separate process. All updates on you make on clients, users and options in the web interface, are made by calling the API underneath. This server is also responsible for serving the web interface views. Start the API with:

```ruby api_server.rb -d -e production'-p 9000```

Goliath is not tied to any particular Ruby, but recommended is MRI Ruby 1.9.3.

**Server configuration**
Most of the options can be configured in the web-based administration interface. The remaining settings (SIP2 server address and so on) can be found in `config/mycel.yml`
 
To make the application ready for production, run `rake setup`. This will 1) seed the database with `db/seed.yml`, 2) prepare the template views with production hostname and port, and 3) set up cronjobs.

#### Cronjob troubleshooting
Mycel sets up a cronjob to remove all users at midnight. If the cronjob doesn't get executed, check your `var/log/syslog` for hints on what might be wrong. 

Try to comment out the following line from your `~/.bashrc` file:

```[  -z "$PS1" ] && return``` 

As well as adding the following to `~/.rmvrc`:

```rvm_trust_rvmrcs_flag=1``` 

### Clients
Mycel is being developed and tested on clients running lubuntu 11.10 and 12.04, but any system capable of running GTK-based applications should work.

The client is written in Ruby, so obviously you should have Ruby installed. Development is done on version 1.9.3. Simply run bundle install and the client should be good to go. You may have to install some development headers in order to compile the gtk2-gem. On Debian-based systems you can try

```sudo apt-get install libgtk2.0-dev```

Note: when I got the system stable and running, I plan to rewrite the client in a compiled language like C or Go. At our Library most clients are thin clients with Linux images loaded in RAM at start up, and we therefore want the images to be as small and efficient as possible.

#### Notes
The client is identified by sending by sending the mac-adress to the API. The mac adress is obtained using the following command:

```cat /sys/class/net/eth0/address```

It should work on all *nix systems, but note that this fetches address of eth0; so make sure to fetch the correct eth (or wlan) if the client has several network connections.

## Statistics

### Logging
Logging format:
>[PID:INFO] {DateTimestamp} :: {UserType}, {age}, {logs on|logs_off} : {branch/dept/client[MAC]} 

>[4896:INFO] 2012-10-14 18:47:17 :: LibraryUser, 31, logs on : hovedbiblioteket/voksenavdelingen/hovedklient1[00:01:2e:bc:c8:7d]

>[4896:INFO] 2012-10-14 18:54:09 :: LibraryUser, 11, logs off : hovedbiblioteket/unge deichman/ungeklient2[00:01:2e:bc:c8:7d]

> [4896: INFO] 2012-10-14 19:14:29 :: GuestUser, adult, logs on ....

> [4896: INFO] 2012-10-14 19:14:29 :: AnonymousUser, unknown, logs on ....

## Potential feature enhancements
* Allow booking of clients
* Manage users printer quota
* Realtime chat. If the library has a staffed helpdesk, then users in need of technical help can initiate a chat-session with the staff.


## Remaining TODOs

* Global configuration in web interface (20h)
* Deciding logging format and implementation (10h)
* Admin users and authentication (10h)
* Thorough cross-browser testing (3h)
* Documentation, especially installation and setup (5h)
* Simplify setup, remove harcoded values from application & move all settings to one file, congig/mycel.yml (2h)
* Handling network disconnects, both server and client side (20h)
* Time managment, edge cases in model (5h)
* Store user time in seconds instead of minutes, allowing for more accurate time management. Adjust time every 15 sec. (2h)
* Live testing with remote clients (10h)
* Rewrite the client in a compiled language (30h)


  [Deichmanske bibliotek]: http://deichman.no
  [Goliath]: https://github.com/postrank-labs/goliath/
  [Grape]: https://github.com/intridea/grape
  [em_postgresql]: https://github.com/mperham/em_postgresql


