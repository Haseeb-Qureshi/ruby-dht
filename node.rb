require 'rbtree'
require 'httparty'
require 'zlib'

class DHTNode
  attr_reader :setup_complete
  attr_accessor :response
  KEY_SPACE = 500

  #       0
  #     /¯^¯\
  # 375|<   >| 125
  #     \_v_/
  #      250

  def initialize
    @store = {}
    @setup_complete = false
  end

  def setup!(request)
    @address ||= "#{request.host}:#{request.port}"
    @peers = RBTree[hash(@address), @address] # keep track of all peers in a Red-Black Tree
    @setup_complete = true
  end

  def get_all_keys_in_network
    keys = []
    @peers.each do |_, peer_address|
      uri = "http://#{peer_address}/db"
      keys << HTTParty.get(uri).strip.split("\r\n")
    end
    keys << @store.keys

    @response.write(keys.flatten!)
    @response.status = 200
    @response.finish
  end

  def get_val(key:)
    routing_address = closest_peer(key)[1]
    if routing_address == @address
      val = @store[key]
    else
      val = route_to_node!(routing_address, :get, key: key)
    end

    @response.write(val.to_s + "\n")
    @response.status = 200
    @response.finish
  end

  def get_local_keys
    @response.write(@store.keys.join("\r\n") + "\n")
    @response.status = 200
    @response.finish
  end

  def get_peers
    @response.write(@peers.to_a.map(&:first).join("\r\n") + "\n")
    @response.status = 200
    @response.finish
  end

  def set!(key:, val:)
    routing_address = closest_peer(key)[1]
    if routing_address == @address
      old_val = @store[key]
      @store[key] = val
    else
      old_val = route_to_node!(routing_address, :set, key: key, val: val)
    end

    @response.write("#{key} => #{val}\n")
    @response.status = old_val.nil? ? 200 : 201
    @response.finish
  end

  def delete!(key:)
    routing_address = closest_peer(key)[1]

    if routing_address == @address
      val = @store.delete(key)
    else
      val = route_to_node!(routing_address, :delete, key: key)
    end

    if val.nil?
      @response.write("Key not found.\n")
      @response.status = 404
      @response.finish
    else
      @response.write("Key #{key} => #{val} deleted.\n")
      @response.status = 200
      @response.finish
    end
  end

  def initialize_network!(peers_list:)
    add_to_peers_list!(peers_list: peers_list, initialize_all: true)

    @response.write("Network list initialized.\n")
    @response.status = 201
    @response.finish
  end

  def join_network!(peers_list:)
    add_to_peers_list!(peers_list: peers_list)
    inform_peers!(:joined)

    @response.write("Network list initialized and current peers informed.\n")
    @response.status = 201
    @response.finish
  end

  def leave_network!
    inform_peers!(:departed)

    @response.write("Left network.\n")
    @response.status = 200
    @response.finish
  end

  def add_peers!(peers_list:)
    add_to_peers_list!(peers_list: peers_list)

    @response.write("Peer(s) added.\n")
    @response.status = 201
    @response.finish
  end

  def remove_peer!(peer_hash:)
    if @peers.has_key?(peer_hash)
      @peers.delete(peer_hash)
      @response.write("Peer removed.\n")
      @response.status = 200
      @response.finish
    else
      @response.write("Peer is not in network.\n")
      @response.status = 404
      @response.finish
    end
  end

  def get_keyspace
    raise "Not yet implemented" # if a peer is added, it must receive its chunk of the preceding keyspace
  end

  def give_keyspace
    raise "Not yet implemented"
  end

  def debug
    debugger
  end

  private

  def add_to_peers_list!(peers_list:, initialize_all: false)
    self.class.parse_peer_list(peers_list).each do |peer_address|
      next if peer_address == @address
      initialize_peers_network!(peer_address, peers_list) if initialize_all

      raise "Hash collision? or already initialized?" if @peers.has_key?(hash(peer_address))
      @peers[hash(peer_address)] = peer_address
    end
  end

  def route_to_node!(routing_address, method, options)
    raise "Tried to route to self!" if routing_address == @address

    puts "Routing to: #{routing_address} so I can: #{method}"

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

    @peers.each do |_, peer_address|
      next if peer_address == @address
      fn.call(peer_address)
    end
  end

  def initialize_peers_network!(peer_address, peers_list)
    raise "Initializing self!" if peer_address == @address
    uri = "http://#{peer_address}/dht/peers"
    HTTParty.post(uri, body: peers_list)
  end

  def self.parse_peer_list(peers_list)
    peers_list.split("&&")
  end

  def closest_peer(key)
    @peers.upper_bound(hash(key)) || @peers.last # wrap back around if no preceding peer
  end

  def hash(key)
    Zlib.crc32(key) % KEY_SPACE # Ruby's Object#hash uses Murmurhash, outputs integers
  end
end
