require 'drb'
require 'rinda/tuplespace'

$ts = Rinda::TupleSpace.new

known = Time.at(1)
DRb.start_service('druby://localhost:12345', $ts)
_, at, json = $ts.take(['city-deck-date.json', Range.new(known, nil), nil])

File.write('city-deck-date.json', json)
