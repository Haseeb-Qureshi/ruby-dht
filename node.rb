require 'rack'
require 'rack/server'
require 'pp'
require 'byebug'

class DHTNode
  DB_KEY_REGEX = /\/db\/(.+)/

  def initialize
    @store = { "default" => "this is a default value", "default2" => "ditto" }
    @uid = nil
  end

  def call(env)
    request = Rack::Request.new(env)
    @uid ||= "#{request.host}#{request.port}"
    params = request.params
    method = request.request_method
    body = request.body
    path = request.path

    case

    when method == "GET"

      if path == "/"
        say_hello(request)
      elsif path == "/db"
        get_all_keys
      elsif path =~ DB_KEY_REGEX
        get_val(key: path.scan(DB_KEY_REGEX)[0][0])
      elsif path == "/dht/peers"
        get_peers
      elsif path == "/dht/leave"
        leave_network!
      else
        bad_response
      end

    when method == "PUT"

      if path =~ DB_KEY_REGEX
        set!(key: path.scan(DB_KEY_REGEX)[0][0], val: body)
      else
        bad_response
      end

    when method == "DELETE"

      if path =~ DB_KEY_REGEX
        delete!(key: path.scan(DB_KEY_REGEX)[0][0])
      else
        bad_response
      end

    when method == "POST"

      if path == "/dht/join"
        join_network!(network_list: body)
      else
        bad_response
      end

    else
      bad_response
    end
  end

  # API:
  # get_all_keys: => GET 'localhost:3000/db'
  # get_val => GET 'localhost:3000/db/#{key}'
  # peer_list => GET 'localhost:3000/dht/peers'
  # leave_dht => GET 'localhost:3000/dht/leave'

  # set => PUT 'localhost:3000/db/#{key}', body => #{val}


  # delete_key => DELETE 'localhost:3000/db/#{key}'


  # join_dht => POST 'localhost:3000/dht/join', body => name1:host1:port1 \r\n name2:host2:port2 \r\n name3:host3:port3

  def get_val(key:)
    val = @store[key]
    response = Rack::Response.new
    response.write(val)
    response.status = 200

    response.finish
  end

  def get_all_keys
    response = Rack::Response.new
    response.write(@store.keys)
    response.status = 200

    response.finish
  end

  def get_peers
  end

  def leave_network!
  end

  def set!(key:, val:)
  end

  def delete!(key:)
  end

  def join_network!(network_list:)
  end

  def say_hello(request)
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

  def bad_response
    response = Rack::Response.new
    response.write("Sorry, your request was not properly formed.")
    response.status = 400
    response.finish
  end
end

Rack::Server.start(app: DHTNode.new)
