require_relative 'masaki-pg'
require 'json'

class MasakiWorld
  def initialize
    @deck = {}
    kvs = MasakiPG::KVS.new('deck')
    kvs.each do |k, v|
      @deck[k] = JSON.parse(v)
    end
  end
  attr_reader :deck, :idf, :norm

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
end

if __FILE__ == $0
  world = MasakiWorld.new
  world.make_idf
  pp world.idf
  world.make_norm
  pp world.norm
  ary = []
  a = 'FbVwkv-JTYoMW-b1V5FV'
  pp world.cos(a, a)
  world.combination.each do |a, b|
    cos = world.cos(a, b)
    ary << [cos, a, b] if cos > 0.8
  end
  pp ary.sort
end