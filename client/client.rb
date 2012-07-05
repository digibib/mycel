#    HOW A CLIENT CONNECTS WITH SERVER
# 1. Fetch MAC-address (HWaddr) from client. This is what identifies the client. Each
#    MAC-address should correspond to a client row in the db on server.
# 2. Send this identificator to Server => gets back client name, and its place in the
#    hierarchy (department).
# 3. Prompt for username and password (Library card number and personal PIN-code)
# 4. Validate using the SIP2-protocol. If not valid, show error message and go back to #3
# 5. Send userID to server with request to log in
# 6. If user has not exceeded the daily time limit, or is otherwise blocked, the
#    request to log on is granted
# 7. After sucessfull logon, a small window stating the users name, number of minutes left,
#    name of the client, together with a "logg out" button shows up and stays on top of session.
# 8. Session is valid until user logs out, or is forced to log out when the time limit is
#    reached. User is warned 5 minutes before the time is up.
# 9. After logout, got back to #3


# NOTE: The following method of getting the MAC-adress works on debian-based
#       linux, but I'm not sure it works whith every system.
#       This fetches address of eth0; make sure to fetch the right eth (or wlan)
#       if the client has several network connections
client_address = %x[cat '/sys/class/net/eth0/address'].strip

if not client_address
  puts "Fatal error: Could not retreive MAC-address of client."
  puts "This is needed for identifying the client." 
  exit 0
end

puts client_address