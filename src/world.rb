require_relative 'masaki-pg'
require_relative 'deck-detail'
require 'json'

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
    make_filter
  end
  attr_reader :deck, :idf, :norm, :recent, :id_latest

  def make_filter
    @ignore = name_to_vector(["ハイパーボール", "グズマ", "カプ・テテフGX", "ダブル無色エネルギー"])
  end

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
    a = add(a)
    b = add(b)
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

  def search(name, filter, n=5)
    search_by_deck(name, filter, n)
  end

  def search_by_deck(name, filter, n=5)
    v = add(name)

    score = []
    @deck.keys.each do |b|
      # next if name == b
      next if filter && dot(@deck[b], @ignore) > 0
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

  def search_by_name(card_id, filter, n=5)
    req = name_to_vector([card_id])
    norm = vec_to_norm(req)
    return [] if norm == 0

    score = []
    @deck.keys.each do |b|
      next if filter && dot(@deck[b], @ignore) > 0
      c = dot(req, @deck[b]) / (norm * @norm[b]) # cos
      next if c == 0
      score << [c, b]
    end
    top = score.sort.reverse
    top[0,n]
  end

  def search_by_card(card_id, filter, n=5)
    req = [[@id_norm[card_id], 1]]
    p [card_id, req]
    norm = vec_to_norm(req)

    score = []
    @deck.keys.each do |b|
      next if filter && dot(@deck[b], @ignore) > 0
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
