require_relative 'ptclist'
require_relative 'store-card_page'
require 'open-uri'

class CardDetail
  def initialize(wait_time=0.1..1.0)
    @kvs = Masaki::CardPage
    @wait_time = wait_time
  end

  def [](key)
    it = @kvs[key]
    unless it
      it = fetch_card_page(key)
      @kvs[key] = it
    end
    it
  end

  def reload(key)
    it = fetch_card_page(key)
    @kvs[key] = it
  end

  def fetch_card_page(key)
    sleep(rand(@wait_time))
    name = "https://www.pokemon-card.com/card-search/details.php/card/#{key}"
    URI.open(name) do |x|
      raise("not found") unless x.base_uri.to_s == name
      return x.read
    end
  rescue OpenURI::HTTPError
    p [:retry_open_uri, key]
    sleep 5
    retry
  end

  KindErrata = {
    38237 => "特殊エネルギー",
    38238 => "特殊エネルギー",
    38229 => "グッズ",
    37998 => "ポケモンのどうぐ"
  }

  def card_kind(key)
    body = self[key]
    ary = ParseRawCard.section(body)
    KindErrata[key] || ParseRawCard.card_kind(ary)
  end
end

module ParseRawCard
  module_function
  def section(text)
    if /\<section class=\"Section\"\>(.*?)\<\/section\>/m =~ text
      it = $1
      a = it.gsub(/\<h2 class=\"mt20\"\>進化.*\z/m, '')
      a = reg(a)
      return remove_tag(a)
    end
  end

  def reg(text)
    text.gsub(/\<img .* class=\"img-regulation\" alt=\"(.+?)\" \/\>/, '[\1]')
  end

  def icon(text)
    text.gsub(/\<span class=\"icon\-(.+?) icon\"\>\<\/span\>/, '[\1]')
  end

  def remove_tag(text)
    icon(text).gsub(/\&nbsp\;/, ' ').gsub(/\&amp\;/, '&').split(/\s*\<.+?\>\s*/).reject {|x| /\A\s*\z/ =~ x}
  end

  def drop_head_pokemon(ary)
    start_with = ["たね", "1 進化", "2 進化", "復元", "M進化", "BREAK進化", "レベルアップ", "VMAX", "伝説", "V-UNION", "V進化"]
    ary.each_with_index do |o, i|
      return ary[i .. -1] if start_with.include?(o)
    end
    raise "invalid card #{ary.inspect}"
  end
  # %w(スタジアム サポート グッズ トレーナー ポケモンのどうぐ 特殊エネルギー 基本エネルギー)

  def card_kind(ary)
    pokemon = ["たね", "1 進化", "2 進化", "復元", "M進化", "BREAK進化", "レベルアップ", "VMAX", "伝説", "V進化"]
    start_with = %w(スタジアム サポート グッズ トレーナー ポケモンのどうぐ 特殊エネルギー 基本エネルギー)
    ary.find do |x|
      return x if start_with.include?(x)
      return x if pokemon.include?(x)
    end
    raise "invalid card"
  end
end

if __FILE__ == $0
detail = CardDetail.new
errata = {}
kvs = MasakiPG::KVS.new('card_page')
list = PTCList.new('pokemon', 'XY').map do |hash|
  name = hash['cardNameAltText'].gsub(/\&amp\;/, '&')
  name = errata[name] || name
  pair =  [name, hash['cardID'].to_i]
  # pp detail[hash['cardID'].to_i]
  body = detail[pair[1]]
  ary = ParseRawCard.section(body)
  ary = ParseRawCard.drop_head_pokemon(ary)

  [pair.first, ary, pair.last]
end

last = []
result = list.sort.map { |name, desc, card_id|
  if last[0..1] == [name, desc]
    [card_id, nil, last[2]]
  else
    last = [name, desc, card_id]
    [card_id, desc, name]
  end
}

pp result.map {|a,b,c|[a,c]}

end