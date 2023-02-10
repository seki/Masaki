require_relative 'deck-detail'
require_relative 'store-deck'
require_relative 'store-meta'
require 'json'

class MasakiWorld
  module Dot
    def deck_norm(deck)
      deck.instance_variable_get(:@norm)
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
          s += (a[ia][1].clamp(..5) * b[ib][1].clamp(..5) * idf * idf)
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

    def _cos(deck_a, deck_b)
      dot(deck_a, deck_b) / (deck_norm(deck_a) * deck_norm(deck_b))
    end

    def _search_by_deck(v, n)
      _search_by_deck_core(@deck, v, n)
    end

    def _search_by_deck_core(all_deck, v, n)
      norm = deck_norm(v)
      all_deck.map do |b, deck_b|
        c = dot(v, deck_b) / (norm * deck_norm(deck_b)) # cos
        c = 0 if c + Float::EPSILON >= 1 # ignore same deck
        [c, b]
      end.max(n).find_all {|x| x[0] > 0}
    end
  end

  class ForRactor
    include Dot
    NPROC = 8
    def initialize(idf, deck, nproc=NPROC)
      @idf = idf
      @deck = deck.to_a
      @nproc = nproc
    end

    def each_in(range)
      return enum_for(__method__, range) unless block_given?
      range.each {|x| yield(@deck[x])}
    end

    def _search_by_deck(v, n)
      ((0..@deck.size).step(@deck.size / @nproc + 1) + [@deck.size]).each_cons(2).map {|s, e|
        Ractor.new(self, each_in(s...e), v, n) {|world, sub_decks, v, n|
          world._search_by_deck_core(sub_decks, v, n)
        }
      }.map {|r| r.take}.sum([]).max(n)
    end
  end
  
  include Dot
  def initialize
    data_dir = __dir__ + "/../data/"
    trainer = JSON.parse(File.read(data_dir + "uniq_energy_trainer_all.txt"))
    pokemon = JSON.parse(File.read(data_dir + "uniq_pokemon_all.txt"))
    @name = Hash[trainer + pokemon]
    make_id_norm

    @deck = {}
    import_deck
    pp @deck.size

    reload_recent
    
    @deck_tmp = {}
    @added_deck = {}
    make_index
    @ractor = for_ractor(8)
  end
  attr_reader :deck, :idf, :recent, :id_latest, :ractor

  def for_ractor(nproc=8)
    Ractor.make_shareable(ForRactor.new(@idf, @deck, nproc))
  end

  def import_deck
    Masaki::Deck.each do |k, v_ary|
      begin
        next unless v_ary
        @deck[k] = re_normalize(v_ary)
      rescue => e
        pp [k, e]
      end
    end
  end

  def reload_recent(n=10)
    @recent = Masaki::Meta.referer_tw_recent(n)
  end

  def re_normalize(v)
    v = v.map {|card_id, n| [@id_norm[card_id], n]}.sort
    v.chunk {|e| e[0]}.map {|card_id, g|  [card_id, g.map{|h| h[1]}.sum]}
  end

  def make_id_norm
    @id_norm = (0..(@name.keys.max)).to_a
    @name.each do |k, v|
      next if String === v
      @id_norm[k] = v 
    end

    @id_latest = (0..(@name.keys.max)).to_a
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
    String === it ? it : @name[it]
  end

  def cos(a, b)
    left = @deck[a]
    right = @deck[b]
    dot(left, right) / (deck_norm(left) * deck_norm(right))
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
      result[kv[0]] = Math::log(sz.quo(kv[1])).ceil
      result
    end
  end

  def vec_to_norm(value)
    norm2 = value.inject(0) do |sum2, card_n|
      card, n = card_n
      sum2 += (@idf[card] * n.clamp(..5)) ** 2
    end
    Math::sqrt(norm2)
  end

  def make_norm1(value)
    norm = vec_to_norm(value)
    value.instance_variable_set(:@norm, norm)
    value.freeze
    norm
  end

  def make_norm
    @deck.each do |k, v|
      make_norm1(v)
    end
  end

  def deck_desc_for_cluster(v, n=5)
    v.max_by(n) {|x| @idf[x[0]] * x[1]}.map {|x| @name[x[0]]}
  end

  def deck_desc(code, n=5)
    v = add(code)
    v.max_by(n) {|x| @idf[x[0]]}.map {|x| @name[x[0]]}
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

  def search(name, n=5)
    search_by_deck(name, n)
  end

  def search_by_deck(name, n, add_deck=false)
    v = add(name, add_deck)

    s = Time.now
    top = _search_by_deck_core(@deck, v, n)
    # top = (_search_by_deck_core(@added_deck, v, n) + @ractor._search_by_deck(v, n)).max(n)
    p [:search, Time.now - s]

    if top[0][1] != name
      top.unshift([1.0, name])
    end
    top[0,n]
  end 

  def search_by_(v, n)
    norm = make_norm1(v)
    return [] if norm == 0

    s = Time.now
    top = _search_by_deck_core(@deck, v, n)
    # top = (_search_by_deck_core(@added_deck, v, n) + @ractor._search_by_deck(v, n)).max(n)
    p [:search, Time.now - s]

    top
  end

  def search_by_name(card_name, n=5)
    req = name_to_vector([card_name])
    search_by_(req, n)
  end

  def search_by_card(card_id, n=5)
    req = [[@id_norm[card_id], 1]]
    search_by_(req, n)
  end

  def search_by_screen_name(screen_name, n=30)
    ary = Masaki::Meta.referer_tw_screen_name(screen_name, n)
    ary.each {|tw| add(tw['deck'], true)}
    ary
  end

  def add(name, save=false)
    if save
      v = @deck[name]
    else
      v = @deck[name] || @deck_tmp[name]
    end
    return v if v

    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    v = v.map {|card_id, n| [@id_norm[card_id], n]}.sort
    v = v.chunk {|e| e[0]}.map {|card_id, g|  [card_id, g.map{|h| h[1]}.sum]}
    if save
      puts name
      Masaki::Deck[name] = v
      @deck[name] = v
      @added_deck[name] = v
    else
      @deck_tmp[name] = v
    end
    make_norm1(v)
    v
  end
end

if __FILE__ == $0
  require 'benchmark'

  p Ractor.new {1}.take

  mw = MasakiWorld.new

  key = "yyyyyS-NFYSqN-pUXMXy"
  v = mw.deck[key]

  Benchmark.bm do |x|
    [2, 4, 8, 16, 32, 64].each do |n|
      r = mw.for_ractor(n)
      x.report("%02d E" % n){ 50.times{ r._search_by_deck(v, 10) } }
    end
    x.report('org '){ 50.times{ mw._search_by_deck(v, 10) } }
  end
end