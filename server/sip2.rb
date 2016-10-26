require "socket"
require "time"
require "./config/settings"

class DGClient
  def initialize()
    @host, @port = Settings::SIP2[:host], Settings::SIP2[:port]
    @user, @pass = Settings::SIP2[:username], Settings::SIP2[:password]
  end

  def send_message(msg)
    connection do |socket|
      socket.print("9300CN#{@user}|CO#{@pass}|CP|\r")
      tmp = socket.gets("\r")
      socket.print(msg)
      result = socket.gets("\r")
      return result
    end
  end

  def connection
    socket = Socket.new Socket::AF_INET, Socket::SOCK_STREAM, 0
    socket.connect Socket.pack_sockaddr_in @port, @host
    yield(socket)
  ensure
    socket.close
  end
end

def formMessage(cardnr, pin)
  code = "63"
  language = "012"
  timestamp = Time.now.strftime("%Y%m%d    %H%M%S")
  summary = " " * 10
  msg = code + language + timestamp + summary + "AO|AA" + cardnr + "|AC|AD" + pin + "|\r"
  return msg
end
