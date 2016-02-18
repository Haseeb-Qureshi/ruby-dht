require 'rack'
require 'rack/server'
require 'pp'
require 'byebug'

class DHTNode
  DB_KEY_REGEX = /\/db\/(.+)/

  def call(env)
    request = Rack::Request.new(env)
    @uid ||= "#{request.hostname}#{request.port}"
    # params = request.params
    method = request.request_method
    body = request.body
    path = request.path

    case
    when method == "GET"
      if path == "/db"
        get_all_keys
      elsif path =~ DB_KEY_REGEX
        get_key(key: path.scan(DB_KEY_REGEX))
      elsif path == "/dht/peers"
        get_peers
      elsif path == "/dht/leave"
        leave_network!
      else
        bad_response
      end
    when method == "PUT"
      if path =~ DB_KEY_REGEX
        set!(key: path.scan(DB_KEY_REGEX), val: body)
      else
        bad_response
      end
    when method == "DELETE"
      if path =~ DB_KEY_REGEX
        delete!(key: path.scan(DB_KEY_REGEX))
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

  def get_key(key:)
    response = Rack::Response.new
    response.write('Hello World') # write some content to the body
    response.status = 202

    response.finish # return the generated triplet
  end

  def get_all_keys
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

  def bad_response
    response = Rack::Response.new
    response.write("Sorry, your request was not properly formed.")
    response.status = 400
    response.finish
  end
end

Rack::Server.start(app: DHTNode.new)
