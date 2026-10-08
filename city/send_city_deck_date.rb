require 'drb'
require 'rinda/tuplespace'

ro = DRbObject.new_with_uri('druby://localhost:12345')

fname = 'city-deck-date.json'
ro.write([fname, File.mtime(fname), File.read(fname)])
