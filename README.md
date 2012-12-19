# Mycel
Mycel is a client/server network system for monitoring and administering publicly available computers. It is currently being developed for use at the Oslo Public Library ([Deichmanske bibliotek]).

The clients are intended to be used library patrons, who log on using their library card number and personal code. Guest users can also be allowed if clients are configured so.

###License
GPLv3

## Architecture
![Mycel architecture](https://github.com/digibib/mycel/raw/master/docs/architecture.png)
###Server
The server is composed of two [Goliath] processes:

1. A websocket server handling log on/off requests from the clients, adjusting the time spent by users, as well as broadcasting this information to the clients and web administration interface.

2. An API server implemented using [Grape], exposing the database via a REST/JSON. This process is also serving the HTML views. The API is used by the web interface to store and retrieve configuration settings. It is also used to identify the clients and authenticate users before they connect to the WebSocket server.

###Database
The database keeps track of how the library is organized hierarchicaly in branches, departments and clients, as well as users and which user is logged on to which client. The options are configurable on all levels (organization -> branch -> department -> client). If a given setting is not set, it is inherited from the parent level in the hierarchy.

####Model
A simplified overview of the models:
![Mycel architecture](https://github.com/digibib/mycel/raw/master/docs/db_model.png)

Although we have aimed at a generic design, the system _is_ tailored for the Oslo public library, and might not be a perfect fit for your organization. If you are considering to use Mycel, please carefully study the model and [database schema](https://github.com/digibib/mycel/raw/master/docs/db_schema.pdf) to see if it can support all your configuration needs. You may, for example, require additional options, so modify the schema and models accordingly.

The user table is reset every night, and only anonymized information about patron usage is stored in logfiles for statistical purposes.

###Clients
The clients consist of a simple websocket-client to connect to the server, and a GTK-based GUI to show user login information.

## Installation and setup
The system can be a bit challenging to set up, especially for those with litle Linux sysadmin experience. The trickiest part is probaby network configuration and setup and distribution of the live client images. This topic will be adressed in our Wiki.

Do not hesitate to get in touch if your library wants to try out Mycel and need guidance!

###Database
Mycel is written and tested with MySQL. To compile the mysql2 gem you will need the development headers:

```sudo apt-get install libmysqlclient-dev```

If you want to use a different database, it's vital that you choose one with asynchronous drivers. PostgreSQL is also known to work with Goliath using the [em_postgresql] adapter.

### Server
*Note:* We currently have some unresolved bugs related to fibers, probably in one of the dependencies, leadning to failures (Stack overflow) in Ruby 1.9.3. Until we manage to resolve this, Ruby version 1.9.2 must be used on the serverside,

To get it up running, simply do a bundle install and, start and deamonize the 2 server processes:

```ruby server.rb -d -e prod -l logs/api.log -p 9001```

```ruby api_server.rb -d -e prod -l logs/production.log -p 9000```


**Server configuration**

Most of the options can be configured in the web-based administration interface. The remaining settings (SIP2 server address and so on) can be found in `config/mycel.yml`

To make the application ready for production, run `rake setup`. This will 1) seed the database with `db/seed.yml`, 2) prepare the template views with production hostname and port, and 3) set up logrotation.

#### Cronjobs
You need to set up a cronjob to remove all users.Create a file `/etc/cron.d/mycel`, and paste in the following, substituting USER and PATH to suit your environment:

```
0 0 * * * {USER} /bin/bash -l -c 'source /home/{USER}/.rvm/environments/ruby-1.9.2-p320 && cd /{PATH/TO}/mycel/server && bundle exec rake delete_users --silent >> logs/cron.log 2>&1'
```

It will log number of users deleted to `mycel/server/logs/cron.log`

Another cron is set up to log the opening hours for all departments. This is needed for generating better and more acurate statistics. In paritciluar it's needed for calculating the utilization level of the clients on any given day.

```
0 0 * * * {USER} /bin/bash -l -c 'source /home/{USER}/.rvm/environments/ruby-1.9.2-p320 && cd /{PATH/TO}/mycel/server && bundle exec rake log_hours --silent >> logs/hours.log 2>&1'
```


If the cronjobs doesn't get executed, check your `/var/log/syslog` for hints on what could be wrong. In particular, you may need to comment out the following line from your `~/.bashrc` file:

    [  -z "$PS1" ] && return

### Clients
Mycel is being developed and tested on clients running lubuntu 11.10 and 12.04, but any system capable of running GTK-based applications should work.

The client is a compiled executable written in Go. For installation instruction see the [mycel-client repository](https://github.com/digibib/mycel-client).

#### Notes
The client is identified by sending by sending the mac-adress to the API. The mac adress is obtained using the following command:

```cat /sys/class/net/eth0/address```

It should work on all *nix systems, but note that this fetches address of eth0; so make sure to fetch the correct eth (or wlan) if the client has several network connections.

## Statistics

### Logging
I am working on scripts to generate usefull statistics automatically for each department and branch, as well as (global) overall statistics and graphs of trends and use.

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
* Generate statistics (20h)
* Allow adding branches/departments/clients in web interface (15h)
* Documentation, especially installation and setup (5h)

  [Deichmanske bibliotek]: http://deichman.no
  [Goliath]: https://github.com/postrank-labs/goliath/
  [Grape]: https://github.com/intridea/grape
  [em_postgresql]: https://github.com/mperham/em_postgresql
