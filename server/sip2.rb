require "socket"
require "time"

SIP2 = YAML::load(File.open("config/sip2.yml"))

class DGClient
  def initialize()
    @host, @port = SIP2['server'], SIP2['port']
  end

  def send_message(msg)
    connection do |socket|
      socket.puts(msg)
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

def appendChecksum(msg)
  check = 0
  msg.each_char { |m| check += m.ord }
  check += "\0".ord
  check = (check ^ 0xFFFF) + 1

  checksum = "%4.4X" % check
  return msg + checksum
end

def formMessage(cardnr, pin)
  code = "63"
  language = "012"
  timestamp = Time.now.strftime("%Y%m%d    %H%M%S")
  summary = " " * 10
  msg = code + language + timestamp + summary + "AO|AA" + cardnr + "|AC|AD" + pin + "|AY1AZ"
  return msg
end