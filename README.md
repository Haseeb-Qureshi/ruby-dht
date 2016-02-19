# Distributed Hash Table in Ruby

The purpose of this project is to implement a distributed hash table, using
local independently running HTTP servers. The code will be implemented entirely
in Ruby.

# TODO
* Add replication factor (predecessor & successor?)
  * Need special endpoint for this?
* Subdivide key space into smaller chunks to minimize variance?
  * Append each node 5 times to give smaller sub-slices
  * "#{node}#{i}" from 0-4?
* Add finger tables (how? Need a central coordinator for finger table queries?)
* How to deal with race conditions and request failures?
* Quorums? Eventual consistency?
* Periodically ping peers to detect failed nodes?
  * Reshuffle keys
* Add auth token for private API endpoints
