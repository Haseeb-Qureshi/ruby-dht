class DHTNode
  attr_accessor :uid

  def initialize
    @store = { "default" => "this is a default value", "default2" => "ditto" }
    @uid = nil # gets assigned on first request
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
    response.write(val.to_s + "\n")
    response.status = 200

    response.finish
  end

  def get_all_keys
    response = Rack::Response.new
    response.write(@store.keys.to_s + "\n")
    response.status = 200

    response.finish
  end

  def get_peers
  end

  def leave_network!
  end

  def set!(key:, val:)
    old_val = @store[key]
    @store[key] = val
    response = Rack::Response.new
    response.write("#{key} => #{val}\n")
    response.status = old_val.nil? ? 201 : 200

    response.finish
  end

  def delete!(key:)
    val = @store.delete(key)
    response = Rack::Response.new
    if val.nil?
      response.write("Key not found.\n")
      response.status = 404
      response.finish
    else
      response.write("Key #{key} => #{val} deleted.\n")
      response.status = 200
      response.finish
    end
  end

  def join_network!(network_list:)
  end

  def say_hello(request)

  end


end
