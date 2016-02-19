require 'rbtree'
require 'httparty'
require 'zlib'

class DHTNode
  attr_reader :setup_complete
  attr_accessor :response
  KEY_SPACE = 500

  #       0
  #     /¯^¯\
  # 375|<   >| 125  each key maps to predecessor in keyspace
  #     \_v_/       e.g., if a node lives at 375
  #      250              then 378 => node(375)

  def initialize
    @store = {}
    @setup_complete = false
  end

  def finish_setup!(request)
    @address = "#{request.host}:#{request.port}"
    @peers = RBTree[hash(@address), @address] # keep track of keyspace in a Red-Black tree
    @setup_complete = true
  end

  def get_all_keys_in_network
    keys = {}
    @peers.each do |_, peer_address|
      next if peer_address == @address

      uri = "http://#{peer_address}/db"
      peer_keys = HTTParty.get(uri).body.strip!
      keys[peer_address] = peer_keys.split("\r\n") unless peer_keys.empty?
    end
    keys[@address] = @store.keys

    @response.write(keys.inspect)
    @response.status = 200
    close_response!
  end

  def get_val(key:)
    routing_address = predecessor(key)[1]
    if routing_address == @address
      val = @store[key]
    else
      val = route_to_node!(routing_address, :get, key: key)
    end

    if val.nil?
      @response.write("Key not found.")
      @response.status = 404
    else
      @response.write(val)
      @response.status = 200
    end
    close_response!
  end

  def get_local_keys
    @response.write(@store.keys.join("\r\n"))
    @response.status = 200
    close_response!
  end

  def get_peers
    @response.write(@peers.to_a.map(&:first).join("\r\n"))
    @response.status = 200
    close_response!
  end

  def set!(key:, val:)
    routing_address = predecessor(key)[1]
    if routing_address == @address
      old_val = @store[key]
      @store[key] = val
    else
      old_val = route_to_node!(routing_address, :set, key: key, val: val)
    end

    @response.write("#{key} => #{val}")
    @response.status = old_val.nil? ? 200 : 201
    close_response!
  end

  def delete!(key:)
    routing_address = predecessor(key)[1]

    if routing_address == @address
      val = @store.delete(key)
    else
      val = route_to_node!(routing_address, :delete, key: key)
    end

    if val.nil?
      @response.write("Key not found.")
      @response.status = 404
      close_response!
    else
      @response.write("Key #{key} => #{val} deleted.")
      @response.status = 200
      close_response!
    end
  end

  def initialize_network!(peers_list:)
    add_to_peers_list!(peers_list: peers_list, initialize_all: true)

    initialize_debug_pairs! # TODO: remove this debug setup

    @response.write("Network list initialized.")
    @response.status = 201
    close_response!
  end

  def join_network!(peers_list:)
    add_to_peers_list!(peers_list: peers_list)
    inform_peers!(:joined)
    get_keys_from_keyspace!

    @response.write("Network list initialized, current peers informed, and keys retrieved.")
    @response.status = 201
    close_response!
  end

  def leave_network!
    inform_peers!(:departed)

    @response.write("Left network.")
    @response.status = 200
    close_response!
  end

  def add_peers!(peers_list:)
    add_to_peers_list!(peers_list: peers_list)

    @response.write("Peer(s) added.")
    @response.status = 201
    close_response!
  end

  def remove_peer!(peer:)
    peer_hash = hash(peer)
    if @peers.has_key?(peer_hash)
      if predecessor(peer_hash)[1] == @address
        get_keys_from_keyspace!
      end

      @peers.delete(peer_hash)
      @response.write("Peer removed.")
      @response.status = 200
    else
      @response.write("Peer is not in network.")
      @response.status = 404
    end
    close_response!
  end

  def get_keyspace(lower_bound:, upper_bound:) # returns a chunk of the keyspace
    # this has to be O(n) in the number of keys in this node because we have to hash all of them to search the range of the keyspace
    # unless we store them in a BST?
    # maybe we keep both a BST and a hash table for O(lg n) insert and delete, O(1) get, and O(lg n + r) for return range?
    key_subspace = []
    @store.each do |k, v|
      if lower_bound < upper_bound
        if hash(k).between?(lower_bound, upper_bound)
          key_subspace << [k, v]
        end
      else # wraps around
        if hash(k).between?(lower_bound, KEY_SPACE) || hash(k).between(0, upper_bound)
          key_subspace << [k, v]
        end
      end
    end

    @response.write(key_subspace.map { |pair| pair.join("=") }.join("&"))
    @response.status = 200
    close_response!
  end

  def debug
    debugger
  end

  private

  def get_keys_from_keyspace! # if a peer is added, it must ask its preceding peer for the furthest chunk of its keyspace
    preceding_peer, succeeding_peer = predecessor(@address), successor(@address)
    upper_bound = succeeding_peer[0]
    lower_bound = hash(@address)
    uri = "http://#{preceding_peer[1]}/dht/keyspace" +
          "?lower_bound=#{lower_bound}&upper_bound=#{upper_bound}"
    pairs = HTTParty.get(uri).body.strip.split("&").map! { |pair| pair.split("=") }
    pairs.each { |k, v| @store[k] = v }
  end

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

    # puts "Routing to: #{routing_address} so I can: #{method}"

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
        uri = "http://#{peer_address}/dht/peers/#{@address}"
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

  def predecessor(key)
    @peers.upper_bound(hash(key) - 1) || @peers.last # wrap back around if no preceding peer
  end

  def successor(key)
    @peers.lower_bound(hash(key) + 1) || @peers.first
  end

  def hash(key)
    Zlib.crc32(key) % KEY_SPACE
  end

  def close_response!
    @response.write("\n")
    @response.finish
  end

  def initialize_debug_pairs!
    [
      "hello world",
      "loony tunes",
      "baby girl",
      "roller coaster",
      "flip kick",
      "santa claus",
      "turkey trot",
      "wise words",
      "killer whale",
      "ninja turtle",
      "real talk",
      "planned parenthood",
      "flight simulator",
      "mind reader",
      "tarot card",
      "leather couch",
      "finish line",
      "circus act",
      "clown around",
      "sand dune"
    ].map(&:split).each { |k, v| set!(key: k, val: v) }

    @response = Rack::Response.new
  end
end
