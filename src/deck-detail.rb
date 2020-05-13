require 'open-uri'

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
end

if __FILE__ == $0
  require 'pp'
  require_relative 'masaki-pg'

  dest = MasakiPG::KVS.new('deck')

  norm = eval(File.read('../data/derived_norm.txt'))
  keys = eval(File.read('../data/deck_keys.tmp'))
  keys.each do |name|
    if dest.include?(name)
      p [:exist, name]
      next
    end
    p [name]
    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    v = v.map {|card_id, n| [norm[card_id] || card_id, n]}.sort
    v = v.chunk {|e| e[0]}.map {|card_id, g|  [card_id, g.map{|h| h[1]}.sum]}
    dest[name] = v.to_json
  end
end
