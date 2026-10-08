require 'drb'
require 'rinda/tuplespace'

$ts = Rinda::TupleSpace.new

nsec = 1.quo(1000000000)
fname = 'city-deck-date.json'
known = File.mtime(fname) rescue Time.at(1)
DRb.start_service('druby://localhost:12345', $ts)
_, at, json = $ts.take([fname, Range.new(known + nsec , nil), nil])
File.write(fname, json)
