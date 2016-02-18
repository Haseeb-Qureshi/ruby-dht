require 'rack'
require 'rack/server'
require 'pp'
require 'byebug'

class DHTNode
  def initialize()
  end

  def call(env)
    request = Rack::Request.new(env)
    params = request.params
    method = request.request_method
    body = request.body
    path = request.path
    # port = request.port


    response = Rack::Response.new
    response.write('Hello World') # write some content to the body
    response.status = 202

    response.finish # return the generated triplet
  end
end

Rack::Server.start(app: DHTNode.new)

# API:
# get_all_keys: => GET 'localhost:3000/db'

# set => PUT 'localhost:3000/db/#{key}', body => #{val}

# get_val => GET 'localhost:3000/db/#{key}'

# delete_key => DELETE 'localhost:3000/db/#{key}'

# peer_list => GET 'localhost:3000/dht/peers'

# join_dht => POST 'localhost:3000/dht/join', body => name1:host1:port1 \r\n name2:host2:port2 \r\n name3:host3:port3

# leave_dht => GET 'localhost:3000/dht/leave'
