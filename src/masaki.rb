require_relative 'masaki-pg'
require_relative 'deck-detail'
require 'json'

class Masaki
  def initialize
    @world = MasakiWorld.new
    @recent = @world.recent.map {|k| [k, deck_desc(k)]}
  end
  attr_reader :world

  def do_api(req, res, post)
    case post['method']
    when "search"
      do_search_api(req, res, post)
    when "recent"
      do_recent_api(req, res, post)
    end
  end

  def do_recent_api(req, res, post)
    {
      'recent' => @recent
    }
  end

  def do_search_api(req, res, post)
    str = post["search"]
    name = DeckDetail::guess_deck_name(str)
    return search(name, 5) if name
    card_id = guess_card_id(str)
    return search_by_card(card_id) if card_id
    search_by_name(str)
  end

  def search(deck, n=5)
    ary = @world.search_by_deck(deck, n).map {|s, k|
      diff = @world.diff(deck, k).map {|name, card_no, left_right| [name, card_url(card_no)] + left_right}
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'image' => image,
        'score' => s,
        'name' => k,
        'diff' => diff,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_deck', deck],
      'result' => ary
    }
  end

  def search_by_name(name, n=10)
    ary = @world.search_by_name(name, n).map {|s, k|
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'image' => image,
        'score' => s,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_name', name],
      'result' => ary
    }
  end

  def search_by_card(card_no, n=10)
    ary = @world.search_by_card(card_no, n).map {|s, k|
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'image' => image,
        'score' => s,
        'name' => k,
        'desc' => deck_desc(k)
      }
    }
    {
      'query' => ['search_by_card', card_no],
      'result' => ary
    }
  end

  def add(deck)
    @world.add(deck)
  end

  def card_url(key)
    "https://www.pokemon-card.com/card-search/details.php/card/#{key}"
  end

  def guess_card_id(str)
    if /\/card\-search\/details\.php\/card\/(\d+)/ =~ str
      Integer($1, 10) rescue nil
    elsif /card_images\/.*\/(\d+)\w+\.jpg/ =~ str
      Integer($1, 10) rescue nil
    else
      Integer(str, 10) rescue nil
    end
  end

  def deck_desc(code)
    @world.top_idf(code)[0,5].map {|n| world.name(n)}
  end
end

