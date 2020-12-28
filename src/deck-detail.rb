require 'open-uri'
require_relative 'masaki-pg'

module DeckDetail
  module_function
  def parse(text)
    it = do_parse(text)
  end

  def item_parse(item)
    item.split('-').collect {|x| x.split('_')[0,2].map {|x| Integer(x)}}
  end
  
  def do_parse(text)
    return nil unless /\<form id=\"inputArea\" action=\"\.\/deckRegister\.php\"\>(.+?)\<\/form\>/m =~ text
    deck = $1
    if /id=\"deck_pke\" value=\"(.*?)\"/ =~ deck
      pokemon = item_parse($1)
    end
    if /id=\"deck_gds\" value=\"(.*?)\"/ =~ deck
      goods = item_parse($1)
    end
    if /id=\"deck_sup\" value=\"(.*?)\"/ =~ deck
      support = item_parse($1)
    end
    if /id=\"deck_sta\" value=\"(.*?)\"/ =~ deck
      stadium = item_parse($1)
    end
    if /id=\"deck_ene\" value=\"(.*?)\"/ =~ deck
      energy = item_parse($1)
    end
    pokemon + goods + support + stadium + energy
  end

  def fetch_deck_page(key)
    name = "https://www.pokemon-card.com/deck/confirm.html/deckID/#{key}/"
    URI.open(name) do |x|
      raise("not found") unless x.base_uri.to_s == name
      return x.read
    end
  end

  def guess_deck_name(str)
    if /(\W|\A)(\w{6}\-\w{6}\-\w{6})(\W|\Z)/ =~ str
      return $2
    end
  end

  def make_url(key)
    [
      "https://www.pokemon-card.com/deck/confirm.html/deckID/#{key}/",
      "https://www.pokemon-card.com/deck/deckView.php/deckID/#{key}.png",
      MasakiPG::instance.referer_tw_link(key)
    ]
  end
end

if __FILE__ == $0
  require 'pp'
  require_relative 'masaki-pg'

  keys = JSON.parse(File.read(ARGV.shift))

  $world = MasakiPG::KVS.new('world')
  $deck = MasakiPG::KVS.new('deck')

  base = JSON.parse($world['deck'])
  keys.each {|name|
    next if base.include?(name) || $deck.include?(name)
    p name
    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    $deck[name] = v.to_json
  }
end
