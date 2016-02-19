# Distributed Hash Table in Ruby

The purpose of this project is to implement a distributed hash table, using
local independently running HTTP servers. The code will be implemented entirely
in Ruby.

# TODO
* Add replication factor (predecessor & successor?)
  * Need special endpoint for this?
* Add finger tables (how? Need a central coordinator for finger table queries?)
* How to deal with race conditions and request failures?
* Quorums? Eventual consistency?
* Periodically ping peers to detect failed nodes?
  * Reshuffle keys
