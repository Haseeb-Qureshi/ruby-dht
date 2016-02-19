require 'rbtree'
require 'httparty'

class DHTNode
  attr_reader :setup_complete
  KEY_SPACE = 40

  #       0
  #     /¯^¯\
  # 30 |<   >| 10
  #     \_v_/
  #      20

  def initialize
    @store = {}
    @setup_complete = false
  end

  def setup!(request)
    @address ||= "#{request.host}:#{request.port}"
    @peers = RBTree[hash(@address), @address] # keep track of all peers in a Red-Black Tree
    @setup_complete = true
  end

  # API:
  # get_local_keys: => GET 'localhost:3000/db'
  # get_val => GET 'localhost:3000/db/#{key}'
  # peer_list => GET 'localhost:3000/dht/peers'
  # leave_dht => GET 'localhost:3000/dht/leave'

  # set => PUT 'localhost:3000/db/#{key}', body => #{val}

  # delete_key => DELETE 'localhost:3000/db/#{key}'

  # join_dht => POST 'localhost:3000/dht/join', body => name1:host1:port1 \r\n name2:host2:port2 \r\n name3:host3:port3

  def get_all_in_network
    raise "Not yet implemented"
  end

  def get_val(key:)
    routing_address = closest_peer(key)[1]
    if routing_address == @address
      val = @store[key]
    else
      val = route_to_node!(routing_address, :get, key: key)
    end

    response = Rack::Response.new
    response.write(val.to_s + "\n")
    response.status = 200
    response.finish
  end

  def get_local_keys
    response = Rack::Response.new
    response.write(@store.keys.join("\r\n") + "\n")
    response.status = 200
    response.finish
  end

  def get_peers
    response = Rack::Response.new
    response.write(@peers.to_a.map(&:last).join("\r\n") + "\n")
    response.status = 200
    response.finish
  end

  def set!(key:, val:)
    routing_address = closest_peer(key)[1]
    if routing_address == @address
      old_val = @store[key]
      @store[key] = val
    else
      old_val = route_to_node!(routing_address, :set, key: key, val: val)
    end

    response = Rack::Response.new
    response.write("#{key} => #{val}\n")
    response.status = old_val.nil? ? 200 : 201
    response.finish
  end

  def delete!(key:)
    routing_address = closest_peer(key)[1]

    if routing_address == @address
      val = @store.delete(key)
    else
      val = route_to_node!(routing_address, :delete, key: key)
    end

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

  def initialize_network!(network_list:)
    initialize_peers!(self.class.format_network_list(network_list))
    inform_peers!(:joined)

    response = Rack::Response.new
    response.write("Network list initialized.\n")
    response.status = 201
    response.finish
  end

  def leave_network!
    inform_peers!(:departed)

    response = Rack::Response.new
    response.write("Left network.\n")
    response.status = 200
    response.finish
  end

  def add_peer!(peer_address:)
    initialize_peers!([peer_address])

    response = Rack::Response.new
    response.write("Peer added.\n")
    response.status = 201
    response.finish
  end

  def remove_peer!(peer_hash:)
    response = Rack::Response.new

    if @peers.has_key?(peer_hash)
      @peers.delete(peer_hash)
      response.write("Peer removed.\n")
      response.status = 200
      response.finish
    else
      response.write("Peer is not in network.\n")
      response.status = 404
      response.finish
    end
  end

  def get_keyspace
    raise "Not yet implemented" # if a peer is added, it must receive its chunk of the preceding keyspace
  end

  def debug
    debugger
  end

  private

  def initialize_peers!(peers)
    peers.each do |peer_address|
      next if peer_address == @address
      raise "Hash collision? or already initialized?" if @peers.has_key?(hash(peer_address))
      @peers[hash(peer_address)] = peer_address
    end
  end

  def route_to_node!(routing_address, method, options)
    raise "Tried to route to self!" if routing_address == @address

    key = options[:key]
    key_url = "http://#{routing_address}/db/#{key}"
    case method
    when :get
      HTTParty.get(key_url)
    when :get_all
      HTTPParty.get("http://#{routing_address}/db")
    when :set
      HTTParty.put(key_url, body: options[:val])
    when :delete
      HTTParty.delete(key_url)
    else
      raise "hell"
    end
  end

  def inform_peers!(action)
    if action == :joined
      fn = lambda do |peer_address|
        uri = "http://#{peer_address}/dht/peers"
        HTTParty.post(uri, body: @address)
      end
    elsif action == :departed
      fn = lambda do |peer_address|
        uri = "http://#{peer_address}/dht/peers/#{hash(@address)}"
        HTTParty.delete(uri)
      end
    else
      raise "Invalid action"
    end

    peers.each { |_, peer_address| fn.call(peer_address) }
  end

  def self.format_network_list(network_list)
    network_list.split("&&")
  end

  def closest_peer(key)
    @peers.upper_bound(hash(key)) || @peers.last # wrap back around if no preceding peer
  end

  def hash(key)
    key.hash % KEY_SPACE # .hash uses Murmurhash, outputs integers
  end
end
