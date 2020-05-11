module DeckParser
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
end

if __FILE__ == $0
  require_relative '../../DDeck/src/ddeck-mysql'
  require_relative 'masaki-pg'
  require 'json'

  norm = eval(File.read('../data/derived_norm.txt'))

  src = DDeckMysql::KVS.new('deck')
  dest = MasakiPG::KVS.new('deck')

  src.each do |k, v|
    v = DeckParser.parse(v)
    v = v.map {|k, n| [norm[k] || k, n]}.sort
    v = v.chunk {|e| e[0]}.map {|f, g|  [f, g.map{|h| h[1]}.sum]}
    dest[k] = v.to_json
  end
end