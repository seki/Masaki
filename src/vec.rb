require_relative 'masaki-pg'
require 'json'

class MasakiWorld
  def initialize
    @deck = {}
    kvs = MasakiPG::KVS.new('deck')
    kvs.each do |k, v|
      @deck[k] = JSON.parse(v)
    end
    trainer = eval(File.read("../data/uniq_energy_trainer_all.txt"))
    pokemon = eval(File.read("../data/uniq_pokemon_all.txt"))
    @name = Hash[trainer + pokemon]
  end
  attr_reader :deck, :idf, :norm

  def name(k)
    it = @name[k] 
    return it if String === it
    @name[it]
  end

  def combination
    @deck.keys.combination(2)
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
      result[kv[0]] = Math::log(sz.quo(kv[1])).ceil
      result
    end
  end

  def make_norm
    @norm = Hash.new(0)
    @deck.each do |k, v|
      norm2 = v.inject(0) do |sum2, card_n|
        card, n = card_n
        sum2 += (@idf[card] * n) ** 2
      end
      @norm[k] = Math::sqrt(norm2)
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
end

if __FILE__ == $0
  world = MasakiWorld.new
  world.make_idf
  world.make_norm

  a = ARGV.shift
  score = []
  world.deck.keys.each do |b|
    next if a == b
    cos = world.cos(a, b)
    score << [cos, b]
  end
  top = score.sort.reverse
  pp top[0, 5]
  l, r, s = world.diff(a, top[0][1])
  pp s.map {|k, n| [world.name(k), n]}
  pp l.map {|k, n| [world.name(k), n]}
  pp r.map {|k, n| [world.name(k), n]}

  exit

  ary = []
  a = 'FbVwkv-JTYoMW-b1V5FV'
  pp world.cos(a, a)
  sum = sum2 = 0
  world.combination.each do |a, b|
    cos = world.cos(a, b)
    ary << [a, b, cos]
    sum += cos
    sum2 += cos ** 2
  end
  mean = sum / ary.size
  dev = sum2 / ary.size - mean ** 2
  pp [mean, dev]
  s = Math::sqrt(dev)

  hash = {}
  ary.each do |a, b, c|
    c2 = (c - mean) / s
    if c2.abs > 0.5
      ab = [a, b].sort
      hash[ab] = c2
    end
  end

  pp hash.size
  File.open('cos.dump', 'w') {|fp| Marshal.dump(hash, fp)}
end