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
    @node.uid ||= "#{request.host}#{request.port}"
    params = request.params
    method = request.request_method
    body = request.body.read
    path = request.path

    case

    when method == "GET"

      if path == "/"
        self.class.say_hello(request)
      elsif path == "/db"
        @node.get_all_keys
      elsif path =~ DB_KEY_REGEX
        @node.get_val(key: path.scan(DB_KEY_REGEX)[0][0])
      elsif path == "/dht/peers"
        @node.get_peers
      elsif path == "/dht/leave"
        @node.leave_network!
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
      else
        self.class.bad_response
      end

    when method == "POST"

      if path == "/dht/join"
        @node.join_network!(network_list: body)
      else
        self.class.bad_response
      end

    else
      self.class.bad_response
    end
  end

  def self.bad_response
    response = Rack::Response.new
    response.write("Sorry, your request was not properly formed.")
    response.status = 400
    response.finish
  end

  def self.say_hello(request)
    response = Rack::Response.new
    response.write(<<-STR)
      Hi there! Welcome to my DHT server. Here's how the API works:

      get_all_keys: => GET '#{request.host}:#{request.port}/db'
      get_val => GET '#{request.host}:#{request.port}/db/\#{key}'

      set => PUT '#{request.host}:#{request.port}/db/\#{key}', body => \#{val}
      delete_key => DELETE '#{request.host}:#{request.port}/db/\#{key}'

      peer_list => GET '#{request.host}:#{request.port}/dht/peers'

      join_dht => POST '#{request.host}:#{request.port}/dht/join', body => name1:host1:port1 \\r\\n name2:host2:port2 \\r\\n name3:host3:port3
      leave_dht => GET '#{request.host}:#{request.port}/dht/leave'
    STR
    response.status = 200
    response.finish
  end
end

Rack::Server.start(app: DHTServer.new)