class MasakiWorld
  def initialize
    trainer = JSON.parse(File.read("data/uniq_energy_trainer_all.txt"))
    pokemon = JSON.parse(File.read("data/uniq_pokemon_all.txt"))
    @name = Hash[trainer + pokemon]
    make_id_norm

    @deck = {}

    frozen = MasakiPG::KVS.frozen('deck')
    frozen.each do |k, v|
      @deck[k] = re_normalize(JSON.parse(v))
    end

    @kvs = MasakiPG::KVS.new('deck')
    @kvs.each do |k, v|
      @deck[k] = re_normalize(JSON.parse(v))
    end

    @recent = @deck.keys.last(10)

    @deck_tmp = {}
    make_index
  end
  attr_reader :deck, :idf, :norm, :recent, :id_latest

  def re_normalize(v)
    v = v.map {|card_id, n| [@id_norm[card_id], n]}.sort
    v.chunk {|e| e[0]}.map {|card_id, g|  [card_id, g.map{|h| h[1]}.sum]}
  end

  def make_id_norm
    @id_norm = Hash.new {|h, k| k}
    @name.each do |k, v|
      next if String === v
      @id_norm[k] = v 
    end

    @id_latest = Hash.new {|h, k| k}
    last = []
    @name.sort_by {|k, v| [@id_norm[k], -k]}.each do |k, v|
      v = @id_norm[k]
      if last[1] != v
        last = [k, v]
      else
        @id_latest[k] = last[0]
      end
    end
  end

  def make_index
    make_idf
    make_norm
    make_name_i
  end

  def name(k)
    it = @name[k] 
    String === it ? it :@name[it]
  end

  def cos(a, b)
    left = @deck[a]
    right = @deck[b]
    dot(left, right) / (@norm[a] * @norm[b])
  end

  def name_to_vector(names)
    names.map {|n| name_i(n)}.flatten.sort.map {|x| [x, 1]}
  end

  def name_i(name)
    left = @name_i.bsearch_index {|x| x[0] >= name}
    result = []
    return result unless left
    while @name_i.dig(left, 0) == name
      result << @name_i[left][1]
      left += 1
    end
    result
  end

  def make_name_i
    ary = []
    @name.each do |k, n|
      if String === n
        ary << [n, k]
      end
    end
    @name_i = ary.sort
  end

  def make_idf
    df = Hash.new(0)
    @deck.each do |k, v|
      v.each do |card, n|
        df[card] += 1
      end
    end

    sz = @deck.size
    hash = Hash.new(Math::log(sz))
    @idf = df.inject(hash) do |result, kv|
      result[kv[0]] = Math::log(sz.quo(kv[1]))
      result
    end
  end

  def vec_to_norm(value)
    norm2 = value.inject(0) do |sum2, card_n|
      card, n = card_n
      sum2 += (@idf[card] * n.clamp(1,5)) ** 2
    end
    Math::sqrt(norm2)
  end

  def make_norm1(name, value)
    @norm[name] = vec_to_norm(value)
  end

  def make_norm
    @norm = Hash.new(0)
    @deck.each do |k, v|
      make_norm1(k, v)
    end
  end

  def dot(a, b)
    s = 0
    ia = 0
    ib = 0
    while true
      break unless a[ia]
      break unless b[ib]
      if a[ia][0] == b[ib][0]
        idf = @idf[a[ia][0]]
        s += (a[ia][1].clamp(1,5) * b[ib][1].clamp(1,5) * idf * idf)
        ia += 1
        ib += 1
      elsif a[ia][0] > b[ib][0]
        ib += 1
      else
        ia += 1
      end
    end
    s
  end

  def top_idf(k)
    v = @deck[k] || @deck_tmp[k]
    v.map {|x| x[0]}.sort_by {|x| -@idf[x]}
  end

  def diff(a, b)
    a = @deck[a] || @deck_tmp[a]
    b = @deck[b] || @deck_tmp[b]
    left = {}
    right = {}
    same = {}
    ia = 0
    ib = 0
    while true
      break unless a[ia]
      break unless b[ib]
      if a[ia][0] == b[ib][0]
        same[a[ia][0]] = [a[ia][1], b[ib][1]]
        ia += 1
        ib += 1
      elsif a[ia][0] > b[ib][0]
        right[b[ib][0]] = [0, b[ib][1]]
        ib += 1
      else
        left[a[ia][0]] = [a[ia][1], 0]
        ia += 1
      end
    end
    while a[ia]
      left[a[ia][0]] = [a[ia][1], 0]
      ia += 1
    end
    while b[ib]
      right[b[ib][0]] = [0, b[ib][1]]
      ib += 1
    end
    return [left, same, right].map {|hash|
      hash.sort_by {|a, b| [b[1] <=> b[0], -@idf[a]]}.map {|k, n| k = @id_latest[k]; [name(k), k, n]}
    }.inject([]) {|a, b| a + b}
  end

  def search(name, n=5)
    search_by_deck(name, n)
  end

  def search_by_deck(name, n=5)
    v = add(name)

    ignore = name_to_vector(["ハイパーボール", "グズマ", "カプ・テテフGX", "ダブル無色エネルギー"])

    score = []
    @deck.keys.each do |b|
      # next if name == b
      next if dot(@deck[b], ignore) > 0
      c = dot(v, @deck[b]) / (@norm[name] * @norm[b]) # cos
      next if c == 0
      score << [c, b]
    end
    top = score.sort.reverse
    if top[0][1] != name
      top.unshift([1.0, name])
    end
    top[0,n]
  end

  def search_by_name(card_id, n=5)
    req = name_to_vector([card_id])
    norm = vec_to_norm(req)
    return [] if norm == 0
    ignore = name_to_vector(["ハイパーボール", "グズマ", "カプ・テテフGX", "ダブル無色エネルギー"])

    score = []
    @deck.keys.each do |b|
      next if dot(@deck[b], ignore) > 0
      c = dot(req, @deck[b]) / (norm * @norm[b]) # cos
      next if c == 0
      score << [c, b]
    end
    top = score.sort.reverse
    top[0,n]
  end

  def search_by_card(card_id, n=5)
    req = [[@id_norm[card_id], 1]]
    p [card_id, req]
    norm = vec_to_norm(req)
    ignore = name_to_vector(["ハイパーボール", "グズマ", "カプ・テテフGX", "ダブル無色エネルギー"])

    score = []
    @deck.keys.each do |b|
      next if dot(@deck[b], ignore) > 0
      c = dot(req, @deck[b]) / (norm * @norm[b]) # cos
      next if c == 0
      score << [c, b]
    end
    top = score.sort.reverse
    top[0,n]
  end

  def add(name, save=false)
    v = @deck[name] || @deck_tmp[name]
    return v if v

    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    v = v.map {|card_id, n| [@id_norm[card_id], n]}.sort
    v = v.chunk {|e| e[0]}.map {|card_id, g|  [card_id, g.map{|h| h[1]}.sum]}
    if save
      @kvs[name] = v.to_json
      @deck[name] = v
    else
      @deck_tmp[name] = v
    end
    make_norm1(name, v)
    v
  end
end

if __FILE__ == $0
  require 'drb'

  masaki = Masaki.new
  pp masaki.world.name_to_vector(["ハイパーボール", "グズマ", "カプ・テテフGX", "ダブル無色エネルギー"])
  pp masaki.world.name_to_vector(["イーブイ"])
  pp masaki.world.search_by_name("シキジカ")

  exit
end