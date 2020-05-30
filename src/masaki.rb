require_relative 'masaki-pg'
require_relative 'deck-detail'
require 'json'

class Masaki
  def initialize
    @world = MasakiWorld.new
  end

  def do_api(req, res, deck)
    name = DeckDetail::guess_deck_name(deck)
    search(name, 5)
  end

  def search(deck, n=5)
    @world.search(deck, n).map {|s, k| 
      link, image =  DeckDetail::make_url(k)
      {
        'link' => link,
        'image' => image,
        'score' => s
      }
    }
  end

  def add(deck)
    @world.add(deck)
  end

  def card_url(key)
    "https://www.pokemon-card.com/card-search/details.php/card/#{key}"
  end

  def diff(left, right)
    l, r, s = @world.diff(left, right)
    [s.sort_by {|a, b| -@world.idf[a]}.map {|k, n| [@world.name(k), n, card_url(k)]},
     l.sort_by {|a, b| -@world.idf[a]}.map {|k, n| [@world.name(k), n, card_url(k)]},
     r.sort_by {|a, b| -@world.idf[a]}.map {|k, n| [@world.name(k), n, card_url(k)]}]
  end
end

class MasakiWorld
  def initialize
    @deck = {}
    @kvs = MasakiPG::KVS.new('deck')
    @kvs.each do |k, v|
      @deck[k] = JSON.parse(v)
    end
    trainer = JSON.parse(File.read("data/uniq_energy_trainer_all.txt"))
    pokemon = JSON.parse(File.read("data/uniq_pokemon_all.txt"))
    @name = Hash[trainer + pokemon]

    @id_norm = Hash[JSON.parse(File.read('data/derived_norm.txt'))]

    make_index
  end
  attr_reader :deck, :idf, :norm

  def make_index
    make_idf
    make_norm
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

  def make_idf
    df = Hash.new(0)
    @deck.each do |k, v|
      v.each do |card, n|
        df[card] += 1
      end
    end

    sz = @deck.size
    @idf = df.inject({}) do |result, kv|
      result[kv[0]] = Math::log(sz.quo(kv[1]))
      result
    end
  end

  def make_norm1(name, value)
    norm2 = value.inject(0) do |sum2, card_n|
      card, n = card_n
      sum2 += (@idf[card] * n) ** 2
    end
    @norm[name] = Math::sqrt(norm2)
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
        s += (a[ia][1] * b[ib][1] * idf * idf)
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

  def diff(a, b)
    a = @deck[a]
    b = @deck[b]  
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
        right[b[ib][0]] = b[ib][1]
        ib += 1
      else
        left[a[ia][0]] = a[ia][1]
        ia += 1
      end
    end
    return left, right, same
  end

  def search(name, n=5)
    v = add(name)

    score = []
    @deck.keys.each do |b|
      next if name == b
      c = dot(v, @deck[b]) / (@norm[name] * @norm[b]) # cos
      score << [c, b]
    end
    top = score.sort.reverse
    top[0,n]
  end

  def add(name, save=true)
    return @deck[name] if @deck.include?(name)

    src = DeckDetail.fetch_deck_page(name)
    v = DeckDetail.parse(src)
    v = v.map {|card_id, n| [@id_norm[card_id] || card_id, n]}.sort
    v = v.chunk {|e| e[0]}.map {|card_id, g|  [card_id, g.map{|h| h[1]}.sum]}
    if save
      @kvs[name] = v.to_json
      @deck[name] = v
    end
    make_norm1(name, v)
    v
  end
end

if __FILE__ == $0
  require 'drb'

  masaki = Masaki.new
  DRb.start_service('druby://localhost:50151', masaki)
  puts DRb.uri
  DRb.thread.join


  l, r, s = world.diff(a, top[0][1])
  pp s.sort_by {|a, b| -world.idf[a]}.map {|k, n| [world.name(k), n]}
  pp l.sort_by {|a, b| -world.idf[a]}.map {|k, n| [world.name(k), n]}
  pp r.sort_by {|a, b| -world.idf[a]}.map {|k, n| [world.name(k), n]}

  exit

end