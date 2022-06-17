require 'json'
require_relative 'masaki-pg'
require_relative 'deck-detail'

$deck = MasakiPG::KVS.new('deck')
def main
  MasakiPG::instance.kvs_frozen_world("deck")
  frozen = MasakiPG::KVS.frozen('deck')

  city = JSON.parse(File.read("data/city-deck.json"))
  city.each {|name, date|
    next if frozen.include?(name) || $deck.include?(name)
    p name
    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    $deck[name] = v.to_json
  }
  # puts(URI.open('https://hamana.herokuapp.com/ping/').read)
end

if __FILE__ == $0
  main
end