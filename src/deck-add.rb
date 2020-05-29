require 'twitter_oauth'
require 'net/http'
require 'uri'
require 'date'
require_relative 'masaki-pg'
require_relative 'deck-detail'

$deck = MasakiPG::KVS.new('deck')

if __FILE__ == $0
  norm = eval(File.read('../data/derived_norm.txt'))
  while name = ARGV.shift
    next if $deck.include?(name)

    p name

    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    v = v.map {|card_id, n| [norm[card_id] || card_id, n]}.sort
    v = v.chunk {|e| e[0]}.map {|card_id, g|  [card_id, g.map{|h| h[1]}.sum]}
    $deck[name] = v.to_json
  end
end