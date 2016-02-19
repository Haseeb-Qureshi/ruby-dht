require 'rack'
require 'rack/server'
require 'pp'
require 'byebug'
require_relative 'node'

class DHTServer
  DB_KEY_REGEX = /\/db\/(.+)/

  def initialize
    @node = DHTNode.new
  end

  def call(env)
    request = Rack::Request.new(env)
    @node.setup!(request) unless @node.setup_complete
    params = request.params
    method = request.request_method
    body = request.body.read
    path = request.path

    case

    when method == "GET"

      if path == "/"
        self.class.say_hello(request)
      elsif path == "/db"
        @node.get_local_keys
      elsif path =~ DB_KEY_REGEX
        @node.get_val(key: path.scan(DB_KEY_REGEX)[0][0])
      elsif path == "/dht/peers"
        @node.get_peers
      elsif path == "/dht/leave"
        @node.leave_network!
      elsif path == "/debug"
        @node.debug
      else
        self.class.bad_response
      end

    when method == "PUT"

      if path =~ DB_KEY_REGEX
        @node.set!(key: path.scan(DB_KEY_REGEX)[0][0], val: body)
      else
        self.class.bad_response
      end

    when method == "DELETE"

      if path =~ DB_KEY_REGEX
        @node.delete!(key: path.scan(DB_KEY_REGEX)[0][0])
      elsif path =~ /\/dht\/remove_peer\/(.+)/ # TODO: add auth token in header
        peer_address = path.scan(/\/dht\/remove_peer\/(.+)/)[0][0]
        @node.remove_peer!(peer_hash: peer_hash)
      else
        self.class.bad_response
      end

    when method == "POST"

      if path == "/dht/join"
        @node.initialize_network!(network_list: body)
      elsif path == "/dht/peers" # TODO: add auth token in header
        @node.add_peer!(peer_address: body)
      else
        self.class.bad_response
      end

    else
      self.class.bad_response
    end
  end

  def self.bad_response
    response = Rack::Response.new
    response.write("Sorry, your request was not properly formed.\n")
    response.status = 400
    response.finish
  end

  def self.say_hello(request)
    response = Rack::Response.new
    response.write(<<-STR)
      Hi there! Welcome to my DHT server. Here's how the public API works:

      get_local_keys: => GET '#{request.host}:#{request.port}/db'
      get_val => GET '#{request.host}:#{request.port}/db/\#{key}'

      set => PUT '#{request.host}:#{request.port}/db/\#{key}', body => \#{val}
      delete_key => DELETE '#{request.host}:#{request.port}/db/\#{key}'

      peer_list => GET '#{request.host}:#{request.port}/dht/peers'

      join_dht => POST '#{request.host}:#{request.port}/dht/join', body => host1:port1&&host2:port2&&host3:port3
      leave_dht => GET '#{request.host}:#{request.port}/dht/leave'\n
    STR
    response.status = 200
    response.finish
  end
end

# "localhost:8000\r\nlocalhost:8001"

port_offset = 0
begin
  Rack::Server.start(app: DHTServer.new, Port: 8000 + port_offset)
rescue RuntimeError => e
  puts "Port #{8000 + port_offset} taken. Trying again."
  port_offset += 1
  retry
end
